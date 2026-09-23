"""Pydantic response/request schemas."""
from __future__ import annotations

from typing import List, Optional

from pydantic import BaseModel


class LoginRequest(BaseModel):
    username: str
    password: str


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    role: str            # "patient" | "clinic"
    display_name: str
    expires_in: int


class ClassResult(BaseModel):
    code: str
    index: int
    name: str
    common_name: str
    probability: float
    resemblance_pct: float
    malignant: bool
    risk: str
    uncertainty: Optional[float] = None
    one_liner: str
    patient_note: str
    clinician_note: str


class TopResult(BaseModel):
    code: str
    name: str
    common_name: str
    probability: float
    resemblance_pct: float
    risk: str
    malignant: bool


class Confidence(BaseModel):
    top_probability: float
    entropy_normalised: float
    level: str
    mc_dropout_available: bool
    mean_uncertainty: Optional[float] = None


class Urgency(BaseModel):
    band: str
    label: str
    message: str


class PredictionResponse(BaseModel):
    mock: bool
    model_config_name: str
    top: TopResult
    classes: List[ClassResult]
    ranking: List[str]
    malignant_probability: float
    confidence: Confidence
    urgency: Urgency
    latency_ms: float


class HealthResponse(BaseModel):
    status: str
    version: str
    mock_mode: bool
    device: str
    chat_enabled: bool = False


class ChatTurn(BaseModel):
    role: str            # "user" | "assistant"
    text: str


class ChatRequest(BaseModel):
    message: str
    history: List[ChatTurn] = []
    context: Optional[dict] = None   # {top_code, top_name, top_prob, malignant_probability, uncertainty}
    lang: str = "en"                 # "en" | "hi" | "bn"


class ChatResponse(BaseModel):
    reply: str
