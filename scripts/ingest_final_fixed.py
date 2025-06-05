import os
import sys
import asyncpg
import asyncio
import requests
import numpy as np
from pathlib import Path
import json

sys.path.append("/app")

async def init_connection(conn):
    from pgvector.asyncpg import register_vector
    await register_vector(conn)
    await conn.execute("SET search_path TO whereisthisplace, public;")

async def get_embedding_from_torchserve(image_path: str) -> np.ndarray:
    try:
        with open(image_path, "rb") as f:
            files = {"data": f}
            response = requests.post("http://localhost:8080/predictions/where", files=files, timeout=30)
        
        if response.status_code == 200:
            result = response.json()
            if isinstance(result, list):
                return np.array(result, dtype=np.float32)
            elif isinstance(result, dict) and "embedding" in result:
                return np.array(result["embedding"], dtype=np.float32)
        raise Exception(f"TorchServe error: {response.status_code} - {response.text}")
    except Exception as e:
        print(f"Error getting embedding for {image_path}: {e}")
        raise

async def store_in_database(filename: str, lat: float, lon: float, 
                          embedding: np.ndarray, source: str, metadata: dict):
    try:
        database_url = os.getenv("DATABASE_URL", "postgresql://whereuser:wherepass@postgres:5432/whereisthisplace")
        
        # Create connection and then initialize it
        conn = await asyncpg.connect(database_url)
        await init_connection(conn)
        
        try:
            await conn.execute("""
                INSERT INTO training_images (filename, lat, lon, geom, vlad, source, metadata)
                VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($3, $2), 4326), $4, $5, $6)
            """, filename, lat, lon, embedding.tolist(), source, json.dumps(metadata))
            
            print(f"✅ Stored {filename} at ({lat}, {lon}) with {len(embedding)}D embedding")
            
        finally:
            await conn.close()
            
    except Exception as e:
        print(f"❌ Database error for {filename}: {e}")
        raise

async def process_images(image_dir: str):
    image_dir = Path(image_dir)
    image_files = list(image_dir.glob("*.jpg"))
    
    print(f"Found {len(image_files)} images to process")
    
    for image_path in image_files:
        try:
            metadata_file = image_path.with_suffix(".json")
            if metadata_file.exists():
                with open(metadata_file) as f:
                    metadata = json.load(f)
                lat = metadata.get("lat", metadata.get("latitude", 0.0))
                lon = metadata.get("lon", metadata.get("longitude", 0.0))
            else:
                print(f"⚠️ No metadata for {image_path.name}, skipping")
                continue
            
            if lat == 0.0 and lon == 0.0:
                print(f"⚠️ Invalid coordinates for {image_path.name}, skipping")
                continue
            
            print(f"Getting 128D embedding for {image_path.name}...")
            embedding = await get_embedding_from_torchserve(str(image_path))
            
            await store_in_database(
                image_path.name, lat, lon, embedding, 
                "test", metadata
            )
            
        except Exception as e:
            print(f"❌ Failed to process {image_path.name}: {e}")
            continue

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python ingest_final_fixed.py <image_directory>")
        sys.exit(1)
    
    image_dir = sys.argv[1]
    asyncio.run(process_images(image_dir))
