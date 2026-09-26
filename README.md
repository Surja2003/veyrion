# Veyrion — a friendly AI skin-check on your phone

Veyrion lets you take a close-up photo of a skin spot and get a calm, easy-to-read
estimate of what it might be — with clear next steps. It's built for two kinds of
people: **patients**, who get plain-language guidance without scary jargon, and
**clinics**, who get the extra clinical detail underneath.

> ⚠️ **Veyrion is not a doctor and not a medical device.** It's a screening helper.
> It can be wrong — it misses roughly 3 in 10 real melanomas — so **never use it to
> decide that a spot is safe.** If anything looks new, changing, or worrying, see a
> dermatologist.

---

## 📲 Download the app (Android)

**[⬇️ Download Veyrion for Android](https://github.com/Surja2003/veyrion/releases/latest/download/Veyrion.apk)**

Then install it in three easy steps:

1. **Tap the link above** on your Android phone (or open **Releases** on this page
   and download `Veyrion.apk`).
2. When your phone asks, **allow installing from this source** (Android shows a
   one-time "install unknown apps" prompt — that's normal for apps outside the Play
   Store). Then tap **Install**.
3. **Open Veyrion** and sign in with one of the demo accounts below.

That's it — no accounts to create, nothing to set up. The app already knows where to
find its server.

### 🌐 Or just try it in a browser
No install needed: **[veyrion-pi.vercel.app](https://veyrion-pi.vercel.app)**

### 🔑 Demo sign-ins
| Role | Username | Password |
|------|----------|----------|
| Patient | `patient` | `patient123` |
| Clinic  | `clinic`  | `clinic123` |

---

## How to use it

1. **Scan** — take a close, well-lit photo of a single spot (or pick one from your
   gallery). Fill the frame with the spot. You can crop and fine-tune it.
2. **Read your result** — Veyrion shows how much the spot resembles each of 7 skin
   types, a suggested next step (monitor / routine visit / see a dermatologist soon),
   and a plain-language explanation. Nothing is hidden.
3. **Ask the assistant** — a built-in chat can explain your result in your own
   language (English, हिन्दी, বাংলা).
4. **Learn** — the Learn tab explains the ABCDE self-check and the 7 lesion types.

If you point the camera at something that isn't skin, Veyrion tells you it can't
analyse it — it won't invent a result.

---

## The good stuff, honestly

- Both patients and clinics see **all** the numbers — Veyrion never hides results,
  it just explains them differently for each audience.
- The **melanoma safety note** is shown to everyone, every time.
- It works in **English, Hindi, and Bengali**, including the chat assistant.

---

<details>
<summary><b>For developers — build it yourself</b></summary>

### What's in this repo
```
darm/
├── notebook*.ipynb   # Kaggle training notebooks
├── backend/          # FastAPI inference service
│   ├── app/          # model, predictor, auth, API, skin-image gate
│   └── weights/      # .pth checkpoints (runs in a labelled mock mode until present)
├── deploy_hf/        # the copy that runs on the server (Docker)
└── app/              # Flutter client (Android · Web · Windows)
```

### The model
Five vision backbones (Swin-Tiny, ConvNeXt-Base, EfficientNet-B4, DenseNet-201, a
multi-scale ResNet-34) + patient metadata are fused into a 5760-dim vector →
`GrandmasterFusionNet` → 7 classes (`nv, mel, bkl, bcc, akiec, vasc, df`), with
MC-Dropout uncertainty. Trained on **HAM10000** with lesion-grouped validation:
**90.62% accuracy · Macro-F1 0.8257 · melanoma recall 0.689**.

### Run the backend
```bash
cd backend
py -3.11 -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt          # real inference (needs the .pth weights)
uvicorn app.main:app --port 8000
```
Put the six `.pth` files in `backend/weights/` for real predictions (mock mode
otherwise). Docker: build from `deploy_hf/Dockerfile` (serves on port 7860).

### Run the app
```bash
cd app
flutter pub get
flutter run -d chrome                     # web
flutter run -d <android-id>               # Android device/emulator
# point it at your own backend:
flutter build apk --release --dart-define=DARM_API_BASE=https://your-backend
```

</details>

---

## Please read before any real-world use
Veyrion is a student / benchmark project. Genuine clinical use would need external
multi-site validation, prospective testing, a quality-management system, and
clearance from a medical-device regulator (CDSCO in India, CE-MDR in the EU, FDA in
the US). Until then, treat it as an educational and triage-support tool, with all its
disclaimers kept intact.
