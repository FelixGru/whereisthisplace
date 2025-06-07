#!/bin/bash

# Manual Benchmark Testing Script
# This script helps you run the benchmark harness locally for testing

set -e

echo "🚀 WhereIsThisPlace Benchmark Harness - Manual Testing"
echo "=================================================="

# Check if we're in the right directory
if [ ! -f "scripts/benchmark.py" ]; then
    echo "❌ Error: Please run this script from the project root directory"
    exit 1
fi

# Check if datasets exist
if [ ! -d "datasets" ]; then
    echo "❌ Error: datasets/ directory not found"
    exit 1
fi

# Count available images
TOTAL_IMAGES=$(find datasets -name "*.jpg" | wc -l | tr -d ' ')
echo "📊 Found $TOTAL_IMAGES gold-label images in datasets/"

# Check if API is running
API_URL="${API_URL:-http://localhost:8000}"
echo "🔍 Checking API at $API_URL..."

if curl -s -f "$API_URL/health" > /dev/null; then
    echo "✅ API is responding"
else
    echo "❌ API is not responding at $API_URL"
    echo "   Make sure your API server is running:"
    echo "   docker-compose up -d"
    echo "   or set API_URL environment variable to point to your API"
    exit 1
fi

# Install Python dependencies if needed
echo "📦 Checking Python dependencies..."
if ! python3 -c "import requests" 2>/dev/null; then
    echo "Installing requests..."
    pip3 install requests
fi

# Run benchmark options
echo ""
echo "Choose benchmark test:"
echo "1. Quick test (10 images from Paris dataset)"
echo "2. Paris dataset (100 images)"
echo "3. Full benchmark (300 images from all datasets)"
echo "4. Custom test"
echo ""
read -p "Enter your choice (1-4): " choice

case $choice in
    1)
        echo "🧪 Running quick test with 10 images..."
        python3 scripts/benchmark.py \
            --dataset-dir datasets/mapillary_paris \
            --api-url "$API_URL" \
            --threshold-km 25.0 \
            --max-images 10
        ;;
    2)
        echo "🗼 Running Paris dataset benchmark..."
        python3 scripts/benchmark.py \
            --dataset-dir datasets/mapillary_paris \
            --api-url "$API_URL" \
            --threshold-km 25.0
        ;;
    3)
        echo "🌍 Running full benchmark with 300 images..."
        python3 scripts/benchmark.py \
            --dataset-dir datasets \
            --api-url "$API_URL" \
            --threshold-km 25.0 \
            --max-images 300
        ;;
    4)
        echo "🛠️  Custom test configuration:"
        read -p "Dataset directory (default: datasets): " dataset_dir
        dataset_dir=${dataset_dir:-datasets}
        
        read -p "Threshold in km (default: 25.0): " threshold
        threshold=${threshold:-25.0}
        
        read -p "Max images (default: all): " max_images
        
        cmd="python3 scripts/benchmark.py --dataset-dir $dataset_dir --api-url $API_URL --threshold-km $threshold"
        if [ ! -z "$max_images" ]; then
            cmd="$cmd --max-images $max_images"
        fi
        
        echo "Running: $cmd"
        eval $cmd
        ;;
    *)
        echo "❌ Invalid choice"
        exit 1
        ;;
esac

echo ""
echo "✅ Benchmark completed!"
echo ""
echo "💡 Tips:"
echo "   - Accuracy ≥70% is required for CI to pass"
echo "   - Use threshold of 25km for city-level accuracy"
echo "   - Use threshold of 1km for precise location accuracy"
echo "   - Check logs above for detailed error information" 