import sys
from pathlib import Path
from fastapi import FastAPI
import asyncio
import os
import re
from fastapi.testclient import TestClient

API_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = API_ROOT.parent
sys.path.append(str(API_ROOT))
sys.path.append(str(PROJECT_ROOT))

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


def test_ephemeral_upload_cleanup_and_logging(capsys):
    client = TestClient(app)
    response = client.post(
        "/predict",
        files={"photo": ("test.jpg", b"dummy", "image/jpeg")},
    )
    assert response.status_code == 200

    captured = capsys.readouterr().out
    match = re.search(r"Saved upload to (/tmp/\S+)", captured)
    assert match is not None
    tmp_path = match.group(1)
    assert f"Deleting {tmp_path}" in captured
    assert not os.path.exists(tmp_path)
