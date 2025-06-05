import asyncio
import asyncpg
import requests
import csv
import json
import time
from pathlib import Path
from pgvector.asyncpg import register_vector

class BulkLoader:
    def __init__(self, database_url: str, model_url: str, max_concurrent: int = 4):
        self.database_url = database_url
        self.model_url = model_url.rstrip('/')
        self.semaphore = asyncio.Semaphore(max_concurrent)
        self.stats = {'processed': 0, 'successful': 0, 'errors': 0, 'skipped': 0}
        
    async def init_pool(self):
        self.pool = await asyncpg.create_pool(
            self.database_url,
            min_size=2,
            max_size=10,
            init=register_vector
        )
        
    async def process_image(self, image_path: Path, filename: str, lat: float, lon: float, source: str):
        async with self.semaphore:
            try:
                # Read image
                with open(image_path, 'rb') as f:
                    image_data = f.read()
                
                # Get embedding
                response = requests.post(f'{self.model_url}/predictions/where', 
                                       data=image_data, timeout=30)
                if response.status_code != 200:
                    raise Exception(f'TorchServe error: {response.status_code}')
                
                embedding_data = response.json()
                embedding = embedding_data['embedding']
                
                # Insert into database with geometry
                async with self.pool.acquire() as conn:
                    await conn.execute('''
                        INSERT INTO training_images (filename, lat, lon, geom, vlad, source) 
                        VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($3, $2), 4326), $4, $5)
                    ''', filename, lat, lon, embedding, source)
                
                self.stats['successful'] += 1
                print(f'✅ {filename} - {lat:.4f}, {lon:.4f}')
                
            except Exception as e:
                self.stats['errors'] += 1
                print(f'❌ {filename}: {e}')
            finally:
                self.stats['processed'] += 1
                
    async def load_from_csv(self, csv_path: Path, source: str):
        print(f'Loading from: {csv_path}')
        
        tasks = []
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                image_path = csv_path.parent / row['image']
                if image_path.exists():
                    task = self.process_image(
                        image_path, 
                        row['image'], 
                        float(row['lat']), 
                        float(row['lon']), 
                        source
                    )
                    tasks.append(task)
                else:
                    print(f'⚠️  Image not found: {image_path}')
                    self.stats['skipped'] += 1
        
        if tasks:
            await asyncio.gather(*tasks, return_exceptions=True)
            
    async def run(self, dataset_dir: str, source: str = 'bulk_load'):
        await self.init_pool()
        
        dataset_path = Path(dataset_dir)
        csv_files = list(dataset_path.glob('*.csv'))
        
        print(f'Found {len(csv_files)} CSV files in {dataset_dir}')
        
        start_time = time.time()
        for csv_file in csv_files:
            await self.load_from_csv(csv_file, source)
            
        elapsed = time.time() - start_time
        
        print(f'''
=== BULK LOADING COMPLETE ===
✅ Successful: {self.stats['successful']}
❌ Errors: {self.stats['errors']} 
⚠️  Skipped: {self.stats['skipped']}
⏱️  Time: {elapsed:.2f}s
🚀 Rate: {self.stats['successful']/elapsed if elapsed > 0 else 0:.1f} images/sec
        ''')
        
        await self.pool.close()

if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description='Bulk load images with embeddings')
    parser.add_argument('--dataset-dir', required=True, help='Directory containing CSV and images')
    parser.add_argument('--source', default='bulk_load', help='Source label for database')
    parser.add_argument('--max-concurrent', type=int, default=4, help='Max concurrent processing')
    parser.add_argument('--database-url', default='postgresql://whereuser:wherepass@postgres:5432/whereisthisplace')
    parser.add_argument('--model-url', default='http://localhost:8080')
    
    args = parser.parse_args()
    
    loader = BulkLoader(args.database_url, args.model_url, args.max_concurrent)
    asyncio.run(loader.run(args.dataset_dir, args.source))
