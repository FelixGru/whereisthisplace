#!/usr/bin/env python3
"""Benchmark harness for WhereIsThisPlace API.

Loads gold-label images and evaluates model predictions.
Updated to trigger CI workflow.
"""
import argparse
import csv
import sys
import time
import random
from math import radians, sin, cos, sqrt, atan2
from pathlib import Path
from typing import Iterable, Tuple, List

import requests


def haversine(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """Return distance in kilometers between two lat/lon coordinates."""
    r = 6371.0
    lat1, lon1, lat2, lon2 = map(radians, [lat1, lon1, lat2, lon2])
    dlat = lat2 - lat1
    dlon = lon2 - lon1
    a = sin(dlat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(dlon / 2) ** 2
    c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return r * c


def collect_all_images(dataset_dir: Path) -> List[Tuple[Path, float, float]]:
    """Collect all available images from dataset directory."""
    images = []
    for csv_path in dataset_dir.rglob("*.csv"):
        with csv_path.open(newline="") as f:
            reader = csv.DictReader(f)
            for row in reader:
                img = csv_path.parent / row["image"]
                if img.exists():
                    images.append((img, float(row["lat"]), float(row["lon"])))
                else:
                    print(f"Warning: Image file not found: {img}", file=sys.stderr)
    return images


def iter_dataset(dataset_dir: Path, max_images: int = None, random_seed: int = None) -> Iterable[Tuple[Path, float, float]]:
    """Yield (image_path, lat, lon) for images, optionally randomized."""
    images = collect_all_images(dataset_dir)
    
    if random_seed is not None:
        random.seed(random_seed)
        random.shuffle(images)
        print(f"🎲 Using random seed {random_seed} for reproducible sampling")
    elif max_images and max_images < len(images):
        # Use a time-based seed for different samples each run
        seed = int(time.time()) % 10000
        random.seed(seed)
        random.shuffle(images)
        print(f"🎲 Randomly sampling {max_images} from {len(images)} images (seed: {seed})")
    
    count = 0
    for img_path, lat, lon in images:
        if max_images and count >= max_images:
            break
        yield img_path, lat, lon
        count += 1


def evaluate(dataset_dir: Path, api_url: str, threshold_km: float, max_images: int = None, random_seed: int = None) -> Tuple[float, float, dict]:
    """Evaluate model performance and return accuracy, mean error, and detailed stats."""
    distances = []
    correct = 0
    total = 0
    errors = []
    start_time = time.time()
    
    print(f"Starting benchmark evaluation...")
    print(f"Dataset directory: {dataset_dir}")
    print(f"API URL: {api_url}")
    print(f"Threshold: {threshold_km} km")
    if max_images:
        print(f"Max images: {max_images}")
    if random_seed is not None:
        print(f"Random seed: {random_seed}")
    print("-" * 50)
    
    for img_path, lat, lon in iter_dataset(dataset_dir, max_images, random_seed):
        if not img_path.exists():
            print(f"Skipping missing file: {img_path}")
            continue
            
        try:
            with open(img_path, "rb") as f:
                files = {"photo": (img_path.name, f, "image/jpeg")}
                resp = requests.post(f"{api_url.rstrip('/')}/predict", files=files, timeout=60)
                resp.raise_for_status()
                data = resp.json()
                
                # Handle different response formats
                prediction = data.get("prediction", data)
                if isinstance(prediction, dict):
                    pred_lat = float(prediction["lat"])
                    pred_lon = float(prediction["lon"])
                else:
                    # Fallback for direct lat/lon response
                    pred_lat = float(prediction.get("lat", data.get("lat")))
                    pred_lon = float(prediction.get("lon", data.get("lon")))
                    
        except requests.exceptions.Timeout:
            error_msg = f"Timeout on {img_path.name}"
            print(error_msg, file=sys.stderr)
            errors.append(error_msg)
            continue
        except requests.exceptions.RequestException as exc:
            error_msg = f"Request error on {img_path.name}: {exc}"
            print(error_msg, file=sys.stderr)
            errors.append(error_msg)
            continue
        except (KeyError, ValueError, TypeError) as exc:
            error_msg = f"Response parsing error on {img_path.name}: {exc}"
            print(error_msg, file=sys.stderr)
            errors.append(error_msg)
            continue
        except Exception as exc:
            error_msg = f"Unexpected error on {img_path.name}: {exc}"
            print(error_msg, file=sys.stderr)
            errors.append(error_msg)
            continue
            
        # Calculate distance and accuracy
        dist = haversine(lat, lon, pred_lat, pred_lon)
        distances.append(dist)
        if dist <= threshold_km:
            correct += 1
        total += 1
        
        # Progress indicator
        if total % 10 == 0:
            current_acc = (correct / total) * 100 if total > 0 else 0
            print(f"Processed {total} images, current accuracy: {current_acc:.1f}%")
        
        # Small delay to avoid overwhelming the API
        time.sleep(0.1)
    
    elapsed_time = time.time() - start_time
    
    if not total:
        return 0.0, float("inf"), {
            "total_processed": 0,
            "errors": len(errors),
            "error_details": errors,
            "elapsed_time": elapsed_time
        }
    
    mean_error = sum(distances) / total
    accuracy = (correct / total) * 100
    
    # Calculate additional statistics
    distances.sort()
    median_error = distances[len(distances) // 2] if distances else 0
    p95_error = distances[int(len(distances) * 0.95)] if distances else 0
    
    stats = {
        "total_processed": total,
        "correct_predictions": correct,
        "errors": len(errors),
        "error_details": errors[:10],  # Only show first 10 errors
        "elapsed_time": elapsed_time,
        "images_per_second": total / elapsed_time if elapsed_time > 0 else 0,
        "median_error_km": median_error,
        "p95_error_km": p95_error,
        "min_error_km": min(distances) if distances else 0,
        "max_error_km": max(distances) if distances else 0
    }
    
    return accuracy, mean_error, stats


def main() -> None:
    parser = argparse.ArgumentParser(description="Run benchmark against API")
    parser.add_argument(
        "--dataset-dir",
        type=Path,
        default=Path("datasets"),
        help="Directory containing gold-label datasets",
    )
    parser.add_argument(
        "--api-url",
        default="http://localhost:8000",
        help="Base URL of the API",
    )
    parser.add_argument(
        "--threshold-km",
        type=float,
        default=1.0,
        help="Distance threshold in km for Top-1 accuracy",
    )
    parser.add_argument(
        "--max-images",
        type=int,
        help="Maximum number of images to process (for testing)",
    )
    parser.add_argument(
        "--random-seed",
        type=int,
        help="Random seed for reproducible image sampling",
    )
    args = parser.parse_args()

    # Verify API is accessible
    try:
        health_resp = requests.get(f"{args.api_url}/health", timeout=10)
        if health_resp.status_code != 200:
            print(f"Warning: API health check failed with status {health_resp.status_code}")
        else:
            print("✅ API health check passed")
    except Exception as e:
        print(f"Warning: Could not reach API health endpoint: {e}")

    acc, mean_err, stats = evaluate(args.dataset_dir, args.api_url, args.threshold_km, args.max_images, args.random_seed)
    
    print("\n" + "=" * 60)
    print("BENCHMARK RESULTS")
    print("=" * 60)
    print(f"Dataset: {args.dataset_dir}")
    print(f"Images processed: {stats['total_processed']}")
    print(f"Correct predictions: {stats['correct_predictions']}")
    print(f"Processing errors: {stats['errors']}")
    print(f"Elapsed time: {stats['elapsed_time']:.1f}s")
    print(f"Processing rate: {stats['images_per_second']:.1f} images/second")
    print("-" * 60)
    print(f"Top-1 Accuracy (≤{args.threshold_km}km): {acc:.2f}%")
    print(f"Mean Error: {mean_err:.2f} km")
    print(f"Median Error: {stats['median_error_km']:.2f} km")
    print(f"95th Percentile Error: {stats['p95_error_km']:.2f} km")
    print(f"Min Error: {stats['min_error_km']:.2f} km")
    print(f"Max Error: {stats['max_error_km']:.2f} km")
    print("=" * 60)

    # Show error details if any
    if stats['errors'] > 0:
        print(f"\nFirst {len(stats['error_details'])} errors:")
        for error in stats['error_details']:
            print(f"  - {error}")

    # Determine exit code based on accuracy threshold
    if acc < 70.0:
        print(f"\n❌ BENCHMARK FAILED: Accuracy {acc:.2f}% is below required 70%")
        sys.exit(1)
    else:
        print(f"\n✅ BENCHMARK PASSED: Accuracy {acc:.2f}% meets required 70%")


if __name__ == "__main__":
    main()
