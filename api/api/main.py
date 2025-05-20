import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.append(str(ROOT))

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes.predict import router as predict_router
from .middleware.ephemeral import EphemeralUploadMiddleware

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

app.include_router(predict_router)

@app.get("/")
def read_root():
    return {"message": "Hello World"}


@app.get("/health")
def health_check():
    """Simple health check endpoint used by deployment probes."""
    return {"status": "ok"}
