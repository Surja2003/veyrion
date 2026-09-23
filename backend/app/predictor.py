"""
Inference orchestration for DARM.

Loads the fusion head + five backbones if the weight files are present, otherwise
runs in a clearly-labelled deterministic MOCK mode so the full app works during
development. Handles preprocessing, metadata encoding, softmax, and MC-Dropout
uncertainty (temperature-scaled), matching the paper.
"""
from __future__ import annotations

import hashlib
import io
import json
import math
import time
from typing import Optional

import numpy as np

from . import config

# Torch/PIL are heavy; import lazily and degrade to mock mode if unavailable.
try:
    import torch
    import torch.nn.functional as F
    from PIL import Image
    from torchvision import transforms
    _TORCH_OK = True
except Exception:  # pragma: no cover
    _TORCH_OK = False


def _encode_metadata(age: Optional[float], sex: str, localization: str,
                     age_mean: float, age_std: float):
    """Reproduce the notebook's metadata encoding."""
    loc_idx = config.LOC_MAP.get((localization or "unknown").strip().lower(), 0)
    sex_idx = config.SEX_MAP.get((sex or "unknown").strip().lower(), 0)
    if age is None:
        age_z = 0.0
    else:
        age_z = (float(age) - age_mean) / (age_std + 1e-8)
    return loc_idx, sex_idx, age_z


