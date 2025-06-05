import argparse
import asyncio
import csv
import hashlib
import json
import logging
import os
import time
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

import asyncpg
import requests
from pgvector.asyncpg import register_vector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ProductionBulkLoader:
    def __init__(self, database_url: str, model_url: str, max_concurrent: int = 4, pool_size: int = 10):
        self.database_url = database_url
        self.model_url = model_url.rstrip('/')
        self.max_concurrent = max_concurrent
        self.pool_size = pool_size
        self.semaphore = asyncio.Semaphore(max_concurrent)
        
        self.stats = {
            'processed': 0, 'successful': 0, 'skipped': 0, 'errors': 0,
            'total_embed_time': 0.0, 'total_db_time': 0.0, 'total_bytes': 0
        }

    async def init_connection_pool(self):
        async def init_connection(conn):
            await register_vector(conn)
            return conn
        
        self.pool = await asyncpg.create_pool(
            self.database_url, min_size=2, max_size=self.pool_size, init=init_connection
        )
        logger.info(f'Initialized connection pool (size: {self.pool_size})')

    async def close_pool(self):
        if hasattr(self, 'pool'):
            await self.pool.close()

    async def compute_embedding(self, image_data: bytes) -> Tuple[List[float], float]:
        start_time = time.time()
        try:
            response = requests.post(
                f'{self.model_url}/predictions/where',
                data=image_data, timeout=60,
                headers={'Content-Type': 'application/octet-stream'}
            )
            embed_time = time.time() - start_time
            
            if response.status_code == 200:
                result = response.json()
                if isinstance(result, dict) and 'embedding' in result:
                    return result['embedding'], embed_time
                elif isinstance(result, list):
                    return result, embed_time
                else:
                    raise ValueError(f'Unexpected TorchServe response format: {type(result)}')
            else:
                raise ValueError(f'TorchServe error {response.status_code}: {response.text[:200]}')
        except Exception as e:
            embed_time = time.time() - start_time
            raise ValueError(f'TorchServe request failed: {e}')

    async def process_single_image(self, image_path: Path, filename: str, lat: float, lon: float, source: str, metadata: Optional[Dict] = None) -> Dict:
        async with self.semaphore:
            try:
                async with self.pool.acquire() as conn:
                    existing = await conn.fetchrow('SELECT filename FROM training_images WHERE filename = ', filename)
                    if existing:
                        return {'status': 'skipped', 'filename': filename}

                if image_path.exists():
                    image_data = image_path.read_bytes()
                    file_size = len(image_data)
                else:
                    return {'status': 'error', 'filename': filename, 'error': 'File not found'}

                embedding, embed_time = await self.compute_embedding(image_data)
                
                db_start = time.time()
                async with self.pool.acquire() as conn:
                    await conn.execute('''
                        INSERT INTO training_images (filename, lat, lon, geom, source, vlad, metadata)
                        VALUES (, , , ST_SetSRID(ST_MakePoint(, ), 4326), , , )
                    ''', filename, lat, lon, source, embedding, json.dumps(metadata or {}))
                db_time = time.time() - db_start

                return {
                    'status': 'success', 'filename': filename, 'embed_time': embed_time,
                    'db_time': db_time, 'file_size': file_size, 'embedding_dims': len(embedding)
                }
            except Exception as e:
                return {'status': 'error', 'filename': filename, 'error': str(e)}

    async def process_batch(self, batch: List[Tuple[Path, str, float, float, str, Optional[Dict]]]) -> List[Dict]:
        tasks = [self.process_single_image(image_path, filename, lat, lon, source, metadata)
                for image_path, filename, lat, lon, source, metadata in batch]
        return await asyncio.gather(*tasks)

    def update_stats(self, results: List[Dict]):
        for result in results:
            self.stats['processed'] += 1
            if result['status'] == 'success':
                self.stats['successful'] += 1
                self.stats['total_embed_time'] += result.get('embed_time', 0)
                self.stats['total_db_time'] += result.get('db_time', 0)
                self.stats['total_bytes'] += result.get('file_size', 0)
            elif result['status'] == 'skipped':
                self.stats['skipped'] += 1
            else:
                self.stats['errors'] += 1

    def print_progress(self, batch_num: int, total_batches: int, elapsed_time: float):
        success_rate = (self.stats['successful'] / max(self.stats['processed'], 1)) * 100
        throughput = self.stats['successful'] / max(elapsed_time, 0.001) * 3600
        logger.info(f'Batch {batch_num}/{total_batches} | Success: {self.stats["successful"]} | '
                   f'Skipped: {self.stats["skipped"]} | Errors: {self.stats["errors"]} | '
                   f'Rate: {success_rate:.1f}% | Throughput: {throughput:.0f}/hour')

    def print_final_stats(self, total_time: float):
        if self.stats['successful'] == 0:
            logger.error('No images processed successfully!')
            return

        avg_embed_time = self.stats['total_embed_time'] / self.stats['successful']
        avg_db_time = self.stats['total_db_time'] / self.stats['successful']
        avg_total_time = total_time / self.stats['processed']
        throughput = self.stats['successful'] / total_time * 3600

        logger.info('\n' + '='*60)
        logger.info('FINAL PRODUCTION BULK LOADING RESULTS')
        logger.info('='*60)
        logger.info(f'Success: {self.stats["successful"]}/{self.stats["processed"]} ({self.stats["successful"]/self.stats["processed"]*100:.1f}%)')
        logger.info(f'Skipped: {self.stats["skipped"]}')
        logger.info(f'Errors: {self.stats["errors"]}')
        logger.info(f'Total time: {total_time:.1f}s')
        logger.info(f'Avg embedding time: {avg_embed_time:.3f}s')
        logger.info(f'Avg database time: {avg_db_time:.3f}s')
        logger.info(f'Total processed: {self.stats["total_bytes"]:,} bytes')
        logger.info(f'Avg per image: {avg_total_time:.3f}s')
        logger.info(f'Production throughput: {throughput:.0f} images/hour')
        logger.info(f'Daily capacity: {throughput*24:.0f} images/day')
        
        logger.info('\nSCALING ESTIMATES:')
        for target in [1000, 10000, 50000, 100000, 200000]:
            hours = target * avg_total_time / 3600
            if hours < 1:
                logger.info(f'   {target:,} images: {hours*60:.0f} minutes')
            else:
                logger.info(f'   {target:,} images: {hours:.1f} hours')

    async def load_from_csv(self, csv_path: Path, dataset_dir: Path, source: str, batch_size: int = 100) -> int:
        logger.info(f'Loading from CSV: {csv_path}')
        
        with csv_path.open(newline='') as f:
            reader = csv.DictReader(f)
            rows = list(reader)
        
        if not rows:
            logger.warning(f'CSV file {csv_path} is empty')
            return 0

        required_columns = {'image', 'lat', 'lon'}
        if not required_columns.issubset(rows[0].keys()):
            missing = required_columns - set(rows[0].keys())
            raise ValueError(f'CSV missing required columns: {missing}')

        logger.info(f'Found {len(rows)} entries in CSV')
        
        total_batches = (len(rows) + batch_size - 1) // batch_size
        start_time = time.time()
        
        for batch_num in range(total_batches):
            batch_start = batch_num * batch_size
            batch_end = min(batch_start + batch_size, len(rows))
            batch_rows = rows[batch_start:batch_end]
            
            batch_data = []
            for row in batch_rows:
                image_path = dataset_dir / row['image']
                filename = f'{source}_{Path(row["image"]).stem}.jpg'
                lat = float(row['lat'])
                lon = float(row['lon'])
                metadata = {k: v for k, v in row.items() if k not in required_columns}
                batch_data.append((image_path, filename, lat, lon, source, metadata))
            
            batch_start_time = time.time()
            results = await self.process_batch(batch_data)
            batch_time = time.time() - batch_start_time
            
            self.update_stats(results)
            elapsed_time = time.time() - start_time
            self.print_progress(batch_num + 1, total_batches, elapsed_time)
            
            if batch_time < 1.0:
                await asyncio.sleep(0.5)

        return self.stats['successful']

