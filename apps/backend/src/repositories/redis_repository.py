import logging
from typing import Any

from redis.asyncio import Redis

from src.infrastructure.redis_client import get_redis

logger = logging.getLogger(__name__)


class RedisRepository:
    @property
    def redis(self) -> Redis:
        return get_redis()

    async def health(self) -> bool:
        try:
            return bool(await self.redis.ping())
        except Exception:
            logger.exception("Redis health check failed")
            return False

    async def get_hash(self, key: str) -> dict[str, str]:
        try:
            return await self.redis.hgetall(key)
        except Exception:
            logger.exception("Redis HGETALL failed", extra={"key": key})
            return {}

    async def set_hash(self, key: str, values: dict[str, Any], ttl_seconds: int | None = None) -> None:
        try:
            pipeline = self.redis.pipeline(transaction=True)
            pipeline.hset(key, mapping=values)
            if ttl_seconds is not None:
                pipeline.expire(key, ttl_seconds)
            await pipeline.execute()
        except Exception:
            logger.exception("Redis HSET failed", extra={"key": key})
            raise

    async def delete(self, *keys: str) -> int:
        if not keys:
            return 0
        try:
            return int(await self.redis.delete(*keys))
        except Exception:
            logger.exception("Redis DEL failed", extra={"keys": keys})
            raise
