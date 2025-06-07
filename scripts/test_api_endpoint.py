#!/usr/bin/env python3
"""Simple script to test the API endpoint and debug 404 issues."""

import requests
import sys
from pathlib import Path

def test_endpoints():
    """Test various API endpoints to debug the issue."""
    base_url = "http://localhost:8000"
    
    print("🔍 Testing API endpoints...")
    
    # Test root endpoint
    try:
        resp = requests.get(f"{base_url}/", timeout=5)
        print(f"GET / -> {resp.status_code}: {resp.text}")
    except Exception as e:
        print(f"GET / -> Error: {e}")
    
    # Test health endpoint
    try:
        resp = requests.get(f"{base_url}/health", timeout=5)
        print(f"GET /health -> {resp.status_code}: {resp.text}")
    except Exception as e:
        print(f"GET /health -> Error: {e}")
    
    # Test predict endpoint with GET (should fail)
    try:
        resp = requests.get(f"{base_url}/predict", timeout=5)
        print(f"GET /predict -> {resp.status_code}: {resp.text}")
    except Exception as e:
        print(f"GET /predict -> Error: {e}")
    
    # Test predict endpoint with POST but no file (should fail with 422)
    try:
        resp = requests.post(f"{base_url}/predict", timeout=5)
        print(f"POST /predict (no file) -> {resp.status_code}: {resp.text}")
    except Exception as e:
        print(f"POST /predict (no file) -> Error: {e}")
    
    # Test predict endpoint with dummy file
    try:
        # Create a minimal dummy image file
        dummy_image = b'\xff\xd8\xff\xe0\x00\x10JFIF\x00\x01\x01\x01\x00H\x00H\x00\x00\xff\xdb\x00C\x00\x08\x06\x06\x07\x06\x05\x08\x07\x07\x07\t\t\x08\n\x0c\x14\r\x0c\x0b\x0b\x0c\x19\x12\x13\x0f\x14\x1d\x1a\x1f\x1e\x1d\x1a\x1c\x1c $.\' ",#\x1c\x1c(7),01444\x1f\'9=82<.342\xff\xc0\x00\x11\x08\x00\x01\x00\x01\x01\x01\x11\x00\x02\x11\x01\x03\x11\x01\xff\xc4\x00\x14\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x08\xff\xc4\x00\x14\x10\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\xff\xda\x00\x0c\x03\x01\x00\x02\x11\x03\x11\x00\x3f\x00\xaa\xff\xd9'
        
        files = {'photo': ('test.jpg', dummy_image, 'image/jpeg')}
        resp = requests.post(f"{base_url}/predict", files=files, timeout=30)
        print(f"POST /predict (with dummy file) -> {resp.status_code}: {resp.text[:200]}...")
    except Exception as e:
        print(f"POST /predict (with dummy file) -> Error: {e}")
    
    # Test OpenAPI docs endpoint
    try:
        resp = requests.get(f"{base_url}/docs", timeout=5)
        print(f"GET /docs -> {resp.status_code}")
    except Exception as e:
        print(f"GET /docs -> Error: {e}")

if __name__ == "__main__":
    test_endpoints() 