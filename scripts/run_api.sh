#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

# Switch to the Poetry project directory
cd api

# Install dependencies needed to run the FastAPI server
poetry install --only main

# Launch the development server
exec poetry run uvicorn api.main:app --reload --port 8000
