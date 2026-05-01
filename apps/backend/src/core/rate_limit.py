from dataclasses import dataclass

from redis.asyncio import Redis


@dataclass(frozen=True)
class RateLimitResult:
    allowed: bool
    remaining: int
    reset_seconds: int


class RedisRateLimiter:
    def __init__(self, redis: Redis) -> None:
        self._redis = redis

    async def hit(self, key: str, limit: int, window_seconds: int) -> RateLimitResult:
        count = int(await self._redis.incr(key))
        if count == 1:
            await self._redis.expire(key, window_seconds)

        ttl = await self._redis.ttl(key)
        reset_seconds = max(int(ttl), 0)
        allowed = count <= limit
        remaining = max(limit - count, 0)
        return RateLimitResult(allowed=allowed, remaining=remaining, reset_seconds=reset_seconds)

    async def too_many_hits(self, key: str, threshold: int, window_seconds: int) -> bool:
        result = await self.hit(key, threshold, window_seconds)
        return not result.allowed
