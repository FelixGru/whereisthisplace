from fastapi import APIRouter, Request, HTTPException
import re

from ml import retrieval, scene_classifier, fuse

router = APIRouter()


@router.post("/predict")
async def predict(request: Request):
    """Predict the location for an uploaded photo."""
    content_type = request.headers.get("Content-Type", "")
    match = re.search(r"boundary=(.+)", content_type)
    if not match:
        raise HTTPException(status_code=400, detail="Invalid Content-Type")
    boundary = match.group(1)

    body = await request.body()
    delimiter = ("--" + boundary).encode()
    for part in body.split(delimiter):
        if b"Content-Disposition" not in part:
            continue
        headers_end = part.find(b"\r\n\r\n")
        if headers_end == -1:
            continue
        headers = part[:headers_end].decode(errors="ignore")
        if 'name="photo"' not in headers:
            continue
        data = part[headers_end + 4 :]
        data = data.rstrip(b"\r\n--")
        image_bytes = data
        break
    else:
        raise HTTPException(status_code=400, detail="photo not provided")

    scene = scene_classifier.predict_topk(image_bytes, k=5)
    retr = retrieval.search(image_bytes, k=5)
    (lat, lon), conf = fuse.fuse(scene=scene, retrieval=retr)

    return {"lat": lat, "lon": lon, "conf": conf}
