from datetime import UTC, datetime

from fastapi import APIRouter

from src.infrastructure.redis_client import redis_health

router = APIRouter(tags=["health"])


@router.get("/health")
async def health() -> dict[str, str | bool]:
    redis_connected = await redis_health()
    return {
        "status": "ok",
        "version": "0.1.0",
        "redis_connected": redis_connected,
        "timestamp": datetime.now(UTC).isoformat(),
    }
