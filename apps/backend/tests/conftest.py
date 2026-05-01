import pytest
import pytest_asyncio
from fakeredis.aioredis import FakeRedis

from src.infrastructure.redis_client import set_redis_for_tests


@pytest_asyncio.fixture
async def fake_redis_client():
    client = FakeRedis(decode_responses=True)
    set_redis_for_tests(client)
    yield client
    await client.flushall()
    await client.aclose()
    set_redis_for_tests(None)
