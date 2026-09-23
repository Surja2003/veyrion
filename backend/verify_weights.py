"""
Standalone sanity check for the DARM weight files.

Run this AFTER dropping your .pth files into backend/weights/ to confirm each one
loads into the exact architecture before you point the app at real inference:

    python verify_weights.py

Requires torch + torchvision (pip install -r requirements.txt).
Exits 0 if the fusion head loads and a full forward pass works; non-zero otherwise.
"""
from __future__ import annotations

import sys

import torch

from app import config
from app.model import BackboneBank, GrandmasterFusionNet


def _load_sd(path):
    sd = torch.load(path, map_location="cpu")
    return sd.get("state_dict", sd) if isinstance(sd, dict) else sd


def main() -> int:
    wd = config.WEIGHTS_DIR
    print(f"Weights dir: {wd}\n")
    ok = True

    # ---- Backbones (strict=False; leftover classifier heads are expected) ----
    bank = BackboneBank(pretrained=False).eval()
    backbone_attr = {
        "swin": "swin", "convnext": "convnext", "efficientnet": "efficientnet",
        "densenet": "densenet", "unet": "unet",
    }
    for key, attr in backbone_attr.items():
        path = wd / config.WEIGHT_FILES[key]
        if not path.exists():
            print(f"  [ ] {key:12s} MISSING  ({path.name})")
            ok = False
            continue
        sub = getattr(bank, attr)
        missing, unexpected = sub.load_state_dict(_load_sd(path), strict=False)
        # A healthy backbone load: most keys matched; only the head is 'unexpected'.
        loaded = sum(1 for _ in sub.state_dict()) - len(missing)
        flag = "OK" if len(missing) < 10 else "CHECK"
        print(f"  [x] {key:12s} {flag:5s} loaded~{loaded} keys "
              f"(missing {len(missing)}, ignored-head {len(unexpected)})")
        if len(missing) >= 10:
            ok = False

    # ---- Fusion head (strict=True) ----
    fusion_path = next(
        (wd / n for n in config.FUSION_FILE_CANDIDATES if (wd / n).exists()), None
    )
    fusion = GrandmasterFusionNet().eval()
    if fusion_path is None:
        print(f"\n  [ ] fusion       MISSING  (any of {config.FUSION_FILE_CANDIDATES})")
        ok = False
    else:
        try:
            fusion.load_state_dict(_load_sd(fusion_path), strict=True)
            print(f"\n  [x] fusion       OK    strict load from {fusion_path.name}")
        except Exception as e:  # noqa
            print(f"\n  [ ] fusion       FAIL  {fusion_path.name}: {e}")
            ok = False

    # ---- Full forward pass ----
    try:
        x = torch.randn(1, 3, config.IMAGE_SIZE, config.IMAGE_SIZE)
        with torch.no_grad():
            f = bank(x)
            logits = fusion(f["swin"], f["convnext"], f["efficientnet"], f["densenet"],
                            f["unet"], torch.tensor([3]), torch.tensor([1]), torch.tensor([0.5]))
            probs = torch.softmax(logits, 1)[0]
        print("\n  Forward pass OK. Example probabilities:")
        for i, code in enumerate(config.LABEL_ORDER):
            print(f"    {code:6s} {probs[i]:.4f}")
    except Exception as e:  # noqa
        print(f"\n  Forward pass FAILED: {e}")
        ok = False

    print("\n" + ("PASS - ready for real inference." if ok
                  else "INCOMPLETE - see missing/failed items above (app stays in mock mode)."))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
