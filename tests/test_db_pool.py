import sys
from pathlib import Path
from unittest.mock import patch

import pytest
from fastapi import FastAPI

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(1, str(ROOT / "api"))

from api.db import init_db, close_db


class DummyPool:
    def __init__(self) -> None:
        self.closed = False

    async def acquire(self):
        return "conn"

    async def close(self):
        self.closed = True


@patch("api.db.asyncpg.create_pool")
@pytest.mark.asyncio
async def test_pool_returns_connection(mock_create_pool):
    mock_create_pool.return_value = DummyPool()
    app = FastAPI()
    await init_db(app)
    conn = await app.state.pool.acquire()
    assert conn == "conn"
    await close_db(app)
    assert app.state.pool.closed
