import os
import sys
import asyncpg
import asyncio
import requests
import torch
import numpy as np
from pathlib import Path
import json
from typing import Dict, List, Tuple
import subprocess

# Add the app directory to Python path
sys.path.append("/app")

async def init_connection(conn):
    """Initialize database connection with pgvector support"""
    from pgvector.asyncpg import register_vector
    await register_vector(conn)
    await conn.execute("SET search_path TO whereisthisplace, public;")

async def get_embedding_from_torchserve(image_path: str) -> np.ndarray:
    """Get 4096D embedding from TorchServe"""
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

def apply_wpca_compression(embedding_4096: np.ndarray) -> np.ndarray:
    """Apply WPCA compression 4096D -> 128D"""
    try:
        # Load WPCA weights
        wpca_data = torch.load("/model-store/mapillary_WPCA128.pth.tar", map_location="cpu")
        
        # Extract the transformation matrix
        if isinstance(wpca_data, dict):
            wpca_matrix = wpca_data.get("wpca_matrix", wpca_data.get("weight", wpca_data))
        else:
            wpca_matrix = wpca_data
            
        if isinstance(wpca_matrix, torch.Tensor):
            wpca_matrix = wpca_matrix.numpy()
            
        # Apply compression: 4096D @ matrix -> 128D
        embedding_128 = embedding_4096 @ wpca_matrix
        return embedding_128.astype(np.float32)
        
    except Exception as e:
        print(f"Error applying WPCA compression: {e}")
        raise

async def store_in_database(filename: str, lat: float, lon: float, 
                          embedding_128: np.ndarray, source: str, metadata: dict):
    """Store image data in training_images table"""
    try:
        database_url = os.getenv("DATABASE_URL", "postgresql://whereuser:wherepass@postgres:5432/whereisthisplace")
        conn = await asyncpg.connect(database_url, init=init_connection)
        
        try:
            await conn.execute("""
                INSERT INTO training_images (filename, lat, lon, geom, vlad, source, metadata)
                VALUES ($1, $2, $3, ST_SetSRID(ST_MakePoint($3, $2), 4326), $4, $5, $6)
            """, filename, lat, lon, embedding_128.tolist(), source, json.dumps(metadata))
            
            print(f"✅ Stored {filename} at ({lat}, {lon})")
            
        finally:
            await conn.close()
            
    except Exception as e:
        print(f"❌ Database error for {filename}: {e}")
        raise

async def process_mapillary_batch(image_dir: str, batch_size: int = 10):
    """Process a batch of Mapillary images"""
    image_dir = Path(image_dir)
    image_files = list(image_dir.glob("*.jpg"))
    
    print(f"Found {len(image_files)} images to process")
    
    for i in range(0, len(image_files), batch_size):
        batch = image_files[i:i+batch_size]
        print(f"Processing batch {i//batch_size + 1}: {len(batch)} images")
        
        for image_path in batch:
            try:
                # Extract metadata from Mapillary naming convention or metadata file
                metadata_file = image_path.with_suffix(".json")
                if metadata_file.exists():
                    with open(metadata_file) as f:
                        metadata = json.load(f)
                    lat = metadata.get("lat", metadata.get("latitude", 0.0))
                    lon = metadata.get("lon", metadata.get("longitude", 0.0))
                else:
                    # Fallback: try to parse from filename or skip
                    print(f"⚠️ No metadata for {image_path.name}, skipping")
                    continue
                
                if lat == 0.0 and lon == 0.0:
                    print(f"⚠️ Invalid coordinates for {image_path.name}, skipping")
                    continue
                
                # Get 4096D embedding from TorchServe
                print(f"Getting embedding for {image_path.name}...")
                embedding_4096 = await get_embedding_from_torchserve(str(image_path))
                
                # Apply WPCA compression
                print(f"Applying WPCA compression...")
                embedding_128 = apply_wpca_compression(embedding_4096)
                
                # Store in database
                await store_in_database(
                    image_path.name, lat, lon, embedding_128, 
                    "mapillary", metadata if "metadata" in locals() else {}
                )
                
            except Exception as e:
                print(f"❌ Failed to process {image_path.name}: {e}")
                continue

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python ingest_mapillary.py <image_directory>")
        sys.exit(1)
    
    image_dir = sys.argv[1]
    asyncio.run(process_mapillary_batch(image_dir))
