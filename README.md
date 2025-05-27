# WhereIsThisPlace

AI-powered photo geolocation. Upload an image and receive a predicted location with confidence.

## Architecture

```
+---------------+      REST      +---------------+
|   Flutter     | <----------->  |    FastAPI    |
|   Mobile App  |                |    Backend    |
+---------------+                +---------------+
         | gRPC                         | SQL
         v                              v
  +-------------+                +-------------+
  | TorchServe  |                | PostGIS DB  |
  +-------------+                +-------------+
```

1. **Flutter app** uses Mapbox SDK for map tiles and sends photos to the backend.
2. **FastAPI backend** forwards images to TorchServe for inference and stores results in PostGIS.

## Quick Start

### Poetry (API)

```bash
cd api
poetry install
poetry run uvicorn api.main:app --reload
```

`api/main.py` adjusts `sys.path` automatically so the server can be launched from any directory.

You can also start the backend using the helper script from the project root:

```bash
bash scripts/run_api.sh
```

### Docker

To build and run the backend in Docker:

```bash
docker build -t whereisthisplace-api api
# Example run with port 8000
docker run -p 8000:8000 whereisthisplace-api
```

## Local Development

Run both the backend and Flutter app locally:

### Backend

```bash
cd api
poetry install
poetry run uvicorn api.main:app --reload
poetry run pytest
```

Alternatively run the helper script:

```bash
bash scripts/run_api.sh
```

### Flutter App

```bash
cd app
flutter pub get
flutter run
flutter test
```

## Contribution Rules

1. Open an issue before major changes.
2. Fork the repo and create feature branches.
3. Ensure `poetry run pytest` and other tests pass before a PR.
4. Follow conventional commit messages.
5. One PR per topic; keep commits focused.

