import argparse
import asyncio
import csv
import json
import logging
import os
import time
from pathlib import Path
from typing import Dict, List, Optional

import asyncpg
import requests
from pgvector.asyncpg import register_vector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class FixedBulkLoader:
    def __init__(self, database_url: str, model_url: str, max_concurrent: int = 4):
        self.database_url = database_url
        self.model_url = model_url.rstrip('/')
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.stats = {'processed': 0, 'successful': 0, 'skipped': 0, 'errors': 0}

    async def init_connection_pool(self):
        async def init_connection(conn):
            await register_vector(conn)
            return conn
        
        self.pool = await asyncpg.create_pool(
            self.database_url, min_size=2, max_size=8, init=init_connection
        )
        logger.info('Connection pool initialized')

    async def close_pool(self):
        if hasattr(self, 'pool'):
            await self.pool.close()

    async def process_single_image(self, image_path: Path, filename: str, lat: float, lon: float, source: str) -> Dict:
        async with self.semaphore:
            try:
                # Check if already exists
                async with self.pool.acquire() as conn:
                    existing = await conn.fetchrow('SELECT filename FROM training_images WHERE filename = ', filename)
                    if existing:
                        return {'status': 'skipped', 'filename': filename, 'reason': 'already exists'}

                # Read image file
                if not image_path.exists():
                    return {'status': 'error', 'filename': filename, 'error': f'File not found: {image_path}'}

                image_data = image_path.read_bytes()
                
                # Get embedding from TorchServe
                try:
                    response = requests.post(f'{self.model_url}/predictions/where', data=image_data, timeout=60)
                    if response.status_code != 200:
                        return {'status': 'error', 'filename': filename, 'error': f'TorchServe error {response.status_code}'}
                    
                    result = response.json()
                    if isinstance(result, dict) and 'embedding' in result:
                        embedding = result['embedding']
                    elif isinstance(result, list):
                        embedding = result
                    else:
                        return {'status': 'error', 'filename': filename, 'error': f'Unexpected TorchServe response: {type(result)}'}
                        
                except Exception as e:
                    return {'status': 'error', 'filename': filename, 'error': f'TorchServe request failed: {e}'}

                # Insert to database
                try:
                    async with self.pool.acquire() as conn:
                        await conn.execute('''
                            INSERT INTO training_images (filename, lat, lon, geom, source, vlad)
                            VALUES (, , , ST_SetSRID(ST_MakePoint(, ), 4326), , )
                        ''', filename, lat, lon, source, embedding)
                    
                    return {'status': 'success', 'filename': filename, 'embedding_dims': len(embedding)}
                    
                except Exception as e:
                    return {'status': 'error', 'filename': filename, 'error': f'Database insert failed: {e}'}

            except Exception as e:
                return {'status': 'error', 'filename': filename, 'error': f'Unexpected error: {e}'}

    def update_stats(self, results: List[Dict]):
        for result in results:
            self.stats['processed'] += 1
            if result['status'] == 'success':
                self.stats['successful'] += 1
            elif result['status'] == 'skipped':
                self.stats['skipped'] += 1
            else:
                self.stats['errors'] += 1
                # Log specific errors
                logger.error(f'Error processing {result["filename"]}: {result.get("error", "Unknown error")}')

    async def load_from_csv(self, csv_path: Path, dataset_dir: Path, source: str) -> int:
        logger.info(f'Loading from CSV: {csv_path}')
        
        with csv_path.open(newline='') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        
        if not rows:
            logger.warning(f'CSV file {csv_path} is empty')
            return 0

        logger.info(f'Found {len(rows)} entries in CSV')
        
        # Process images
        tasks = []
        for row in rows:
            image_path = dataset_dir / row['image']
            # Create a safe filename
            base_name = Path(row['image']).stem
            filename = f'{source}_{base_name}.jpg'
            lat = float(row['lat'])
            lon = float(row['lon'])
            
            task = self.process_single_image(image_path, filename, lat, lon, source)
            tasks.append(task)
        
        results = await asyncio.gather(*tasks)
        self.update_stats(results)
        
        # Print results
        success_rate = (self.stats['successful'] / max(self.stats['processed'], 1)) * 100
        logger.info(f'Batch complete: {self.stats["successful"]} success, {self.stats["skipped"]} skipped, {self.stats["errors"]} errors ({success_rate:.1f}% success rate)')
        
        return self.stats['successful']

async def main():
    parser = argparse.ArgumentParser(description='Fixed bulk loading for WhereIsThisPlace')
    parser.add_argument('--dataset-dir', type=Path, required=True)
    parser.add_argument('--model-url', default='http://localhost:8080')
    parser.add_argument('--database-url', default='postgresql://whereuser:wherepass@postgres:5432/whereisthisplace')
    parser.add_argument('--source', required=True)
    parser.add_argument('--max-concurrent', type=int, default=4)

    args = parser.parse_args()

    loader = FixedBulkLoader(args.database_url, args.model_url, args.max_concurrent)

    try:
        await loader.init_connection_pool()
        
        csv_files = list(args.dataset_dir.glob('*.csv'))
        if not csv_files:
            logger.error(f'No CSV files found in {args.dataset_dir}')
            return 1

        total_loaded = 0
        for csv_file in csv_files:
            loaded = await loader.load_from_csv(csv_file, args.dataset_dir, args.source)
            total_loaded += loaded

        logger.info(f'BULK LOADING COMPLETE: {total_loaded} total images loaded')
        return 0

    except Exception as e:
        logger.error(f'Bulk loading failed: {e}')
        import traceback
        traceback.print_exc()
        return 1
    finally:
        await loader.close_pool()

if __name__ == '__main__':
    exit(asyncio.run(main()))
