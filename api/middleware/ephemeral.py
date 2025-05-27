import os
import tempfile
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request


class EphemeralUploadMiddleware(BaseHTTPMiddleware):
    """Save request body to a temporary file and remove it after the response."""

    async def dispatch(self, request: Request, call_next):
        body = await request.body()
        request._body = body
        fd, path = tempfile.mkstemp(dir="/tmp", prefix="upload_", suffix=".bin")
        with os.fdopen(fd, "wb") as tmp:
            tmp.write(body)
        print(f"Saved upload to {path}")
        try:
            response = await call_next(request)
        finally:
            try:
                os.unlink(path)
                print(f"Deleted upload {path}")
            except FileNotFoundError:
                pass
        return response
