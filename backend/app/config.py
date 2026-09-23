"""
Central configuration for the DARM inference backend.

The class metadata, metadata encodings, and architecture constants here are
taken verbatim from the training notebooks so the server reproduces the exact
inference contract of the paper "Multi-Backbone Feature Fusion for Multi-Class
Skin Lesion Classification".
"""
from __future__ import annotations

import os
from pathlib import Path

# --------------------------------------------------------------------------- #
# Paths
# --------------------------------------------------------------------------- #
BASE_DIR = Path(__file__).resolve().parent.parent
WEIGHTS_DIR = Path(os.getenv("DARM_WEIGHTS_DIR", BASE_DIR / "weights"))

# Backbone + fusion checkpoint filenames (drop these into backend/weights/).
WEIGHT_FILES = {
    "swin": "swin_best.pth",
    "convnext": "convnext_best.pth",
    "efficientnet": "effnet_best.pth",
    "densenet": "densenet_best.pth",
    "unet": "unet_best.pth",            # multi-scale ResNet-34 branch (called "unet" in the notebooks)
    "fusion": "best_teacher_ensemble.pth",
}

# The fusion head (full C2 config) is saved under different names across the
# notebooks. Any of these is accepted — they share identical state_dict keys and
# load into GrandmasterFusionNet with strict=True. First match wins.
FUSION_FILE_CANDIDATES = [
    "best_teacher_ensemble.pth",   # deployment notebook (notebookda8f63fb86)
    "best_ema_model.pth",          # ablation-study C2 run (notebook917bb6d0fa)
    "fusion_best.pth",
]
AGE_STATS_FILE = "age_normalization_stats.json"

# --------------------------------------------------------------------------- #
# Model / preprocessing constants (from the notebooks & paper)
# --------------------------------------------------------------------------- #
IMAGE_SIZE = 448
IMAGENET_MEAN = (0.485, 0.456, 0.406)
IMAGENET_STD = (0.229, 0.224, 0.225)

# Feature dimensions per branch (paper Section: Feature extraction and caching).
FEATURE_DIMS = {
    "swin": 768,
    "convnext": 1024,
    "efficientnet": 1792,
    "densenet": 1920,
    "unet": 448,   # ResNet-34 multi-scale (64 + 128 + 256), bottlenecked to 128 inside the fusion net
}
META_DIM = 128
UNIFIED_DIM = 5760  # 768 + 1024 + 1792 + 1920 + 128(unet bottleneck) + 128(meta)

# Backbones use torchvision.models (verified against the fine-tune notebooks):
#   swin_t · convnext_base · efficientnet_b4 · densenet201 · resnet34 (multi-scale)
# See app/model.py:BackboneBank for the exact head-stripping per model.

# --------------------------------------------------------------------------- #
# Label map (verbatim from notebook2b05da16f1)
#   label_map = {'nv':0,'mel':1,'bkl':2,'bcc':3,'akiec':4,'vasc':5,'df':6}
# --------------------------------------------------------------------------- #
LABEL_ORDER = ["nv", "mel", "bkl", "bcc", "akiec", "vasc", "df"]

# Metadata encodings (verbatim from notebookda8f63fb86)
LOC_MAP = {
    "unknown": 0, "abdomen": 1, "acral": 2, "back": 3, "chest": 4, "ear": 5,
    "face": 6, "foot": 7, "genital": 8, "hand": 9, "lower extremity": 10,
    "neck": 11, "scalp": 12, "trunk": 13, "upper extremity": 14,
}
SEX_MAP = {"unknown": 0, "male": 1, "female": 2}

# HAM10000 training-fold age statistics. Overridden by weights/age_normalization_stats.json
# if that file is present (exported by notebook2b05da16f1).
DEFAULT_AGE_MEAN = 51.86
DEFAULT_AGE_STD = 16.97

# --------------------------------------------------------------------------- #
# MC-Dropout uncertainty (paper: 10 passes, temperature T = 4.0)
# --------------------------------------------------------------------------- #
MC_DROPOUT_PASSES = 10
MC_TEMPERATURE = 4.0

