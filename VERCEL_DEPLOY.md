# Deploying Veyrion Web App to Vercel (100% FREE)

You can host the **Veyrion Flutter Web App** on **Vercel** for free. Flutter compiles your UI into static Web assets (`HTML/JS/CSS`) that run blazingly fast on Vercel's global CDN.

---

## How it Works Architecture-wise

```
+--------------------------+           HTTP POST /predict            +---------------------------------+
|   Veyrion Mobile App /   | --------------------------------------> |    Render.com FastAPI Backend   |
|   Vercel Web App UI      | <-------------------------------------- | (https://veyrion-ut8u.onrender.com) |
+--------------------------+           JSON Predictions Output       +---------------------------------+
```

- **Frontend (Flutter Web / Vercel)**: Serves the responsive mobile & desktop Web UI.
- **Backend (FastAPI / Render)**: Handles PyTorch model inference, 7-class prediction, and AI chat assistant.

---

## Step-by-Step Vercel Deployment

### Method A: Via GitHub (Recommended)

1. **Build the Web App locally (Optional test)**:
   ```bash
   cd app
   flutter build web --release
   ```

2. **Push your code to GitHub**:
   ```bash
   git add .
   git commit -m "Add Veyrion Web support"
   git push origin main
   ```

3. **Deploy on Vercel**:
   - Go to [vercel.com](https://vercel.com/) and sign in with GitHub.
   - Click **Add New... → Project**.
   - Select your repository (`veyrion-backend` or `veyrion`).
   - Under **Build and Output Settings**:
     - **Framework Preset**: `Other`
     - **Build Command**: `cd app && flutter build web --release`
     - **Output Directory**: `app/build/web`
   - Click **Deploy**.

---

### Method B: Direct Upload via Vercel CLI

If you want to deploy directly from your terminal:

1. **Install Vercel CLI**:
   ```bash
   npm install -g vercel
   ```

2. **Build the Flutter Web static bundle**:
   ```bash
   cd app
   flutter build web --release
   ```

3. **Deploy the `build/web` folder directly**:
   ```bash
   cd build/web
   vercel --prod
   ```

Vercel will give you a live HTTPS link (e.g., `https://veyrion.vercel.app`).
