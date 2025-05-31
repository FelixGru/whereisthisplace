import os
from typing import Optional, Dict, Any

import asyncpg
import numpy as np


async def nearest(vec: np.ndarray) -> Optional[asyncpg.Record]:
    """Return the closest photo to the given vector.

    Parameters
    ----------
    vec: np.ndarray
        Embedding vector with dimension matching the ``vlad`` column.

    Returns
    -------
    asyncpg.Record | None
        Row containing ``lat``, ``lon`` and ``score`` fields or ``None`` if no
        data is found.
    """
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is not set")

    conn = await asyncpg.connect(dsn=database_url)
    try:
        row = await conn.fetchrow(
            "SELECT lat, lon, 1 - (vlad <#> $1) AS score "
            "FROM photos ORDER BY vlad <#> $1 LIMIT 1",
            vec.tolist(),
        )
        return row
    finally:
        await conn.close()

