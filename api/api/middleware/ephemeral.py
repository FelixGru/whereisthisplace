from pathlib import Path
import tempfile
from fastapi import Request, UploadFile
from starlette.middleware.base import BaseHTTPMiddleware


class EphemeralUploadMiddleware(BaseHTTPMiddleware):
    """Save uploaded file to /tmp and remove it after the response."""

    async def dispatch(self, request: Request, call_next):
        if request.method == "POST" and request.url.path == "/predict":
            form = await request.form()
            upload = form.get("photo")
            if isinstance(upload, UploadFile):
                suffix = Path(upload.filename or "").suffix
                with tempfile.NamedTemporaryFile(
                    delete=False, suffix=suffix, dir="/tmp"
                ) as tmp:
                    data = await upload.read()
                    tmp.write(data)
                    tmp_path = Path(tmp.name)
                print(f"Saved upload to {tmp_path}")
                request.state.temp_file_path = tmp_path
                upload.file.seek(0)
                response = await call_next(request)
                print(f"Deleting {tmp_path}")
                tmp_path.unlink(missing_ok=True)
                return response
        response = await call_next(request)
        return response

