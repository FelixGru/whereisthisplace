# Benchmark Harness

This document describes the benchmark harness for the WhereIsThisPlace API, which evaluates model accuracy using gold-label datasets.

## Overview

The benchmark harness (`scripts/benchmark.py`) loads gold-label images with known locations and tests the API's prediction accuracy. It calculates:

- **Top-1 Accuracy**: Percentage of predictions within a specified distance threshold
- **Mean Error**: Average distance error in kilometers
- **Additional Statistics**: Median error, 95th percentile, min/max errors, processing rate

## ⚠️ Important Limitations

**Static Test Set Issue**: The current benchmark uses the same gold-label images repeatedly. This means:

✅ **Good for**: Detecting regressions, API failures, infrastructure issues  
❌ **Limited for**: Catching gradual model drift, validating generalization to new data

### Solutions for Better Validation

1. **Random Sampling** (Implemented): Each run samples different subsets
2. **Continuous Data Collection**: Add new test images regularly
3. **A/B Testing**: Compare against baseline model performance
4. **User Feedback Integration**: Track real-world prediction quality

## Gold-Label Datasets

The benchmark uses 500+ gold-label images from Mapillary, organized in the `datasets/` directory:

```
datasets/
├── mapillary_paris/           # ~100 Paris images
├── mapillary_paris_batch2/    # Additional Paris images  
└── mapillary_paris_batch3/    # More Paris images
```

Each dataset contains:
- **Images**: `.jpg` files with Mapillary street view photos
- **Metadata**: `.csv` files with image filenames and true coordinates
- **Format**: `image,lat,lon,description,mapillary_id,captured_at,verified_bbox`

## Usage

### Manual Testing

Use the interactive script for local testing:

```bash
./scripts/run_benchmark_manual.sh
```

This script provides options for:
1. Quick test (10 images)
2. Paris dataset (100 images) 
3. Full benchmark (300 images)
4. Custom configuration

### Direct Script Usage

Run the benchmark script directly:

```bash
# Basic usage - Paris dataset
python3 scripts/benchmark.py --dataset-dir datasets/mapillary_paris

# Full benchmark with 300 randomly sampled images
python3 scripts/benchmark.py \
    --dataset-dir datasets \
    --max-images 300 \
    --threshold-km 25.0 \
    --api-url http://localhost:8000

# Reproducible test with fixed seed
python3 scripts/benchmark.py \
    --dataset-dir datasets \
    --max-images 300 \
    --random-seed 42 \
    --threshold-km 25.0
```

### Parameters

- `--dataset-dir`: Directory containing gold-label datasets (default: `datasets`)
- `--api-url`: API base URL (default: `http://localhost:8000`)
- `--threshold-km`: Distance threshold for accuracy calculation (default: `1.0`)
- `--max-images`: Maximum number of images to process (optional)
- `--random-seed`: Fixed seed for reproducible sampling (optional)

### Threshold Guidelines

- **1 km**: Precise location accuracy (street-level)
- **25 km**: City-level accuracy (recommended for CI)
- **100 km**: Regional accuracy

## CI/CD Integration

### GitHub Actions Workflow

The benchmark runs automatically via `.github/workflows/benchmark.yml`:

- **Triggers**: Push to main, PRs affecting API/ML code, manual dispatch
- **Environment**: Ubuntu with PostgreSQL service
- **Sampling**: Random 300 images per run (different subset each time)
- **Process**: 
  1. Build Docker image
  2. Start API service
  3. Run benchmark on 300 images
  4. Fail if accuracy < 70%

### Definition of Done

✅ **CI job fails if Top-1 accuracy < 70%** (with 25km threshold)

This ensures model performance doesn't regress with code changes.

**Note**: Since we use random sampling, occasional failures due to particularly challenging subsets are possible. Consider the trend over multiple runs rather than individual failures.

## Improving Benchmark Robustness

### 1. Expand Test Data

```bash
# Add new datasets regularly
scripts/mapillary_downloader.py --city "London" --count 100
scripts/mapillary_downloader.py --city "Tokyo" --count 100
scripts/mapillary_downloader.py --city "New York" --count 100
```

### 2. Geographic Diversity

Current datasets focus on Paris. Consider adding:
- Different cities and countries
- Rural vs urban locations
- Various weather/lighting conditions
- Different architectural styles

### 3. Baseline Comparison

Track performance trends:

```bash
# Store results for comparison
python3 scripts/benchmark.py --max-images 300 > results/baseline_$(date +%Y%m%d).txt

# Compare against baseline
python3 scripts/compare_benchmarks.py results/baseline_*.txt
```

