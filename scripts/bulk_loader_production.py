#!/usr/bin/env python3
"""
Production Bulk Loader for WhereIsThisPlace
"""

import argparse
import asyncio
import asyncpg
import requests
import csv
import json
import time
import logging
from pathlib import Path
from typing import Dict, List, Optional
from pgvector.asyncpg import register_vector

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

class ProductionBulkLoader:
    def __init__(self, database_url: str, model_url: str, max_concurrent: int = 4, batch_size: int = 100):
        self.database_url = database_url
        self.model_url = model_url.rstrip('/')
        self.max_concurrent = max_concurrent
        self.batch_size = batch_size
        self.semaphore = asyncio.Semaphore(max_concurrent)
        
        self.stats = {
            'processed': 0, 'successful': 0, 'errors': 0, 'skipped': 0,
            'total_embedding_time': 0.0, 'total_db_time': 0.0
        }
        self.error_log = []
        
    async def init_pool(self):
        self.pool = await asyncpg.create_pool(
            self.database_url, min_size=5, max_size=20, init=register_vector
        )
        logger.info(f'Initialized connection pool (size: 5-20)')
        
    async def process_image(self, image_path: Path, filename: str, lat: float, lon: float, 
                           source: str, metadata: Optional[Dict] = None) -> bool:
        async with self.semaphore:
            try:
                start_time = time.time()
                
                if not image_path.exists():
                    self.stats['skipped'] += 1
                    self.error_log.append(f'{filename}: File not found')
                    return False
                    
                with open(image_path, 'rb') as f:
                    image_data = f.read()
                
                embed_start = time.time()
                response = requests.post(
                    f'{self.model_url}/predictions/where', 
                    data=image_data, timeout=60,
                    headers={'Content-Type': 'application/octet-stream'}
                )
                
                if response.status_code != 200:
                    self.stats['errors'] += 1
                    self.error_log.append(f'{filename}: TorchServe error {response.status_code}')
                    return False
                
                embedding_data = response.json()
                embedding = embedding_data.get('embedding')
                if not embedding:
                    self.stats['errors'] += 1
                    self.error_log.append(f'{filename}: No embedding in response')
                    return False
                    
                embed_time = time.time() - embed_start
                self.stats['total_embedding_time'] += embed_time
                
                db_start = time.time()
                async with self.pool.acquire() as conn:
                    await conn.execute('''
                        INSERT INTO training_images (filename, lat, lon, geom, vlad, source, metadata) 
                        VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($3, $2), 4326), $4, $5, $6)
                    ''', filename, lat, lon, embedding, source, json.dumps(metadata) if metadata else None)
                
                db_time = time.time() - db_start
                self.stats['total_db_time'] += db_time
                self.stats['successful'] += 1
                
                total_time = time.time() - start_time
                logger.debug(f'✅ {filename} - {lat:.4f}, {lon:.4f} ({total_time:.3f}s)')
                return True
                
            except Exception as e:
                self.stats['errors'] += 1
                self.error_log.append(f'{filename}: {str(e)}')
                logger.error(f'❌ {filename}: {e}')
                return False
            finally:
                self.stats['processed'] += 1
                
    async def process_batch(self, batch_data: List[Dict], source: str):
        tasks = []
        for item in batch_data:
            image_path = Path(item['image_path'])
            task = self.process_image(
                image_path, item['filename'], item['lat'], item['lon'],
                source, item.get('metadata')
            )
            tasks.append(task)
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
            
    async def load_from_csv(self, csv_path: Path, source: str):
        logger.info(f'Loading from CSV: {csv_path}')
        
        batch = []
        total_rows = 0
        
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            
            for row in reader:
                total_rows += 1
                image_path = csv_path.parent / row['image']
                
                batch_item = {
                    'image_path': image_path,
                    'filename': row['image'],
                    'lat': float(row['lat']),
                    'lon': float(row['lon']),
                    'metadata': {
                        'description': row.get('description', ''),
                        'csv_source': str(csv_path.name)
                    }
                }
                batch.append(batch_item)
                
                if len(batch) >= self.batch_size:
                    batch_num = (total_rows // self.batch_size) + 1
                    await self.process_batch(batch, source)
                    success_rate = (self.stats['successful'] / self.stats['processed']) * 100 if self.stats['processed'] > 0 else 0
                    throughput = self.stats['successful'] / (time.time() - self.start_time) * 3600 if hasattr(self, 'start_time') else 0
                    
                    logger.info(f'Batch {batch_num} | Success: {self.stats["successful"]} | '
                               f'Skipped: {self.stats["skipped"]} | Errors: {self.stats["errors"]} | '
                               f'Rate: {success_rate:.1f}% | Throughput: {throughput:.0f}/hour')
                    batch = []
            
            if batch:
                await self.process_batch(batch, source)
        
        logger.info(f'Completed {csv_path.name}: {self.stats["successful"]} images loaded')
        
    async def run(self, dataset_dir: str, source: str = 'bulk_load'):
        self.start_time = time.time()
        await self.init_pool()
        
        dataset_path = Path(dataset_dir)
        if not dataset_path.exists():
            raise FileNotFoundError(f'Dataset directory not found: {dataset_dir}')
            
        csv_files = list(dataset_path.glob('*.csv'))
        logger.info(f'Found {len(csv_files)} CSV files to process')
        
        if not csv_files:
            logger.warning(f'No CSV files found in {dataset_dir}')
            return
        
        for csv_file in csv_files:
            logger.info(f'\nProcessing CSV: {csv_file.name}')
            await self.load_from_csv(csv_file, source)
            
        elapsed = time.time() - self.start_time
        success_rate = (self.stats['successful'] / self.stats['processed']) * 100 if self.stats['processed'] > 0 else 0
        throughput_per_sec = self.stats['successful'] / elapsed if elapsed > 0 else 0
        throughput_per_hour = throughput_per_sec * 3600
        
        logger.info(f'''
=== BULK LOADING COMPLETE ===
✅ Successful: {self.stats['successful']}
❌ Errors: {self.stats['errors']} 
⚠️  Skipped: {self.stats['skipped']}
📊 Success Rate: {success_rate:.1f}%
⏱️  Total Time: {elapsed:.2f}s
🚀 Throughput: {throughput_per_sec:.1f}/sec ({throughput_per_hour:.0f}/hour)
📈 Daily Capacity: {throughput_per_hour*24:.0f} images/day
        ''')
        
        if self.error_log:
            logger.warning(f'\n=== ERRORS ({len(self.error_log)}) ===')
            for error in self.error_log[:10]:
                logger.warning(error)
            if len(self.error_log) > 10:
                logger.warning(f'... and {len(self.error_log) - 10} more errors')
        
        await self.pool.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Production bulk loader for geolocated images')
    parser.add_argument('--dataset-dir', required=True, help='Directory containing CSV and images')
    parser.add_argument('--source', default='bulk_load', help='Source label for database')
    parser.add_argument('--max-concurrent', type=int, default=8, help='Max concurrent processing')
    parser.add_argument('--batch-size', type=int, default=100, help='Batch size for processing')
    parser.add_argument('--database-url', 
                        default='postgresql://whereuser:wherepass@postgres:5432/whereisthisplace',
                        help='Database connection string')
    parser.add_argument('--model-url', default='http://localhost:8080', help='TorchServe model URL')
    parser.add_argument('--log-level', default='INFO', 
                        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
                        help='Logging level')
    
    args = parser.parse_args()
    logging.getLogger().setLevel(getattr(logging, args.log_level))
    
    loader = ProductionBulkLoader(
        args.database_url, args.model_url, args.max_concurrent, args.batch_size
    )
    
    try:
        asyncio.run(loader.run(args.dataset_dir, args.source))
    except KeyboardInterrupt:
        logger.info('Interrupted by user')
    except Exception as e:
        logger.error(f'Fatal error: {e}')
        raise
