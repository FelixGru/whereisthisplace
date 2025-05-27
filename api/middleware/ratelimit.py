import time
from starlette.middleware.base import BaseHTTPMiddleware
from starlette.requests import Request
from starlette.responses import Response


class RateLimitMiddleware(BaseHTTPMiddleware):
    """Simple in-memory token bucket rate limiter per client IP."""

    def __init__(self, app, limit: int = 10, period: int = 86400):
        super().__init__(app)
        self.limit = limit
        self.period = period
        self.buckets: dict[str, tuple[int, float]] = {}

    async def dispatch(self, request: Request, call_next):
        client_ip = request.client.host if request.client else "unknown"
        now = time.time()
        tokens, last = self.buckets.get(client_ip, (self.limit, now))
        if now - last > self.period:
            tokens = self.limit
            last = now
        if tokens <= 0:
            return Response("Too Many Requests", status_code=429)
        tokens -= 1
        self.buckets[client_ip] = (tokens, last)
        return await call_next(request)