# --------------------------------------------------------------------------- #
# Rich per-class clinical metadata. Served to the app and used for framing.
# `risk` drives the urgency band. `malignant` is the clinical nature.
# Text is written to be fully transparent to patients while avoiding panic.
# --------------------------------------------------------------------------- #
CLASS_INFO = {
    "nv": {
        "code": "NV",
        "name": "Melanocytic Nevus",
        "common_name": "Common mole",
        "malignant": False,
        "risk": "low",
        "one_liner": "A common, benign mole. The large majority of these are harmless.",
        "patient_note": (
            "Melanocytic naevi ('moles') are extremely common and almost always harmless. "
            "This result does not mean anything is wrong. Still, it is worth knowing your own skin: "
            "if a mole changes in size, shape, or colour, starts itching or bleeding, tell a doctor."
        ),
        "clinician_note": (
            "Highest-support class (val F1 0.959). Note the dominant error mode in this model is "
            "melanoma -> NV confusion (53 MEL predicted as NV): a confident 'NV' does not rule out melanoma."
        ),
        "abcde": True,
    },
    "mel": {
        "code": "MEL",
        "name": "Melanoma",
        "common_name": "Melanoma (a form of skin cancer)",
        "malignant": True,
        "risk": "high",
        "one_liner": "A potentially serious skin cancer. Early assessment matters and usually leads to good outcomes.",
        "patient_note": (
            "Melanoma is a type of skin cancer. Seeing this word is understandably worrying, but two things matter: "
            "(1) this tool is a screening aid, not a diagnosis, and it can be wrong; (2) when melanoma is found early it is "
            "very often treatable. The right next step is simple and not an emergency: book a dermatologist to look at it in person."
        ),
        "clinician_note": (
            "Val recall 0.689 (precision 0.781) - this model MISSES roughly 1 in 3 true melanomas, mostly to NV. "
            "Treat a negative melanoma result with caution; correlate with dermoscopy/history and consider biopsy on clinical suspicion."
        ),
        "abcde": True,
    },
    "bkl": {
        "code": "BKL",
        "name": "Benign Keratosis",
        "common_name": "Benign keratosis (e.g. seborrhoeic keratosis, solar lentigo)",
        "malignant": False,
        "risk": "low",
        "one_liner": "A benign, non-cancerous growth that is very common with age.",
        "patient_note": (
            "Benign keratoses are harmless skin growths that become more common as we get older. "
            "They do not turn into cancer. They can be removed for comfort or cosmetic reasons if they bother you."
        ),
        "clinician_note": (
            "Val F1 0.829. Note 17 BKL were predicted as MEL by this model - BKL/MEL overlap is a known confuser. "
            "Dermoscopic correlation recommended for pigmented BKL."
        ),
        "abcde": False,
    },
    "bcc": {
        "code": "BCC",
        "name": "Basal Cell Carcinoma",
        "common_name": "Basal cell carcinoma (the most common, least aggressive skin cancer)",
        "malignant": True,
        "risk": "moderate",
        "one_liner": "The most common skin cancer. It rarely spreads and is highly treatable.",
        "patient_note": (
            "Basal cell carcinoma is a skin cancer, but it is the most common and least dangerous kind. "
            "It grows slowly and almost never spreads to the rest of the body. It does need to be looked at and treated, "
            "but it is not an emergency. Please book a dermatologist appointment."
        ),
        "clinician_note": (
            "Val recall 0.891 / precision 0.797 (F1 0.841). Generally well separated. Confirm and treat per local pathway."
        ),
        "abcde": False,
    },
    "akiec": {
        "code": "AKIEC",
        "name": "Actinic Keratosis / Intraepithelial Carcinoma",
        "common_name": "Actinic keratosis (a pre-cancerous sun-damage spot)",
        "malignant": True,
        "risk": "moderate",
        "one_liner": "A sun-damage lesion that is pre-cancerous or an early in-situ carcinoma. Treatable.",
        "patient_note": (
            "Actinic keratoses are rough patches caused by years of sun exposure. They are considered pre-cancerous, "
            "meaning a small fraction could develop into cancer over time if left alone. They are easily treated. "
            "Book a routine dermatology appointment, and protect the area from the sun."
        ),
        "clinician_note": (
            "Val F1 0.724 (lowest of the malignant/pre-malignant group). Confusers: 7 AKIEC -> BKL. "
            "Field cancerisation context; manage per AK pathway."
        ),
        "abcde": False,
    },
    "vasc": {
        "code": "VASC",
        "name": "Vascular Lesion",
        "common_name": "Vascular lesion (e.g. angioma, haemorrhage)",
        "malignant": False,
        "risk": "low",
        "one_liner": "A benign lesion made of blood vessels, such as a cherry angioma.",
        "patient_note": (
            "Vascular lesions are harmless collections of small blood vessels (like a cherry angioma). "
            "They are benign and usually need no treatment."
        ),
        "clinician_note": (
            "Val F1 0.822 but small support (n=36) - estimate is unstable. Usually clinically obvious."
        ),
        "abcde": False,
    },
    "df": {
        "code": "DF",
        "name": "Dermatofibroma",
        "common_name": "Dermatofibroma (a benign firm skin nodule)",
        "malignant": False,
        "risk": "low",
        "one_liner": "A common, benign, firm skin nodule. Harmless.",
        "patient_note": (
            "Dermatofibromas are harmless firm bumps in the skin, often on the legs. "
            "They are benign and usually left alone unless they are uncomfortable."
        ),
        "clinician_note": (
            "Val precision 0.950 / recall 0.760 (F1 0.844) on tiny support (n=25). High precision, unstable estimate."
        ),
        "abcde": False,
    },
}

# Model performance context (paper Table II) - surfaced honestly in the app.
MODEL_CARD = {
    "dataset": "HAM10000 (lesion-grouped validation, 2025 samples)",
    "config": "C2 (image + metadata), MixUp disabled",
    "accuracy": 0.9062,
    "macro_f1": 0.8257,
    "melanoma_recall": 0.6891,
    "per_class_f1": {
        "nv": 0.9593, "mel": 0.7321, "bkl": 0.8288, "bcc": 0.8412,
        "akiec": 0.7238, "vasc": 0.8219, "df": 0.8444,
    },
    "key_caveat": (
        "This is a controlled-benchmark model, not a clinically validated device. "
        "Its biggest weakness is melanoma sensitivity (~69% recall): it can label a true "
        "melanoma as a benign mole. Never use it to rule out cancer."
    ),
}

# --------------------------------------------------------------------------- #
# Auth (demo). Replace with a real user store + secret management in production.
# --------------------------------------------------------------------------- #
JWT_SECRET = os.getenv("DARM_JWT_SECRET", "change-me-in-production-darm-secret")
JWT_ALGORITHM = "HS256"
JWT_EXPIRE_HOURS = 12

CORS_ORIGINS = os.getenv("DARM_CORS_ORIGINS", "*").split(",")
