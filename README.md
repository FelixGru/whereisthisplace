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

`api/api/main.py` now adjusts `sys.path` automatically so the server can be launched from any directory.

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

## Bulk Data Loading

### Production Bulk Loader

Load large datasets of geolocated images for training:

```bash
# Basic usage (recommended - uses simplified processing)
python scripts/bulk_loader_production.py \
    --dataset-dir ./datasets/my_dataset \
    --source my_training_data \
    --max-concurrent 8

# Use batch processing mode (for testing/debugging)
python scripts/bulk_loader_production.py \
    --dataset-dir ./datasets/mapillary_paris \
    --source mapillary_dataset \
    --use-batch-processing \
    --batch-size 100

# With custom database and model URLs
python scripts/bulk_loader_production.py \
    --dataset-dir ./datasets/mapillary_paris \
    --source mapillary_dataset \
    --database-url postgresql://user:pass@localhost:5432/db \
    --model-url http://localhost:8080 \
    --log-level DEBUG
```

### Dataset Format

Create CSV files with the following format:

```csv
image,lat,lon,description
eiffel_tower.jpg,48.8584,2.2945,Eiffel Tower view
big_ben.jpg,51.4994,-0.1278,Big Ben clock tower
statue_liberty.jpg,40.6892,-74.0445,Statue of Liberty
```

### Mapillary Integration

Download training data from Mapillary with enhanced geographic filtering:

```bash
# Download images from Paris bounding box
# (Uses client-side filtering to ensure coordinates are within bbox)
python scripts/mapillary_downloader.py \
    --access-token YOUR_MAPILLARY_TOKEN \
    --bbox "2.2,48.8,2.4,48.9" \
    --output-dir ./datasets/mapillary_paris \
    --max-images 1000

# Then bulk load the downloaded dataset
python scripts/bulk_loader_production.py \
    --dataset-dir ./datasets/mapillary_paris \
    --source mapillary_training_data
```

**Enhanced Features:**
- **Client-side bbox filtering**: Validates coordinates actually fall within specified bounding box
- **10x over-sampling**: Requests more images than needed to account for Mapillary API bbox issues
- **Geographic verification**: Creates bbox_info.json with filtering statistics
- **Improved reliability**: Handles known Mapillary API coordinate filtering problems

### Performance

Expected throughput on EC2 GPU instance:
- **266,000+ images/hour** capacity (simplified processing mode)
- **33+ images/sec** processing rate (batch mode)
- **2.4M+ images/day** theoretical maximum

**Fixed Issues (v1.1):**
- ✅ **pgvector compatibility**: Fixed embedding list conversion to numpy arrays
- ✅ **Batch processing bugs**: Added simplified sequential mode as default
- ✅ **Mapillary bbox filtering**: Client-side geographic validation prevents coordinate issues
- ✅ **100% success rates**: Achieved with real-world datasets (Berlin, NYC, Paris, London)

The bulk loader includes:
- Concurrent processing with rate limiting
- Proper PostGIS geometry creation and pgvector embedding storage
- Progress tracking and comprehensive error handling
- Two processing modes: simplified (default) and batch processing
- Enhanced Mapillary integration with geographic verification

## Benchmarking

`scripts/benchmark.py` evaluates the API using the gold‑label datasets found
in `datasets/mapillary_paris*`. These three folders contain a total of 300
labeled images captured in Paris. The benchmark loads all images, sends them to
a running `/predict` endpoint and reports the Top‑1 accuracy (within 1&nbsp;km)
and mean distance error. The script exits with a non‑zero status if accuracy is
below 70%, allowing CI jobs to fail when the model regresses.

Run it after starting the API:

```bash
python scripts/benchmark.py --api-url http://localhost:8000
```

## Contribution Rules

1. Open an issue before major changes.
2. Fork the repo and create feature branches.
3. Ensure `poetry run pytest` and other tests pass before a PR.
4. Follow conventional commit messages.
5. One PR per topic; keep commits focused.

