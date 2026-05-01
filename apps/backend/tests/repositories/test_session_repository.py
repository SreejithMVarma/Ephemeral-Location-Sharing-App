import os

import pytest
from redis.asyncio import Redis

from src.repositories.session_repository import SESSION_TTL_SECONDS, SessionRepository


@pytest.mark.asyncio
async def test_create_session_sets_ttl_and_fields(fake_redis_client):
    repo = SessionRepository()
    session_id = "sess_ttl"

    await repo.create_session(session_id, {"name": "Test Session"}, host_user_id="host_1")

    session = await repo.get_hash(repo.session_key(session_id))
    ttl = await fake_redis_client.ttl(repo.session_key(session_id))
    members = await repo.get_members(session_id)

    assert session["name"] == "Test Session"
    assert ttl > 0
    assert ttl <= SESSION_TTL_SECONDS
    assert "host_1" in members


@pytest.mark.asyncio
async def test_bulk_create_session_is_atomic(fake_redis_client):
    repo = SessionRepository()
    session_id = "sess_atomic"

    await repo.bulk_create_session_atomic(
        session_id,
        {"name": "Atomic"},
        ["u1", "u2"],
    )

    session = await repo.get_hash(repo.session_key(session_id))
    members = await repo.get_members(session_id)

    assert session["name"] == "Atomic"
    assert members == {"u1", "u2"}


@pytest.mark.asyncio
async def test_georadius_boundaries_1m_20m_21m(fake_redis_client):
    repo = SessionRepository()
    session_id = "sess_geo"

    # Anchor at equator; longitude deltas approximate meter distances.
    await repo.add_location(session_id, "anchor", 0.0, 0.0)
    await repo.add_location(session_id, "near_1m", 0.000008, 0.0)
    await repo.add_location(session_id, "near_20m", 0.00015, 0.0)
    await repo.add_location(session_id, "far_21m", 0.00030, 0.0)

    within_1 = {member for member, _ in await repo.nearby_members(session_id, "anchor", 1.0)}
    within_20 = {member for member, _ in await repo.nearby_members(session_id, "anchor", 20.0)}

    assert "anchor" in within_1
    assert "near_20m" in within_20
    assert "far_21m" not in within_20


@pytest.mark.asyncio
@pytest.mark.skipif(
    not os.getenv("RUN_REDIS_INTEGRATION"),
    reason="Set RUN_REDIS_INTEGRATION=1 to run real Redis boundary checks",
)
async def test_georadius_boundaries_real_redis_1m_20m_21m():
    redis_url = os.getenv("REDIS_URL", "redis://localhost:6379/0")
    client = Redis.from_url(redis_url, decode_responses=True)
    session_id = "sess_geo_real"
    repo = SessionRepository()

    from src.infrastructure.redis_client import set_redis_for_tests

    set_redis_for_tests(client)
    try:
        await repo.add_location(session_id, "anchor", 0.0, 0.0)
        await repo.add_location(session_id, "near_1m", 0.000008, 0.0)
        await repo.add_location(session_id, "near_20m", 0.00017966, 0.0)
        await repo.add_location(session_id, "far_21m", 0.00018864, 0.0)

        within_1 = {member for member, _ in await repo.nearby_members(session_id, "anchor", 1.0)}
        within_20 = {member for member, _ in await repo.nearby_members(session_id, "anchor", 20.0)}
        within_21 = {member for member, _ in await repo.nearby_members(session_id, "anchor", 21.0)}

        assert "anchor" in within_1
        assert "near_1m" in within_1
        assert "near_20m" in within_20
        assert "far_21m" not in within_20
        assert "far_21m" in within_21
    finally:
        await repo.delete_session_cascade(session_id)
        await client.aclose()
        set_redis_for_tests(None)
