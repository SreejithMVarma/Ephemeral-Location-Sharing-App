import asyncio
import logging
from collections.abc import Awaitable, Callable

from redis.asyncio import Redis

from src.core.config import settings

try:
    from fakeredis import aioredis
    FAKEREDIS_AVAILABLE = True
except ImportError:
    FAKEREDIS_AVAILABLE = False

_redis: Redis | None = None
_listener_task: asyncio.Task[None] | None = None
_expiry_callbacks: list[Callable[[str], Awaitable[None]]] = []

logger = logging.getLogger(__name__)


def register_expiry_callback(callback: Callable[[str], Awaitable[None]]) -> None:
    _expiry_callbacks.append(callback)


def get_redis() -> Redis:
    if _redis is None:
        raise RuntimeError("Redis client is not initialized")
    return _redis


def set_redis_for_tests(client: Redis | None) -> None:
    global _redis
    _redis = client


async def _listen_for_expired_keys() -> None:
    redis = get_redis()
    db = redis.connection_pool.connection_kwargs.get("db", 0)
    channel = f"__keyevent@{db}__:expired"
    pubsub = redis.pubsub()
    await pubsub.subscribe(channel)
    try:
        while True:
            message = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
            if not message:
                await asyncio.sleep(0.05)
                continue
            key = str(message.get("data", ""))
            for callback in list(_expiry_callbacks):
                try:
                    await callback(key)
                except Exception:
                    logger.exception("Expiry callback failed", extra={"key": key})
    except asyncio.CancelledError:
        raise
    finally:
        await pubsub.unsubscribe(channel)
        await pubsub.aclose()


async def init_redis() -> None:
    global _redis, _listener_task
    try:
        _redis = Redis.from_url(
            settings.redis_url,
            decode_responses=True,
            max_connections=settings.redis_max_connections,
        )
        # Test connection
        await _redis.ping()
        logger.info("✓ Connected to Redis at %s", settings.redis_url)
        
        try:
            await _redis.config_set("notify-keyspace-events", "KEA")
        except Exception:
            logger.warning("Unable to configure Redis keyspace notifications. Ensure KEA is set in redis.conf")

        if settings.redis_enable_keyspace_listener and _listener_task is None:
            _listener_task = asyncio.create_task(_listen_for_expired_keys())
    except Exception as exc:
        logger.warning("Failed to connect to Redis at %s: %s", settings.redis_url, exc)
        if FAKEREDIS_AVAILABLE:
            logger.warning("Falling back to fakeredis (in-memory, development only)")
            _redis = aioredis.FakeRedis(decode_responses=True)
            logger.info("✓ Using fakeredis for development")
        else:
            raise RuntimeError(
                f"Failed to connect to Redis and fakeredis is not available. "
                f"Please install Redis or run: pip install fakeredis[aioredis]"
            ) from exc


async def close_redis() -> None:
    global _redis, _listener_task
    if _listener_task is not None:
        _listener_task.cancel()
        try:
            await _listener_task
        except asyncio.CancelledError:
            pass
        _listener_task = None

    if _redis is not None:
        await _redis.aclose()
        _redis = None


async def redis_health() -> bool:
    if _redis is None:
        return False
    try:
        return bool(await _redis.ping())
    except Exception:
        return False
