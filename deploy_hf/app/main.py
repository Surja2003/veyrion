"""
DARM FastAPI inference service.

Endpoints
---------
GET  /health                 - liveness + whether real weights are loaded
GET  /meta/options           - metadata dropdown options + class catalogue + model card
POST /auth/login             - demo login (patient / clinic)
POST /predict                - image (+ age/sex/localization) -> 7-class result
"""
from __future__ import annotations

from typing import Optional

from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile, status
from fastapi.middleware.cors import CORSMiddleware

from . import __version__, auth, chat, config
from .predictor import get_predictor
from .schemas import (
    ChatRequest,
    ChatResponse,
    HealthResponse,
    LoginRequest,
    LoginResponse,
)

app = FastAPI(
    title="DARM - Skin Lesion Decision Support API",
    version=__version__,
    description="Multi-backbone feature-fusion skin lesion classifier (HAM10000, 7 classes). "
                "Decision-support only - not a diagnostic device.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=config.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
def _startup():
    get_predictor()  # warm-load weights (or enter mock mode)


@app.get("/health", response_model=HealthResponse)
def health():
    p = get_predictor()
    return HealthResponse(
        status="ok", version=__version__, mock_mode=p.mock, device=p.device,
        chat_enabled=chat.is_configured(),
    )


@app.post("/chat", response_model=ChatResponse)
async def chat_endpoint(body: ChatRequest, user: dict = Depends(auth.current_user)):
    reply = await chat.answer(
        message=body.message.strip(),
        history=[t.model_dump() for t in body.history],
        context=body.context,
        lang=body.lang,
        role=user.get("role", "patient"),
    )
    return ChatResponse(reply=reply)


@app.get("/meta/options")
def meta_options():
    """Everything the client needs to render forms and label results."""
    return {
        "sex": list(config.SEX_MAP.keys()),
        "localization": list(config.LOC_MAP.keys()),
        "classes": [
            {
                "code": code,
                "index": i,
                **{k: config.CLASS_INFO[code][k] for k in
                   ("name", "common_name", "malignant", "risk", "one_liner",
                    "patient_note", "clinician_note")},
            }
            for i, code in enumerate(config.LABEL_ORDER)
        ],
        "model_card": config.MODEL_CARD,
        "age_stats": {"mean": get_predictor().age_mean, "std": get_predictor().age_std},
    }


@app.post("/auth/login", response_model=LoginResponse)
def login(body: LoginRequest):
    rec = auth.verify_user(body.username, body.password)
    if not rec:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid username or password")
    token, expires_in = auth.create_token(body.username.strip().lower(), rec["role"], rec["name"])
    return LoginResponse(
        access_token=token, role=rec["role"], display_name=rec["name"], expires_in=expires_in
    )


def _looks_like_image(data: bytes) -> bool:
    """Validate by magic bytes rather than trusting the client's content-type
    (Flutter's http sends application/octet-stream by default)."""
    if len(data) < 12:
        return False
    return (
        data[:3] == b"\xff\xd8\xff"                 # JPEG
        or data[:8] == b"\x89PNG\r\n\x1a\n"          # PNG
        or data[:2] == b"BM"                          # BMP
        or data[:4] == b"GIF8"                        # GIF
        or (data[:4] == b"RIFF" and data[8:12] == b"WEBP")  # WEBP
    )


@app.post("/predict")
def predict(
    image: UploadFile = File(...),
    age: Optional[float] = Form(None),
    sex: str = Form("unknown"),
    localization: str = Form("unknown"),
    mc_dropout: bool = Form(True),
    user: dict = Depends(auth.current_user),
):
    data = image.file.read()
    if not data:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, "Empty image")
    if len(data) > 15 * 1024 * 1024:
        raise HTTPException(status.HTTP_413_REQUEST_ENTITY_TOO_LARGE, "Image too large (max 15MB)")
    # Accept if the content-type claims an image OR the bytes look like one.
    ct_ok = bool(image.content_type) and image.content_type.startswith("image/")
    if not ct_ok and not _looks_like_image(data):
        raise HTTPException(
            status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            "Uploaded file is not a recognised image (JPEG/PNG/BMP/GIF/WEBP).",
        )

    result = get_predictor().predict(
        image_bytes=data, age=age, sex=sex, localization=localization, mc_dropout=mc_dropout
    )
    # rename for pydantic-friendly field name; keep raw dict return for flexibility
    result["model_config_name"] = result.pop("model_config")
    result["requested_by_role"] = user.get("role")
    return result


@app.get("/")
def root():
    return {"service": "DARM inference", "version": __version__, "docs": "/docs"}
