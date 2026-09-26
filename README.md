# Veyrion — Dermoscopic AI Risk Monitor

A production-oriented **Flutter app (Android · Web · Windows)** + **FastAPI backend**
that puts your multi-backbone skin-lesion fusion model into the hands of patients
and clinics. Take/upload a photo → crop & fine-tune → add age/sex/site → get a
7-class breakdown with resemblance %, uncertainty, and a calm, non-hidden,
role-aware explanation.

> ⚠️ **Not a medical device.** Veyrion is a decision-support / screening aid built on
> a controlled HAM10000 benchmark. Melanoma recall is ~69% — it can call a real
> melanoma a harmless mole. It must never be used to rule out cancer.

## What's in here

```
darm/
├── notebook*.ipynb     # your Kaggle training notebooks (unchanged)
├── backend/            # FastAPI inference service (matches the paper exactly)
│   ├── app/            # model, predictor, auth, API
│   └── weights/        # drop your .pth checkpoints here (mock mode until then)
└── app/                # Flutter client (android · web · windows)
    └── lib/
```

## The model this serves

Five backbones (Swin-Tiny 768, ConvNeXt-Base 1024, EfficientNet-B4 1792,
DenseNet-201 1920, multi-scale ResNet-34 → 128) + patient metadata (128) fused to
a **5760-dim** vector → `GrandmasterFusionNet` head → 7 classes
(`nv, mel, bkl, bcc, akiec, vasc, df`). The backend reproduces the exact metadata
encoding, age z-scoring, softmax and MC-Dropout uncertainty from your notebooks.

Validation (C2, MixUp off): **90.62% acc · Macro-F1 0.8257 · melanoma recall 0.689**.

## Run it in 3 steps

### 1. Backend (mock mode works immediately, no weights/torch needed)
```bash
cd backend
py -3.11 -m venv .venv && .venv\Scripts\activate      # Python 3.11/3.12 recommended
pip install -r requirements-min.txt                   # or requirements.txt for real inference
uvicorn app.main:app --port 8000
```
For **real predictions**: `pip install -r requirements.txt`, put your six `.pth`
files in `backend/weights/` (see `backend/weights/README.md`), restart.

### 2. App
```bash
cd app
flutter pub get
flutter run -d chrome        # Web  (the "flutter web extension")
flutter run -d windows       # Windows desktop
flutter run -d <android-id>  # Android device/emulator
```

### 3. Sign in
- **Patient:** `patient / patient123`
- **Clinic:**  `clinic / clinic123`

Set the server URL in-app under **Settings**, or at build time:
```bash
flutter run -d chrome --dart-define=Veyrion_API_BASE=https://your-space.hf.space
```
(Android emulator reaches your machine at `http://10.0.2.2:8000`, already the default.)

## How the app frames results (your requirement: full power, nothing hidden)

Both roles see **every** number — all 7 probabilities, uncertainty, malignant mass,
confidence. The difference is framing:
- **Patient** view leads with plain-language reassurance + clear next steps, so
  results are understood without panic.
- **Clinic** view adds clinical caveats (dominant MEL→NV confusion, per-class F1,
  "low melanoma score ≠ rule-out") and record-oriented detail.

The safety caveat about melanoma sensitivity is shown to **everyone**, always.

## Deploy the backend
- **Docker:** `cd backend && docker build -t darm-api . && docker run -p 8000:8000 -v %cd%/weights:/app/weights darm-api`
- **Hugging Face Spaces (Docker SDK):** use `backend/Dockerfile`, expose port 7860.

## Regulatory reality (please read before any real-world use)
This is a student/benchmark system. Real clinical use in the medical sector would
require: external multi-site validation, prospective evaluation, a quality-management
system, and clearance/registration with your medical-device regulator (e.g. CDSCO
in India, CE-MDR in the EU, FDA in the US). Ship it as an educational / triage
support tool with the disclaimers intact until that work is done.
more update on the project will come soon ,as soon as we are free
