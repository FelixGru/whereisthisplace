import sys
from pathlib import Path

# When this file is /app/api/main.py, ROOT becomes /app
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))  # Ensures /app is in sys.path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes.predict import router as predict_router
# Corrected import for middleware:
from api.middleware import EphemeralUploadMiddleware, RateLimitMiddleware
import http.client
import json
from urllib.parse import urlparse

app = FastAPI()

# Allow all origins for now. The Flutter app will run on a different port
# during development, so permissive CORS simplifies local testing.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)
app.add_middleware(EphemeralUploadMiddleware)
app.add_middleware(RateLimitMiddleware)

app.include_router(predict_router)

@app.get("/")
def read_root():
    return {"message": "Hello World"}


TORCHSERVE_MANAGEMENT_URL = "http://localhost:8081"


@app.get("/health")
def health_check():
    """Report FastAPI and TorchServe status."""
    parsed = urlparse(TORCHSERVE_MANAGEMENT_URL)
    models_data = {}
    torchserve_status = "unhealthy"
    try:
        conn = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=10)
        conn.request("GET", "/models")
        resp = conn.getresponse()
        body = resp.read().decode()
        if resp.status == 200:
            data = json.loads(body)
            models_data = data
            if any(m.get("modelName") == "where" for m in data.get("models", [])):
                torchserve_status = "healthy"
            else:
                torchserve_status = 'unhealthy - model "where" not found'
        else:
            torchserve_status = f"unhealthy, status: {resp.status}, body: {body}"
    except Exception as e:
        torchserve_status = f"unhealthy: {e}"

    return {
        "fastapi_status": "healthy",
        "torchserve_status": torchserve_status,
        "torchserve_models": models_data,
        "message": "API is operational",
    }

