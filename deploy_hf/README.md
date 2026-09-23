---
title: Veyrion Backend
emoji: 🩺
colorFrom: blue
colorTo: green
sdk: docker
app_port: 7860
pinned: false
license: mit
short_description: Veyrion skin-lesion decision-support inference API (5-backbone fusion)
---

# Veyrion — Dermoscopic AI Risk Monitor (Backend)

FastAPI inference service for the Veyrion skin-lesion classifier: a five-backbone
feature-fusion model (Swin-Tiny, ConvNeXt-Base, EfficientNet-B4, DenseNet-201,
multi-scale ResNet-34) + patient-metadata branch → 7 HAM10000 classes.

**Research / educational use only — not a medical device and not a diagnosis.
Always consult a qualified dermatologist.**

## Endpoints
- `GET  /health` — liveness + whether real weights are loaded
- `GET  /meta/options` — form options, class catalogue, model card
- `POST /auth/login` — demo login (patient / clinic)
- `POST /predict` — image (+ age/sex/localization) → 7-class result
- `GET  /docs` — interactive Swagger UI

Built for the Veyrion Flutter app (Android / Web / Windows).
