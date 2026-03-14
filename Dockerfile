FROM python:3.11-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY requirements-backend.txt /tmp/requirements-backend.txt

RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r /tmp/requirements-backend.txt \
    && pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu --extra-index-url https://pypi.org/simple torch torchvision \
    && mkdir -p /app/models /runtime/logs /runtime/summaries /runtime/models

COPY backend_helpers.py backend_service.py master.py worker.py predict.py train.py train_dist.py run.py /app/

EXPOSE 8000 8080

CMD ["uvicorn", "backend_service:app", "--host", "0.0.0.0", "--port", "8080"]
