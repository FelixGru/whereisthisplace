import os
import re
import sys
from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.testclient import TestClient

API_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = API_ROOT.parent
sys.path.append(str(PROJECT_ROOT))
sys.path.append(str(API_ROOT))

from api.middleware import EphemeralUploadMiddleware

app = FastAPI()
app.add_middleware(EphemeralUploadMiddleware)

@app.post('/upload')
async def upload(request: Request):
    data = await request.body()
    return {'size': len(data)}

client = TestClient(app)

def test_upload_removed_and_logged(capsys):
    response = client.post('/upload', data=b'dummy')
    assert response.status_code == 200
    logs = capsys.readouterr().out
    match = re.search(r"Saved upload to (.+)", logs)
    assert match is not None
    path = match.group(1).strip()
    assert not os.path.exists(path)
