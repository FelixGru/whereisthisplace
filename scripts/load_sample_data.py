#!/usr/bin/env python3
"""Load sample data into the photos table for benchmarking."""

import asyncio
import asyncpg
import numpy as np
from pgvector.asyncpg import register_vector

async def init_connection(conn):
    """Initialize connection with pgvector and set correct schema."""
    await conn.execute("SET search_path TO whereisthisplace, public;")
    await register_vector(conn)

async def load_sample_data():
    """Load sample data into the photos table."""
    database_url = "postgresql://whereuser:wherepass@localhost:5432/whereisthisplace"
    
    # Sample locations around the world with dummy embeddings
    sample_data = [
        # Paris, France
        (48.8566, 2.3522, "Paris, France"),
        (48.8584, 2.2945, "Eiffel Tower"),
        (48.8606, 2.3376, "Louvre Museum"),
        
        # London, UK
        (51.5074, -0.1278, "London, UK"),
        (51.5014, -0.1419, "Buckingham Palace"),
        (51.5055, -0.0754, "Tower Bridge"),
        
        # New York, USA
        (40.7128, -74.0060, "New York, USA"),
        (40.6892, -74.0445, "Statue of Liberty"),
        (40.7580, -73.9855, "Times Square"),
        
        # Tokyo, Japan
        (35.6762, 139.6503, "Tokyo, Japan"),
        (35.6586, 139.7454, "Tokyo Skytree"),
        
        # Sydney, Australia
        (-33.8688, 151.2093, "Sydney, Australia"),
        (-33.8568, 151.2153, "Sydney Opera House"),
        
        # Berlin, Germany
        (52.5200, 13.4050, "Berlin, Germany"),
        (52.5163, 13.3777, "Brandenburg Gate"),
        
        # Rome, Italy
        (41.9028, 12.4964, "Rome, Italy"),
        (41.8902, 12.4922, "Colosseum"),
        
        # Barcelona, Spain
        (41.3851, 2.1734, "Barcelona, Spain"),
        (41.4036, 2.1744, "Sagrada Familia"),
        
        # Amsterdam, Netherlands
        (52.3676, 4.9041, "Amsterdam, Netherlands"),
        
        # Prague, Czech Republic
        (50.0755, 14.4378, "Prague, Czech Republic"),
    ]
    
    conn = await asyncpg.connect(dsn=database_url)
    await init_connection(conn)
    
    try:
        # Clear existing data
        await conn.execute("DELETE FROM photos")
        print("Cleared existing photos data")
        
        # Insert sample data
        for i, (lat, lon, description) in enumerate(sample_data):
            # Generate a random but consistent embedding for each location
            np.random.seed(i + 1000)  # Consistent seed for reproducible results
            embedding = np.random.normal(0, 0.1, 128).astype(np.float32)
            
            await conn.execute(
                "INSERT INTO photos (lat, lon, vlad) VALUES ($1, $2, $3)",
                lat, lon, embedding.tolist()
            )
        
        # Verify data was inserted
        count = await conn.fetchval("SELECT COUNT(*) FROM photos")
        print(f"✅ Loaded {count} sample photos into database")
        
        # Show some sample data
        samples = await conn.fetch("SELECT lat, lon FROM photos LIMIT 5")
        print("Sample data:")
        for i, row in enumerate(samples):
            location_name = sample_data[i][2] if i < len(sample_data) else "Unknown"
            print(f"  - {location_name}: {row['lat']:.4f}, {row['lon']:.4f}")
            
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(load_sample_data()) 