"""
DARM assistant — a grounded chatbot backed by Google Gemini (free tier).

The API key is read from the GEMINI_API_KEY environment variable (set it as a
Hugging Face Space secret, or in a local .env). It is NEVER shipped to the app;
the Flutter client only talks to this endpoint.

Answers are grounded in DARM's own class catalogue + model card + the user's
actual scan result, so replies are specific to their case rather than generic.
"""
from __future__ import annotations

import asyncio
import os
from typing import List, Optional

import httpx

from . import config

GEMINI_MODEL = os.getenv("DARM_GEMINI_MODEL", "gemini-3.6-flash")
GEMINI_URL = (
    "https://generativelanguage.googleapis.com/v1beta/models/"
    f"{GEMINI_MODEL}:generateContent"
)

LANG_NAMES = {"en": "English", "hi": "Hindi", "bn": "Bengali"}


def is_configured() -> bool:
    return bool(os.getenv("GEMINI_API_KEY"))


def _class_facts(code: Optional[str]) -> str:
    """Compact, factual notes for a class code (or all if none given)."""
    codes = [code] if code and code in config.CLASS_INFO else list(config.CLASS_INFO)
    lines = []
    for c in codes:
        info = config.CLASS_INFO[c]
        lines.append(
            f"- {info['name']} ({c}): {info['one_liner']} "
            f"Malignant={info['malignant']}, risk={info['risk']}. "
            f"Clinician note: {info['clinician_note']}"
        )
    return "\n".join(lines)


def _build_system_prompt(context: Optional[dict], lang: str, role: str) -> str:
    mc = config.MODEL_CARD
    reply_lang = LANG_NAMES.get(lang, "English")

    grounding = [
        "You are the DARM Assistant, a helpful, careful explainer inside the DARM "
        "(Dermoscopic AI Risk Monitor) skin-lesion screening app.",
        "",
        "ABOUT DARM (facts you must use, do not invent others):",
        "- DARM classifies a dermoscopic skin image into 7 HAM10000 classes: "
        "nv (mole), mel (melanoma), bkl, bcc, akiec, vasc, df.",
        "- It fuses five vision backbones (Swin-Tiny, ConvNeXt-Base, EfficientNet-B4, "
        "DenseNet-201, a multi-scale ResNet-34) plus patient metadata (age, sex, body site).",
        f"- Validation: accuracy {mc['accuracy']:.1%}, macro-F1 {mc['macro_f1']:.2f}, "
        f"melanoma recall {mc['melanoma_recall']:.1%}.",
        f"- KEY LIMITATION: {mc['key_caveat']}",
        "",
        "CLASS FACTS:",
        _class_facts(context.get("top_code") if context else None),
    ]

    if context:
        top = context.get("top_name") or context.get("top_code")
        prob = context.get("top_prob")
        unc = context.get("uncertainty")
        malig = context.get("malignant_probability")
        parts = []
        if top is not None and prob is not None:
            parts.append(f"top prediction = {top} at {float(prob) * 100:.0f}% resemblance")
        if malig is not None:
            parts.append(f"combined malignant probability = {float(malig) * 100:.0f}%")
        if unc is not None:
            parts.append(f"model uncertainty = {unc}")
        if parts:
            grounding += [
                "",
                "THIS USER'S CURRENT RESULT (refer to it specifically, do not be generic):",
                "- " + "; ".join(parts) + ".",
            ]

    grounding += [
        "",
        "HOW TO ANSWER — read this carefully:",
        f"- Reply in {reply_lang}.",
        "- FIRST, understand what THIS person is actually asking, and answer THAT exact "
        "question directly in your first sentence. Do not open with a generic definition "
        "or a restatement of the result — they can already see the numbers.",
        "- Sound like a caring human, not a textbook. Acknowledge the feeling behind the "
        "question when there is one (worry, confusion, relief). It is okay to be warm: "
        "\"I understand why that number feels scary — here's what it really means for you.\"",
        "- Be concrete and personal to THEIR result (use the actual class and percentages "
        "above). Never give one-size-fits-all filler that would fit any scan.",
        "- If they ask 'what should I do', give a clear, practical next step, not a lecture.",
        "- You are NOT a doctor and DARM is NOT a diagnosis. For anything clinical, gently "
        "point them to a dermatologist. Never tell someone they definitely do or do not "
        "have cancer, and never suggest skipping medical care.",
        "- If asked something outside skin health / this app, answer briefly and kindly, "
        "then steer back.",
        "- Keep it conversational: usually 2–4 short sentences. Plain text, no markdown "
        "headings, no bullet lists unless they ask for steps.",
    ]
    if role == "clinic":
        grounding.append(
            "- This user is a clinician: you may use precise terms (recall, precision, "
            "dermoscopy, biopsy) and discuss the model's per-class limits candidly, but "
            "stay concise and human."
        )
    return "\n".join(grounding)


async def answer(
    message: str,
    history: List[dict],
    context: Optional[dict],
    lang: str,
    role: str,
) -> str:
    api_key = os.getenv("GEMINI_API_KEY")
    if not api_key:
        return (
            "The assistant isn't configured yet (no GEMINI_API_KEY set on the server). "
            "Add a free Google AI Studio key as a Space secret to enable chat."
        )

    contents = []
    for m in history[-10:]:  # keep the last few turns for context
        r = "model" if m.get("role") == "assistant" else "user"
        contents.append({"role": r, "parts": [{"text": str(m.get("text", ""))}]})
    contents.append({"role": "user", "parts": [{"text": message}]})

    payload = {
        "system_instruction": {
            "parts": [{"text": _build_system_prompt(context, lang, role)}]
        },
        "contents": contents,
        "generationConfig": {
            "temperature": 0.75,          # warmer, more human phrasing
            "topP": 0.95,
            "maxOutputTokens": 1024,       # room so answers are never cut off
            # Gemini 3.x "thinks" by default and that eats the output budget,
            # truncating replies. Disable it for snappy, complete chat answers.
            "thinkingConfig": {"thinkingBudget": 0},
        },
    }

    # Gemini's free tier occasionally returns 503 ("overloaded") / 429 (rate).
    # Retry those transiently with a short backoff so users don't see a blip.
    last_status = None
    try:
        async with httpx.AsyncClient(timeout=30) as client:
            for attempt in range(3):
                resp = await client.post(
                    GEMINI_URL, params={"key": api_key}, json=payload
                )
                if resp.status_code == 200:
                    data = resp.json()
                    cand = (data.get("candidates") or [{}])[0]
                    parts = (cand.get("content") or {}).get("parts") or []
                    text = "".join(p.get("text", "") for p in parts).strip()
                    return text or (
                        "I couldn't generate a reply just now — please rephrase and try again."
                    )
                last_status = resp.status_code
                if resp.status_code in (429, 500, 503) and attempt < 2:
                    await asyncio.sleep(1.5 * (attempt + 1))
                    continue
                break
        return (
            "Sorry, the assistant is busy right now "
            f"(error {last_status}). Please try again in a few seconds."
        )
    except Exception:
        return (
            "Sorry, I couldn't reach the assistant right now. "
            "Please check your connection and try again."
        )
