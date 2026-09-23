# DARM Inference Backend (FastAPI)

Serves the multi-backbone feature-fusion skin lesion classifier as a REST API.
Image (+ optional age/sex/localization) in → 7-class probabilities, uncertainty,
and framing out. Matches the exact architecture and metadata encoding from the
training notebooks.

> **Not a medical device.** Decision-support only. See the model card caveats
> (especially melanoma recall ≈ 0.69). Never use it to rule out cancer.

## Quick start (mock mode — no weights, no torch)

```bash
cd backend
python -m venv .venv
# Windows:  .venv\Scripts\activate
# macOS/Linux:  source .venv/bin/activate
pip install -r requirements-min.txt
uvicorn app.main:app --reload --port 8000
```

Open http://localhost:8000/docs. Responses will have `"mock": true`.

## Real inference

1. `pip install -r requirements.txt` (adds torch / torchvision / timm).
2. Put the six checkpoints in `weights/` (see `weights/README.md`).
3. Restart. `/health` will report `"mock_mode": false`.

## Endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/health` | Liveness + whether real weights loaded |
| GET | `/meta/options` | Sex/localization options, class catalogue, model card |
| POST | `/auth/login` | Demo login → JWT + role (`patient`/`clinic`) |
| POST | `/predict` | multipart: `image`, `age`, `sex`, `localization`, `mc_dropout` |

### Demo logins
- `patient` / `patient123`
- `clinic` / `clinic123`

### Example

```bash
TOKEN=$(curl -s -X POST localhost:8000/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"username":"clinic","password":"clinic123"}' | python -c "import sys,json;print(json.load(sys.stdin)['access_token'])")

curl -s -X POST localhost:8000/predict \
  -H "Authorization: Bearer $TOKEN" \
  -F "image=@lesion.jpg" -F "age=55" -F "sex=male" -F "localization=back"
```

## Deploy
- **Docker:** `docker build -t darm-api . && docker run -p 8000:8000 -v $PWD/weights:/app/weights darm-api`
- **Hugging Face Spaces (Docker SDK):** use this `Dockerfile`; set the port to 7860. Upload weights as Space files or pull from a private model repo at startup.

## Configuration (env vars)
| Var | Default | Meaning |
|-----|---------|---------|
| `DARM_WEIGHTS_DIR` | `./weights` | Where checkpoints live |
| `DARM_JWT_SECRET` | (dev default) | **Change in production** |
| `DARM_CORS_ORIGINS` | `*` | Comma-separated allowed origins |
