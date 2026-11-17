FROM python:3.12-slim

WORKDIR /app
ENV PYTHONUNBUFFERED=1

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY main.py .
COPY templates ./templates

EXPOSE 8000

# `opentelemetry-instrument` liga a instrumentação automática (FastAPI + psycopg).
# Para onde enviar os traces é definido pelas variáveis OTEL_* no app-deployment.yaml.
CMD ["opentelemetry-instrument", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
