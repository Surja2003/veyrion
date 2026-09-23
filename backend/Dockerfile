# DARM inference service - production image (CPU).
# For GPU, start from an nvidia/cuda base and install the matching torch build.
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DARM_WEIGHTS_DIR=/app/weights

WORKDIR /app

# System deps for Pillow/torch
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --upgrade pip && pip install -r requirements.txt

COPY app ./app
COPY weights ./weights

EXPOSE 8000
# Hugging Face Spaces expects port 7860; override CMD there or set --port 7860.
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
