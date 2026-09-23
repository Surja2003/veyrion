# Veyrion inference service - Hugging Face Space (Docker SDK, CPU).
FROM python:3.11-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_ROOT_USER_ACTION=ignore \
    DARM_WEIGHTS_DIR=/app/weights \
    HF_HOME=/tmp/hf \
    TORCH_HOME=/tmp/torch

WORKDIR /app

# System deps for Pillow / torch runtime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 && rm -rf /var/lib/apt/lists/*

# CPU-only torch wheels keep the image small and the build fast.
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --index-url https://download.pytorch.org/whl/cpu torch==2.5.1 torchvision==0.20.1 && \
    pip install -r requirements.txt

COPY app ./app
COPY weights ./weights

# Hugging Face Spaces route external traffic to container port 7860.
EXPOSE 7860
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "7860"]