class Predictor:
    def __init__(self):
        self.ready = False
        self.mock = True
        self.device = "cpu"
        self.age_mean = config.DEFAULT_AGE_MEAN
        self.age_std = config.DEFAULT_AGE_STD
        self.fusion = None
        self.backbones = None
        self.transform = None
        self._load()

    # ------------------------------------------------------------------ #
    def _load(self):
        # Age stats override
        stats_path = config.WEIGHTS_DIR / config.AGE_STATS_FILE
        if stats_path.exists():
            try:
                s = json.loads(stats_path.read_text())
                self.age_mean = float(s.get("mean", s.get("age_mean", self.age_mean)))
                self.age_std = float(s.get("std", s.get("age_std", self.age_std)))
            except Exception:
                pass

        if not _TORCH_OK:
            print("[predictor] torch/PIL not available -> MOCK mode")
            self.ready = True
            return

        fusion_path = next(
            (config.WEIGHTS_DIR / name
             for name in config.FUSION_FILE_CANDIDATES
             if (config.WEIGHTS_DIR / name).exists()),
            config.WEIGHTS_DIR / config.WEIGHT_FILES["fusion"],
        )
        backbone_paths = {
            k: config.WEIGHTS_DIR / config.WEIGHT_FILES[k]
            for k in ("swin", "convnext", "efficientnet", "densenet", "unet")
        }
        have_all = fusion_path.exists() and all(p.exists() for p in backbone_paths.values())

        if not have_all:
            missing = [config.WEIGHT_FILES["fusion"]] if not fusion_path.exists() else []
            missing += [config.WEIGHT_FILES[k] for k, p in backbone_paths.items() if not p.exists()]
            print(f"[predictor] Missing weight files {missing} -> MOCK mode. "
                  f"Drop them into {config.WEIGHTS_DIR} for real inference.")
            self.ready = True
            return

        # Real mode
        from .model import GrandmasterFusionNet, BackboneBank
        self.device = "cuda" if torch.cuda.is_available() else "cpu"

        self.fusion = GrandmasterFusionNet()
        state = torch.load(fusion_path, map_location=self.device)
        state = state.get("state_dict", state) if isinstance(state, dict) else state
        self.fusion.load_state_dict(state, strict=True)
        self.fusion.to(self.device).eval()

        self.backbones = BackboneBank()
        for key, path in backbone_paths.items():
            sub = getattr(self.backbones, "efficientnet" if key == "efficientnet" else key)
            bs = torch.load(path, map_location=self.device)
            bs = bs.get("state_dict", bs) if isinstance(bs, dict) else bs
            # Fine-tuned checkpoints may carry a classifier head; ignore extras.
            missing, unexpected = sub.load_state_dict(bs, strict=False)
            if missing or unexpected:
                print(f"[predictor] {key}: {len(missing)} missing / {len(unexpected)} unexpected keys "
                      f"(loaded non-strict).")
        self.backbones.to(self.device).eval()

        self.transform = transforms.Compose([
            transforms.Resize((config.IMAGE_SIZE, config.IMAGE_SIZE)),
            transforms.ToTensor(),
            transforms.Normalize(config.IMAGENET_MEAN, config.IMAGENET_STD),
        ])
        self.mock = False
        self.ready = True
        print(f"[predictor] Loaded real weights on {self.device}.")

    # ------------------------------------------------------------------ #
    @staticmethod
    def _enable_mc_dropout(module):
        for m in module.modules():
            if m.__class__.__name__.startswith("Dropout"):
                m.train()

    def _softmax_np(self, logits, temperature=1.0):
        z = np.asarray(logits, dtype=np.float64) / temperature
        z = z - z.max()
        e = np.exp(z)
        return e / e.sum()

    # ------------------------------------------------------------------ #
    def predict(self, image_bytes: bytes, age: Optional[float], sex: str,
                localization: str, mc_dropout: bool = True) -> dict:
        t0 = time.time()
        loc_idx, sex_idx, age_z = _encode_metadata(
            age, sex, localization, self.age_mean, self.age_std
        )

        if self.mock or not _TORCH_OK:
            probs, mc_std = self._mock_predict(image_bytes, loc_idx, sex_idx, age_z)
        else:
            probs, mc_std = self._real_predict(image_bytes, loc_idx, sex_idx, age_z, mc_dropout)

        return self._assemble(probs, mc_std, age_z, time.time() - t0)

    # ------------------------------------------------------------------ #
    def _real_predict(self, image_bytes, loc_idx, sex_idx, age_z, mc_dropout):
        img = Image.open(io.BytesIO(image_bytes)).convert("RGB")
        x = self.transform(img).unsqueeze(0).to(self.device)
        loc = torch.tensor([loc_idx], dtype=torch.long, device=self.device)
        sex = torch.tensor([sex_idx], dtype=torch.long, device=self.device)
        age = torch.tensor([age_z], dtype=torch.float32, device=self.device)

        with torch.no_grad():
            feats = self.backbones(x)
            args = (feats["swin"], feats["convnext"], feats["efficientnet"],
                    feats["densenet"], feats["unet"], loc, sex, age)

            base_logits = self.fusion(*args).squeeze(0).cpu().numpy()
            probs = self._softmax_np(base_logits, temperature=1.0)

            mc_std = None
            if mc_dropout:
                self.fusion.eval()
                self._enable_mc_dropout(self.fusion)
                stack = []
                for _ in range(config.MC_DROPOUT_PASSES):
                    lg = self.fusion(*args).squeeze(0).cpu().numpy()
                    stack.append(self._softmax_np(lg, temperature=config.MC_TEMPERATURE))
                self.fusion.eval()
                arr = np.stack(stack, axis=0)
                probs = arr.mean(axis=0)
                mc_std = arr.std(axis=0)
        return probs, mc_std

    # ------------------------------------------------------------------ #
    def _mock_predict(self, image_bytes, loc_idx, sex_idx, age_z):
        """Deterministic, image-dependent pseudo-prediction (clearly flagged mock)."""
        h = hashlib.sha256(image_bytes + bytes([loc_idx, sex_idx])).digest()
        seed = int.from_bytes(h[:8], "big")
        rng = np.random.default_rng(seed)
        # Prior skewed toward NV (dataset reality) so demo output looks plausible.
        prior = np.array([6.0, 1.2, 1.3, 0.9, 0.6, 0.5, 0.5])
        noise = rng.gamma(shape=prior, scale=1.0)
        probs = noise / noise.sum()
        mc_std = rng.uniform(0.01, 0.06, size=7) * (1.0 + probs)
        return probs, mc_std

    # ------------------------------------------------------------------ #
    def _assemble(self, probs, mc_std, age_z, latency_s) -> dict:
        probs = np.asarray(probs, dtype=np.float64)
        order = np.argsort(probs)[::-1]
        classes = []
        for i in range(7):
            code = config.LABEL_ORDER[i]
            info = config.CLASS_INFO[code]
            classes.append({
                "code": code,
                "index": i,
                "name": info["name"],
                "common_name": info["common_name"],
                "probability": float(probs[i]),
                "resemblance_pct": round(float(probs[i]) * 100, 2),
                "malignant": info["malignant"],
                "risk": info["risk"],
                "uncertainty": float(mc_std[i]) if mc_std is not None else None,
                "one_liner": info["one_liner"],
                "patient_note": info["patient_note"],
                "clinician_note": info["clinician_note"],
            })

        top_idx = int(order[0])
        top_code = config.LABEL_ORDER[top_idx]
        top_info = config.CLASS_INFO[top_code]

        # Shannon entropy (normalised 0..1) as a confidence signal.
        p = np.clip(probs, 1e-9, 1.0)
        entropy = float(-(p * np.log(p)).sum() / math.log(7))

        # Malignant probability mass (mel + bcc + akiec).
        malignant_mass = float(sum(
            probs[i] for i, c in enumerate(config.LABEL_ORDER)
            if config.CLASS_INFO[c]["malignant"]
        ))

        return {
            "mock": self.mock,
            "model_config": config.MODEL_CARD["config"],
            "top": {
                "code": top_code,
                "name": top_info["name"],
                "common_name": top_info["common_name"],
                "probability": float(probs[top_idx]),
                "resemblance_pct": round(float(probs[top_idx]) * 100, 2),
                "risk": top_info["risk"],
                "malignant": top_info["malignant"],
            },
            "classes": classes,
            "ranking": [config.LABEL_ORDER[i] for i in order],
            "malignant_probability": malignant_mass,
            "confidence": {
                "top_probability": float(probs[top_idx]),
                "entropy_normalised": entropy,
                "level": _confidence_level(float(probs[top_idx]), entropy),
                "mc_dropout_available": mc_std is not None,
                "mean_uncertainty": float(np.mean(mc_std)) if mc_std is not None else None,
            },
            "urgency": _urgency(top_info, malignant_mass),
            "latency_ms": round(latency_s * 1000, 2),
        }


