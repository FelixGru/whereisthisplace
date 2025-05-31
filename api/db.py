import os

import asyncpg
from fastapi import FastAPI
from dotenv import load_dotenv

load_dotenv()


async def init_db(app: FastAPI):
    """Initialize a connection pool and attach it to the FastAPI app."""
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")
    app.state.pool = await asyncpg.create_pool(dsn=database_url)
    return app.state.pool


async def close_db(app: FastAPI):
    """Close the connection pool stored on the FastAPI app."""
    pool = getattr(app.state, "pool", None)
    if pool is not None:
        await pool.close()
