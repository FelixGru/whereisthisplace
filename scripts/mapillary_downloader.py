#!/usr/bin/env python3
"""
Mapillary Dataset Downloader for WhereIsThisPlace
"""

import argparse
import asyncio
import aiohttp
import csv
import json
import time
from pathlib import Path
from typing import List, Dict, Tuple

class MapillaryDownloader:
    def __init__(self, access_token: str, output_dir: str, max_images: int = 1000):
        self.access_token = access_token
        self.output_dir = Path(output_dir)
        self.max_images = max_images
        self.base_url = "https://graph.mapillary.com"
        
        # Create output directory
        self.output_dir.mkdir(parents=True, exist_ok=True)
        
    async def search_images(self, bbox: Tuple[float, float, float, float]) -> List[Dict]:
        """Search for images within bounding box"""
        min_lon, min_lat, max_lon, max_lat = bbox
        
        async with aiohttp.ClientSession() as session:
            images = []
            url = f"{self.base_url}/images"
            params = {
                'access_token': self.access_token,
                'bbox': f"{min_lon},{min_lat},{max_lon},{max_lat}",
                'fields': 'id,thumb_256_url,computed_geometry,captured_at',
                'limit': min(self.max_images, 2000)
            }
            
            print(f"Searching for images in bbox: {bbox}")
            async with session.get(url, params=params) as response:
                if response.status == 200:
                    data = await response.json()
                    images = data.get('data', [])
                    print(f"Found {len(images)} images")
                else:
                    print(f"Error searching images: {response.status}")
                    error_text = await response.text()
                    print(f"Error details: {error_text}")
                    
            return images[:self.max_images]
    
    async def download_image(self, session: aiohttp.ClientSession, image_data: Dict, index: int) -> Dict:
        """Download a single image"""
        try:
            image_id = image_data['id']
            image_url = image_data['thumb_256_url']
            geometry = image_data['computed_geometry']
            
            # Extract coordinates
            if geometry['type'] == 'Point':
                lon, lat = geometry['coordinates']
            else:
                print(f"Skipping non-point geometry: {image_id}")
                return None
            
            # Download image
            filename = f"mapillary_{image_id}_{index:06d}.jpg"
            filepath = self.output_dir / filename
            
            async with session.get(image_url) as response:
                if response.status == 200:
                    with open(filepath, 'wb') as f:
                        f.write(await response.read())
                    
                    return {
                        'image': filename,
                        'lat': lat,
                        'lon': lon,
                        'description': f"Mapillary image {image_id}",
                        'mapillary_id': image_id,
                        'captured_at': image_data.get('captured_at', '')
                    }
                else:
                    print(f"Failed to download {image_id}: {response.status}")
                    return None
                    
        except Exception as e:
            print(f"Error downloading {image_data.get('id', 'unknown')}: {e}")
            return None
    
    async def download_dataset(self, bbox: Tuple[float, float, float, float]):
        """Download complete dataset"""
        print(f"Starting Mapillary download to: {self.output_dir}")
        
        # Search for images
        images = await self.search_images(bbox)
        if not images:
            print("No images found!")
            return
        
        print(f"Downloading {len(images)} images...")
        
        # Download images concurrently
        csv_data = []
        semaphore = asyncio.Semaphore(10)  # Limit concurrent downloads
        
        async def download_with_semaphore(session, image_data, index):
            async with semaphore:
                return await self.download_image(session, image_data, index)
        
        async with aiohttp.ClientSession() as session:
            tasks = [
                download_with_semaphore(session, image_data, i) 
                for i, image_data in enumerate(images)
            ]
            
            results = await asyncio.gather(*tasks, return_exceptions=True)
            
            # Collect successful downloads
            for result in results:
                if result and not isinstance(result, Exception):
                    csv_data.append(result)
        
        # Write CSV file
        csv_path = self.output_dir / 'mapillary_dataset.csv'
        with open(csv_path, 'w', newline='') as f:
            if csv_data:
                writer = csv.DictWriter(f, fieldnames=csv_data[0].keys())
                writer.writeheader()
                writer.writerows(csv_data)
        
        print(f"""
=== MAPILLARY DOWNLOAD COMPLETE ===
✅ Downloaded: {len(csv_data)} images
📁 Directory: {self.output_dir}
📄 CSV file: {csv_path}
🎯 Ready for bulk loading!

Next steps:
python scripts/bulk_loader_production.py \\
    --dataset-dir {self.output_dir} \\
    --source mapillary_dataset \\
    --max-concurrent 8
        """)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Download Mapillary dataset')
    parser.add_argument('--access-token', required=True, help='Mapillary API access token')
    parser.add_argument('--bbox', required=True, help='Bounding box: "min_lon,min_lat,max_lon,max_lat"')
    parser.add_argument('--output-dir', required=True, help='Output directory for dataset')
    parser.add_argument('--max-images', type=int, default=1000, help='Maximum images to download')
    
    args = parser.parse_args()
    
    # Parse bounding box
    bbox_parts = args.bbox.split(',')
    if len(bbox_parts) != 4:
        raise ValueError("Bounding box must be 'min_lon,min_lat,max_lon,max_lat'")
    
    bbox = tuple(float(x) for x in bbox_parts)
    
    downloader = MapillaryDownloader(args.access_token, args.output_dir, args.max_images)
    asyncio.run(downloader.download_dataset(bbox))
