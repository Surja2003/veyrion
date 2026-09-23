# Deploying Veyrion Backend to Render.com (100% FREE)

**Render.com** provides a **100% Free Web Service** tier for hosting Python / FastAPI applications without needing a credit card or paid subscription.

---

## Step 1: Create a Free Account on Render

1. Go to [render.com](https://render.com/).
2. Click **Get Started for Free** and sign up (you can sign in with your GitHub account).

---

## Step 2: Push your Code to GitHub

1. Create a new GitHub repository (e.g., `veyrion-backend`).
2. Push your `backend` folder to GitHub:
   ```bash
   git init
   git add .
   git commit -m "Initial Veyrion backend commit"
   git branch -M main
   git remote add origin https://github.com/<YOUR-USERNAME>/veyrion-backend.git
   git push -u origin main
   ```

---

## Step 3: Create a New Web Service on Render

1. In your Render Dashboard, click **New +** → **Web Service**.
2. Connect your GitHub repository (`veyrion-backend`).
3. Fill in the deployment settings:
   - **Name**: `veyrion-backend` (or your preferred name)
   - **Language**: `Python 3`
   - **Region**: Choose the closest region (e.g., Oregon, Frankfurt, Singapore)
   - **Branch**: `main`
   - **Root Directory**: `backend` (if your code is inside the `backend` folder)
   - **Build Command**:
     ```bash
     pip install -r requirements-min.txt
     ```
     *(Use `requirements.txt` if uploading real `.pth` PyTorch model weights)*
   - **Start Command**:
     ```bash
     uvicorn app.main:app --host 0.0.0.0 --port $PORT
     ```
   - **Instance Type**: Select **Free** ($0 / month).

---

## Step 4: (Optional) Set Environment Variables

Under **Environment Variables**, add any optional config:
- `GEMINI_API_KEY`: `your_gemini_api_key` (if enabling the AI assistant)
- `DARM_CORS_ORIGINS`: `*`

---

## Step 5: Deploy & Connect to Veyrion App

1. Click **Create Web Service**.
2. Render will build and deploy your service.
3. Once deployed, Render will provide a free HTTPS URL:
   `https://veyrion-backend.onrender.com`
4. Test the health endpoint in your browser:
   `https://veyrion-backend.onrender.com/health`

### Connecting the Veyrion Mobile App:
1. Open **Veyrion™** on your phone.
2. Go to **Settings → Server Settings**.
3. Set **API Base URL** to `https://veyrion-backend.onrender.com`.
4. Tap **Save & test connection**.
