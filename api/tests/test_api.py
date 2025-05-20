import sys
from pathlib import Path
from fastapi import FastAPI

ROOT = Path(__file__).resolve().parents[1].parent
sys.path.append(str(ROOT))
sys.path.append(str(ROOT / "api"))

from api.main import app


def test_app_is_fastapi_instance():
    assert isinstance(app, FastAPI)
    route_paths = {route.path for route in app.router.routes}
    assert "/health" in route_paths


def test_predict_endpoint_returns_location(tmp_path):
    import asyncio
    import json

    async def call_app():
        boundary = "testboundary"
        body = (
            f"--{boundary}\r\n"
            f"Content-Disposition: form-data; name=\"photo\"; filename=\"img.jpg\"\r\n"
            f"Content-Type: image/jpeg\r\n\r\n"
            f"data\r\n"
            f"--{boundary}--\r\n"
        ).encode()
        headers = [(b"content-type", f"multipart/form-data; boundary={boundary}".encode())]

        scope = {
            "type": "http",
            "asgi": {"version": "3.0"},
            "method": "POST",
            "path": "/predict",
            "raw_path": b"/predict",
            "query_string": b"",
            "headers": headers,
        }

        receive_queue = asyncio.Queue()
        await receive_queue.put({"type": "http.request", "body": body, "more_body": False})
        received = []

        async def receive():
            return await receive_queue.get()

        async def send(message):
            received.append(message)

        await app(scope, receive, send)
        status = None
        data = b""
        for message in received:
            if message["type"] == "http.response.start":
                status = message["status"]
            if message["type"] == "http.response.body":
                data += message.get("body", b"")

        return status, data

    status, data = asyncio.run(call_app())
    assert status == 200
    assert json.loads(data.decode()) == {"lat": 0.0, "lon": 0.0, "conf": 0.1}
