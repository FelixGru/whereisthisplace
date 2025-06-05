import argparse
import asyncio
import csv
import json
import logging
import time
from pathlib import Path
from typing import Dict, List

import asyncpg
import requests
from pgvector.asyncpg import register_vector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class WorkingBulkLoader:
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
        logger.info('✅ Connection pool initialized')

    async def close_pool(self):
        if hasattr(self, 'pool'):
            await self.pool.close()

    async def process_single_image(self, image_path: Path, filename: str, lat: float, lon: float, source: str, metadata: dict = None) -> Dict:
        async with self.semaphore:
            try:
                # Check if already exists
                async with self.pool.acquire() as conn:
                    existing = await conn.fetchrow('SELECT filename FROM training_images WHERE filename = ', filename)
                    if existing:
                        return {'status': 'skipped', 'filename': filename}

                # Read image file
                if not image_path.exists():
                    return {'status': 'error', 'filename': filename, 'error': f'File not found: {image_path}'}

                image_data = image_path.read_bytes()
                
                # Get embedding from TorchServe
                response = requests.post(f'{self.model_url}/predictions/where', data=image_data, timeout=60)
                if response.status_code != 200:
                    return {'status': 'error', 'filename': filename, 'error': f'TorchServe error {response.status_code}'}
                
                result = response.json()
                if isinstance(result, dict) and 'embedding' in result:
                    embedding = result['embedding']
                elif isinstance(result, list):
                    embedding = result
                else:
                    return {'status': 'error', 'filename': filename, 'error': f'Unexpected TorchServe response'}

                # Insert to database with CORRECTED parameter order
                async with self.pool.acquire() as conn:
                    if metadata:
                        await conn.execute('''
                            INSERT INTO training_images (filename, lat, lon, geom, vlad, source, metadata)
                            VALUES (, , , ST_SetSRID(ST_MakePoint(, ), 4326), , , )
                        ''', filename, lat, lon, embedding, source, json.dumps(metadata))
                    else:
                        await conn.execute('''
                            INSERT INTO training_images (filename, lat, lon, geom, vlad, source)
                            VALUES (, , , ST_SetSRID(ST_MakePoint(, ), 4326), , )
                        ''', filename, lat, lon, embedding, source)
                
                return {'status': 'success', 'filename': filename, 'embedding_dims': len(embedding)}

            except Exception as e:
                return {'status': 'error', 'filename': filename, 'error': str(e)}

    async def load_from_csv(self, csv_path: Path, dataset_dir: Path, source: str) -> int:
        logger.info(f'📂 Loading from CSV: {csv_path}')
        
        with csv_path.open(newline='') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        
        if not rows:
            logger.warning(f'CSV file {csv_path} is empty')
            return 0

        logger.info(f'📊 Found {len(rows)} entries in CSV')
        
        start_time = time.time()
        tasks = []
        
        for row in rows:
            image_path = dataset_dir / row['image']
            base_name = Path(row['image']).stem
            filename = f'{source}_{base_name}.jpg'
            lat = float(row['lat'])
            lon = float(row['lon'])
            
            # Extract metadata (any extra columns)
            metadata = {k: v for k, v in row.items() if k not in {'image', 'lat', 'lon'}}
            
            task = self.process_single_image(image_path, filename, lat, lon, source, metadata if metadata else None)
            tasks.append(task)
        
        # Process all images concurrently
        results = await asyncio.gather(*tasks)
        
        # Update statistics
        for result in results:
            self.stats['processed'] += 1
            if result['status'] == 'success':
                self.stats['successful'] += 1
            elif result['status'] == 'skipped':
                self.stats['skipped'] += 1
            else:
                self.stats['errors'] += 1
                logger.warning(f'❌ {result["filename"]}: {result.get("error", "Unknown error")}')
        
        elapsed_time = time.time() - start_time
        success_rate = (self.stats['successful'] / max(self.stats['processed'], 1)) * 100
        throughput = self.stats['successful'] / max(elapsed_time, 0.001) * 3600
        
        logger.info(f'✅ Batch complete: {self.stats["successful"]} success, {self.stats["skipped"]} skipped, {self.stats["errors"]} errors')
        logger.info(f'📈 Success rate: {success_rate:.1f}% | Throughput: {throughput:.0f} images/hour')
        
        return self.stats['successful']

async def main():
    parser = argparse.ArgumentParser(description='Working bulk loader for WhereIsThisPlace')
    parser.add_argument('--dataset-dir', type=Path, required=True, help='Directory containing CSV files and images')
    parser.add_argument('--model-url', default='http://localhost:8080', help='TorchServe inference URL')
    parser.add_argument('--database-url', default='postgresql://whereuser:wherepass@postgres:5432/whereisthisplace', help='Database URL')
    parser.add_argument('--source', required=True, help='Source identifier for this batch')
    parser.add_argument('--max-concurrent', type=int, default=4, help='Maximum concurrent processing')

    args = parser.parse_args()

    if not args.dataset_dir.exists():
        logger.error(f'❌ Dataset directory does not exist: {args.dataset_dir}')
        return 1

    loader = WorkingBulkLoader(args.database_url, args.model_url, args.max_concurrent)

    try:
        await loader.init_connection_pool()
        
        csv_files = list(args.dataset_dir.glob('*.csv'))
        if not csv_files:
            logger.error(f'❌ No CSV files found in {args.dataset_dir}')
            return 1

        logger.info(f'🚀 Found {len(csv_files)} CSV files to process')
        
        total_start_time = time.time()
        total_loaded = 0
        
        for csv_file in csv_files:
            logger.info(f'\n🔄 Processing CSV: {csv_file.name}')
            loaded = await loader.load_from_csv(csv_file, args.dataset_dir, args.source)
            total_loaded += loaded

        total_time = time.time() - total_start_time
        overall_throughput = total_loaded / max(total_time, 0.001) * 3600
        
        logger.info(f'\n🎉 BULK LOADING COMPLETE!')
        logger.info(f'📊 Total images loaded: {total_loaded}')
        logger.info(f'⏱️  Total time: {total_time:.2f} seconds')
        logger.info(f'🚀 Overall throughput: {overall_throughput:.0f} images/hour')
        
        return 0

    except Exception as e:
        logger.error(f'❌ Bulk loading failed: {e}')
        import traceback
        traceback.print_exc()
        return 1
    finally:
        await loader.close_pool()

if __name__ == '__main__':
    exit(asyncio.run(main()))
