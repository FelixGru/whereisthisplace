.PHONY: help build up down logs shell test clean

help:
	@echo "Available commands:"
	@echo "  make build       - Build Docker images (GPU)"
	@echo "  make build-cpu   - Build Docker images (CPU)"
	@echo "  make up          - Start all services (GPU)"
	@echo "  make up-cpu      - Start all services (CPU)"
	@echo "  make down        - Stop all services"
	@echo "  make logs        - Show logs"
	@echo "  make shell       - Enter backend container"
	@echo "  make test        - Run tests"
	@echo "  make clean       - Clean up containers and volumes"
	@echo "  make load_dataset - Load dataset into the database"

# Build Docker images (GPU) - DEFAULT
build:
	docker-compose -f docker-compose.gpu-final.yml build

# Build Docker images (CPU)
build-cpu:
	docker-compose -f docker-compose.cpu.yml build

# Start services (GPU) - DEFAULT
up:
	docker-compose -f docker-compose.gpu-final.yml up -d

# Start services with logs (GPU)
up-logs:
	docker-compose -f docker-compose.gpu-final.yml up

# Start services (CPU)
up-cpu:
	docker-compose -f docker-compose.cpu.yml up -d

# Start services with logs (CPU)
up-cpu-logs:
	docker-compose -f docker-compose.cpu.yml up

# Stop services
down:
	docker-compose -f docker-compose.gpu-final.yml down
	docker-compose -f docker-compose.cpu.yml down 2>/dev/null || true

# View logs
logs:
	docker-compose -f docker-compose.gpu-final.yml logs -f

logs-cpu:
	docker-compose -f docker-compose.cpu.yml logs -f

# Enter backend shell
shell:
	docker-compose -f docker-compose.gpu-final.yml exec backend bash

shell-cpu:
	docker-compose -f docker-compose.cpu.yml exec backend bash

# Run tests
test:
	docker-compose -f docker-compose.gpu-final.yml exec backend poetry run pytest

test-cpu:
	docker-compose -f docker-compose.cpu.yml exec backend poetry run pytest

# Clean everything
clean:
	docker-compose -f docker-compose.gpu-final.yml down -v
	docker-compose -f docker-compose.cpu.yml down -v 2>/dev/null || true
	docker system prune -f

# Database shell
db-shell:
	docker-compose -f docker-compose.gpu-final.yml exec postgres psql -U postgres -d whereisthisplace

db-shell-cpu:
	docker-compose -f docker-compose.cpu.yml exec postgres psql -U whereuser -d whereisthisplace

# Check health
health:
	curl http://localhost:8000/health

# Load dataset
load_dataset:
	docker-compose -f docker-compose.gpu-final.yml run --rm backend python scripts/load_dataset.py

load_dataset_cpu:
	docker-compose -f docker-compose.cpu.yml run --rm backend python scripts/load_dataset.py
