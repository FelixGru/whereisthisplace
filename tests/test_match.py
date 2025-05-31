import sys
from pathlib import Path
import asyncio
from unittest.mock import patch
import os

import numpy as np
import pytest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(1, str(ROOT / "api"))

from api.repositories.match import nearest


class DummyConn:
    def __init__(self, result):
        self.result = result
        self.queries = []

    async def fetchrow(self, query, vec):
        self.queries.append((query, vec))
        return self.result

    async def close(self):
        pass


@pytest.mark.asyncio
async def test_nearest_returns_expected_row():
    expected = {"lat": 1.0, "lon": 2.0, "score": 0.9}

    dummy = DummyConn(expected)
    with patch("api.repositories.match.asyncpg.connect", return_value=dummy):
        with patch.dict(os.environ, {"DATABASE_URL": "postgresql://"}):
            result = await nearest(np.array([0.1, 0.2]))

    assert result == expected
    assert dummy.queries

