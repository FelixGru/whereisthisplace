import sys
from pathlib import Path
import asyncio

API_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = API_ROOT.parent
sys.path.append(str(PROJECT_ROOT))
sys.path.append(str(API_ROOT))

from fastapi import FastAPI

from api.main import app


def test_app_is_fastapi_instance():
    assert isinstance(app, FastAPI)
    route_paths = {route.path for route in app.router.routes}
    assert "/health" in route_paths
    assert "/predict" in route_paths


class DummyUploadFile:
    def __init__(self, data: bytes):
        self.data = data

    async def read(self) -> bytes:
        return self.data


def test_predict_endpoint_returns_location():
    from routes.predict import predict

    file = DummyUploadFile(b"dummy")
    data = asyncio.run(predict(photo=file))
    assert data == {"latitude": 0.0, "longitude": 0.0, "confidence": 0.1}


def test_rate_limit_middleware_added():
    from api.middleware import RateLimitMiddleware
    middleware_classes = {m.cls for m in app.user_middleware}
    assert RateLimitMiddleware in middleware_classes

