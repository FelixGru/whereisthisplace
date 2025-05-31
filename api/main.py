import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes.predict import router as predict_router
from api.middleware import EphemeralUploadMiddleware, RateLimitMiddleware
from api.db import init_db, close_db
import requests
import os

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


TORCHSERVE_MANAGEMENT_URL = os.getenv('TORCHSERVE_MANAGEMENT_URL', 'http://localhost:8081')


@app.get("/health")
def health_check():
    """Report FastAPI and TorchServe status."""
    torchserve_status = 'unhealthy'
    models_data = {}

    try:
        # Use requests library which handles connection better
        response = requests.get(f'{TORCHSERVE_MANAGEMENT_URL}/models', timeout=10)

        if response.status_code == 200:
            models_data = response.json()
            # Check if models are loaded
            if models_data.get("models") and len(models_data["models"]) > 0:
                # Check specifically for the "where" model
                model_names = [model.get("modelName") for model in models_data.get("models", [])]
                if "where" in model_names:
                    torchserve_status = 'healthy'
                else:
                    torchserve_status = f'unhealthy - "where" model not found. Found models: {model_names}'
            else:
                torchserve_status = 'unhealthy - no models loaded'
        else:
            torchserve_status = f'unhealthy, status: {response.status_code}, body: {response.text}'
    except requests.exceptions.ConnectionError as e:
        torchserve_status = f'unhealthy: connection error - {str(e)}'
    except requests.exceptions.Timeout as e:
        torchserve_status = f'unhealthy: timeout - {str(e)}'
    except Exception as e:
        torchserve_status = f'unhealthy: {str(e)}'

    return {
        "fastapi_status": "healthy",
        "torchserve_status": torchserve_status,
        "torchserve_models": models_data,
        "message": "API is operational",
    }


@app.on_event("startup")
async def startup_event() -> None:
    await init_db(app)


@app.on_event("shutdown")
async def shutdown_event() -> None:
    await close_db(app)