async def main():
    parser = argparse.ArgumentParser(description='Production bulk loading for WhereIsThisPlace')
    parser.add_argument('--dataset-dir', type=Path, required=True, help='Directory containing CSV files and images')
    parser.add_argument('--model-url', default='http://localhost:8080', help='TorchServe inference URL')
    parser.add_argument('--database-url', default=os.getenv('DATABASE_URL', 'postgresql://whereuser:wherepass@postgres:5432/whereisthisplace'), help='PostgreSQL connection string')
    parser.add_argument('--source', required=True, help='Source identifier for this batch')
    parser.add_argument('--max-concurrent', type=int, default=4, help='Maximum concurrent image processing')
    parser.add_argument('--batch-size', type=int, default=100, help='Batch size for database operations')
    parser.add_argument('--pool-size', type=int, default=10, help='Database connection pool size')

    args = parser.parse_args()

    if not args.dataset_dir.exists():
        logger.error(f'Dataset directory does not exist: {args.dataset_dir}')
        return 1

    loader = ProductionBulkLoader(
        database_url=args.database_url, model_url=args.model_url,
        max_concurrent=args.max_concurrent, pool_size=args.pool_size
    )

    try:
        await loader.init_connection_pool()
        
        csv_files = list(args.dataset_dir.glob('*.csv'))
        if not csv_files:
            logger.error(f'No CSV files found in {args.dataset_dir}')
            return 1

        logger.info(f'Found {len(csv_files)} CSV files to process')
        
        total_start_time = time.time()
        total_loaded = 0
        
        for csv_file in csv_files:
            logger.info(f'\nProcessing CSV: {csv_file.name}')
            loaded = await loader.load_from_csv(csv_file, args.dataset_dir, args.source, args.batch_size)
            total_loaded += loaded
            logger.info(f'Completed {csv_file.name}: {loaded} images loaded')

        total_time = time.time() - total_start_time
        loader.print_final_stats(total_time)
        
        logger.info(f'\nBULK LOADING COMPLETE: {total_loaded} total images loaded')
        return 0

    except Exception as e:
        logger.error(f'Bulk loading failed: {e}')
        return 1
    finally:
        await loader.close_pool()

if __name__ == '__main__':
    exit(asyncio.run(main()))