### 4. Confidence-Based Filtering

Filter out low-confidence predictions:

```bash
# Only count high-confidence predictions
python3 scripts/benchmark.py --min-confidence 0.7 --threshold-km 25.0
```

## Sample Output

```
🎲 Randomly sampling 300 from 500 images (seed: 1234)
Starting benchmark evaluation...
Dataset directory: datasets
API URL: http://localhost:8000
Threshold: 25.0 km
Max images: 300
--------------------------------------------------
Processed 10 images, current accuracy: 80.0%
Processed 20 images, current accuracy: 85.0%
...

============================================================
BENCHMARK RESULTS
============================================================
Dataset: datasets
Images processed: 300
Correct predictions: 261
Processing errors: 2
Elapsed time: 135.2s
Processing rate: 2.2 images/second
------------------------------------------------------------
Top-1 Accuracy (≤25.0km): 87.00%
Mean Error: 12.34 km
Median Error: 8.90 km
95th Percentile Error: 45.67 km
Min Error: 0.12 km
Max Error: 156.78 km
============================================================

✅ BENCHMARK PASSED: Accuracy 87.00% meets required 70%
```

## Error Handling

The benchmark handles various error conditions:

- **Missing images**: Skipped with warning
- **API timeouts**: 60-second timeout with retry logic
- **Network errors**: Logged and counted as errors
- **Response parsing**: Handles different API response formats
- **Service unavailability**: Health check before starting

## Performance Metrics

The benchmark tracks:
- **Processing rate**: Images per second
- **Error rate**: Failed requests vs total
- **Response time**: API latency per request
- **Accuracy distribution**: Error distance statistics

## Troubleshooting

### Common Issues

1. **API not responding**
   ```bash
   # Check if API is running
   curl http://localhost:8000/health
   
   # Start services
   docker-compose up -d
   ```

2. **Missing dependencies**
   ```bash
   pip install requests numpy
   ```

3. **Dataset not found**
   ```bash
   # Verify datasets exist
   ls -la datasets/
   find datasets -name "*.jpg" | wc -l
   ```

4. **Inconsistent results due to random sampling**
   ```bash
   # Use fixed seed for debugging
   python3 scripts/benchmark.py --random-seed 42 --max-images 100
   
   # Run multiple times to see variance
   for i in {1..5}; do
     python3 scripts/benchmark.py --max-images 100 --threshold-km 25.0
   done
   ```

5. **Low accuracy**
   - Check model performance
   - Verify dataset quality
   - Review API response format
   - Check for geographic bias
   - Consider if random sample was particularly challenging

### Debug Mode

Add verbose logging by modifying the script or checking API logs:

```bash
# Check API logs
docker logs where-backend

# Run with smaller sample for debugging
python3 scripts/benchmark.py --max-images 5 --threshold-km 1.0
```

## Development

### Adding New Datasets

1. Create new directory under `datasets/`
2. Add images and CSV metadata file
3. Follow existing CSV format
4. Test with benchmark script

### Modifying Thresholds

Update CI workflow (`.github/workflows/benchmark.yml`) to change:
- Accuracy threshold (currently 70%)
- Distance threshold (currently 25km)
- Image count (currently 300)

### Extending Metrics

The benchmark can be extended to track:
- Per-region accuracy
- Confidence score correlation
- Processing time per image
- Memory usage
- Model bias detection
- Performance trends over time

## Future Improvements

### 1. Continuous Test Data Collection

```python
# Automated data collection pipeline
def collect_new_test_data():
    """Download new test images monthly"""
    cities = ["London", "Tokyo", "Berlin", "Sydney"]
    for city in cities:
        download_mapillary_images(city, count=50)
```

### 2. A/B Testing Framework

```python
# Compare model versions
def compare_models(model_a_url, model_b_url, test_set):
    """Compare two model versions on same test set"""
    results_a = benchmark(model_a_url, test_set)
    results_b = benchmark(model_b_url, test_set)
    return statistical_significance_test(results_a, results_b)
```

### 3. Real-World Feedback Integration

```python
# Track user corrections
def track_user_feedback():
    """Monitor user corrections to predictions"""
    corrections = get_user_corrections()
    accuracy = calculate_real_world_accuracy(corrections)
    alert_if_below_threshold(accuracy)
```

## Related Files

- `scripts/benchmark.py` - Main benchmark script
- `scripts/run_benchmark_manual.sh` - Interactive testing script  
- `.github/workflows/benchmark.yml` - CI/CD workflow
- `datasets/` - Gold-label image datasets
- `api/routes/predict.py` - API prediction endpoint 