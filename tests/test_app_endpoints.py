import sys
from pathlib import Path
import importlib
import asyncio

from fastapi.testclient import TestClient

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(1, str(ROOT / "api"))

import api.main
from routes.predict import predict


def get_fresh_client():
    importlib.reload(api.main)
    return TestClient(api.main.app)


class DummyUploadFile:
    def __init__(self, data: bytes):
        self.data = data

    async def read(self) -> bytes:
        return self.data


def test_health_endpoint_returns_200():
    client = get_fresh_client()
    resp = client.get("/health")
    assert resp.status_code == 200
    data = resp.json()
    assert data.get("fastapi_status") == "healthy"
    assert "torchserve_status" in data


def test_predict_returns_expected_data():
    file = DummyUploadFile(b"dummy")
    result = asyncio.run(predict(photo=file))
    assert result == {"latitude": 0.0, "longitude": 0.0, "confidence": 0.1}


def test_rate_limit_returns_429_after_limit_exceeded():
    client = get_fresh_client()
    for _ in range(10):
        resp = client.get("/health")
        assert resp.status_code == 200
    resp = client.get("/health")
    assert resp.status_code == 429

