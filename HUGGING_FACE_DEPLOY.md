# Deploying Veyrion Backend to Hugging Face Spaces

This guide walks you step-by-step through deploying your **Veyrion FastAPI Backend** (with PyTorch model weights or mock mode) to a free **Hugging Face Docker Space**.

---

## Prerequisites

1. A free account on [Hugging Face](https://huggingface.co/join).
2. Git installed on your computer.
3. (Optional) Your 6 trained `.pth` model checkpoint files:
   - `swin_best.pth`
   - `convnext_best.pth`
   - `effnet_best.pth`
   - `densenet_best.pth`
   - `unet_best.pth`
   - `best_teacher_ensemble.pth`

---

## Step 1: Create a New Space on Hugging Face

1. Log in to [Hugging Face](https://huggingface.co/).
2. Click on your profile picture in the top right and select **New Space** (or go to `https://huggingface.co/new-space`).
3. Fill in the details:
   - **Owner**: Your username
   - **Space name**: `veyrion-backend` (or any name you choose)
   - **License**: `mit`
   - **Select the Space SDK**: **Docker**
   - **Choose a Docker template**: **Blank**
   - **Space Hardware**: **CPU basic (Free)**
   - **Visibility**: **Public** (so the app can connect to it)
4. Click **Create Space**.

---

## Step 2: Prepare the Deployment Files

Everything required for Hugging Face is prepared in the `deploy_hf` directory in your workspace:

```
darm/
└── deploy_hf/
    ├── Dockerfile
    ├── README.md
    └── requirements.txt
```

---

## Step 3: Uploading Files to Hugging Face

### Method A: Direct Upload via Web Interface (Easiest)

1. Open your newly created Space on Hugging Face.
2. Click on the **Files** tab.
3. Click **Add file → Upload files**.
4. Drag and drop the contents of your `backend/app/` folder into the root of the Space files:
   - `app/` directory (containing `main.py`, `config.py`, `predictor.py`, `model.py`, `auth.py`, `chat.py`, `schemas.py`)
   - `Dockerfile` (from `deploy_hf/Dockerfile`)
   - `requirements.txt` (from `deploy_hf/requirements.txt`)
   - `README.md` (from `deploy_hf/README.md`)
5. If you have trained model weights:
   - Create a `weights/` folder inside the Space.
   - Upload your `.pth` files into `weights/`.
6. Click **Commit changes to main**.

---

### Method B: Via Git Command Line (Recommended for Large Files)

1. Clone your Space repository:
   ```bash
   git clone https://huggingface.co/spaces/<YOUR-USERNAME>/veyrion-backend
   cd veyrion-backend
   ```
2. Copy the backend code into the repository:
   - Copy everything from `backend/app/` into `app/`
   - Copy `deploy_hf/Dockerfile` to `Dockerfile`
   - Copy `deploy_hf/requirements.txt` to `requirements.txt`
   - Copy `deploy_hf/README.md` to `README.md`
   - If using weights, copy `.pth` files into `weights/`
3. Git LFS for weights (if `.pth` files are > 10MB):
   ```bash
   git lfs install
   git lfs track "*.pth"
   git add .gitattributes
   ```
4. Commit and push:
   ```bash
   git add .
   git commit -m "Deploy Veyrion inference backend"
   git push origin main
   ```

---

## Step 4: Verify Deployment & Test Endpoints

1. Hugging Face will automatically build and start the Docker container.
2. Once the build finishes, you will see a green **"Running"** status at the top.
3. Your Space public URL will be:
   `https://<YOUR-USERNAME>-veyrion-backend.hf.space`
4. Test the API endpoints in your browser:
   - Health check: `https://<YOUR-USERNAME>-veyrion-backend.hf.space/health`
   - Interactive OpenAPI docs: `https://<YOUR-USERNAME>-veyrion-backend.hf.space/docs`

---

## Step 5: (Optional) Adding Gemini API Key for Chat Assistant

If you want the in-app AI Assistant to answer patient questions using Gemini:

1. Get a free API key from [Google AI Studio](https://aistudio.google.com/).
2. In your Hugging Face Space, go to **Settings → Variables and secrets**.
3. Under **New secret**, add:
   - **Key**: `GEMINI_API_KEY`
   - **Value**: `your_actual_gemini_api_key`
4. Click **Save**. The Space will restart automatically with AI Assistant enabled.

---

## Step 6: Connect your Veyrion App to Hugging Face

In your mobile app:
- Navigate to **Settings → Server Settings**.
- Enter `https://<YOUR-USERNAME>-veyrion-backend.hf.space` in the API Base URL field.
- Tap **Save & test connection**.