def _confidence_level(top_p: float, entropy: float) -> str:
    if top_p >= 0.75 and entropy <= 0.45:
        return "high"
    if top_p >= 0.5 and entropy <= 0.65:
        return "moderate"
    return "low"


def _urgency(top_info: dict, malignant_mass: float) -> dict:
    risk = top_info["risk"]
    if risk == "high" or malignant_mass >= 0.5:
        band, label = "urgent", "See a dermatologist promptly"
        msg = ("The most likely result, or the combined chance of a cancerous type, is high enough that "
               "an in-person dermatology assessment is the clear next step. This is not an emergency-room "
               "situation, but do not delay booking.")
    elif risk == "moderate" or malignant_mass >= 0.2:
        band, label = "routine-soon", "Book a routine dermatology appointment"
        msg = ("This type is treatable and not urgent, but should be looked at by a clinician in person "
               "in the coming weeks.")
    else:
        band, label = "monitor", "Likely benign - monitor and protect your skin"
        msg = ("The most likely result is benign. Keep an eye on the area and see a doctor if it changes "
               "(size, shape, colour, itching, or bleeding). Use sun protection.")
    return {"band": band, "label": label, "message": msg}


# Singleton
_predictor: Optional[Predictor] = None


def get_predictor() -> Predictor:
    global _predictor
    if _predictor is None:
        _predictor = Predictor()
    return _predictor
