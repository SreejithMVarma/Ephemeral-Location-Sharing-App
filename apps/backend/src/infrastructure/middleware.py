import uuid

from fastapi import HTTPException, Request

from src.core.logging import clear_log_context, set_log_context
from src.core.rate_limit import RedisRateLimiter
from src.infrastructure.redis_client import get_redis


def _extract_session_id(path: str) -> str:
    parts = path.strip("/").split("/")
    try:
        sessions_index = parts.index("sessions")
    except ValueError:
        return "-"
    if sessions_index + 1 < len(parts):
        candidate = parts[sessions_index + 1]
        return candidate if candidate and candidate != "verify" else "-"
    return "-"


async def request_id_middleware(request: Request, call_next):
    request_id = request.headers.get("X-Request-ID") or str(uuid.uuid4())
    session_id = _extract_session_id(request.url.path)
    request.state.request_id = request_id
    set_log_context(request_id=request_id, session_id=session_id)
    try:
        response = await call_next(request)
        response.headers["X-Request-ID"] = request_id
        return response
    finally:
        clear_log_context()


async def ip_blocklist_middleware(request: Request, call_next):
    ip = request.client.host if request.client else "unknown"
    redis = get_redis()

    if await redis.sismember("ip:blocklist", ip):
        raise HTTPException(status_code=403, detail="Forbidden")

    response = await call_next(request)
    if response.status_code != 429:
        return response

    limiter = RedisRateLimiter(redis)
    abuse_key = f"abuse:rate-limit:{ip}"
    if await limiter.too_many_hits(abuse_key, threshold=10, window_seconds=60):
        await redis.sadd("ip:blocklist", ip)
        await redis.setex(f"ip:blocklist:ttl:{ip}", 3600, "1")
    return response


async def request_size_middleware(request: Request, call_next):
    path = request.url.path
    if path.startswith("/api/") and request.method in {"POST", "PUT", "PATCH"}:
        content_length = request.headers.get("content-length")
        if content_length and int(content_length) > 10 * 1024:
            raise HTTPException(status_code=413, detail="Request payload too large")
    return await call_next(request)
