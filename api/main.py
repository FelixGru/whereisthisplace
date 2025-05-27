import sys
from pathlib import Path

# When this file is /app/api/main.py, ROOT becomes /app
ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))  # Ensure project root is on sys.path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes.predict import router as predict_router
# Corrected import for middleware:
from api.middleware import EphemeralUploadMiddleware, RateLimitMiddleware

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


@app.get("/health")
def health_check():
    """Simple health check endpoint used by deployment probes."""
    return {"status": "ok"}
