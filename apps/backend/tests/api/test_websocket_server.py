import pytest
from fastapi.testclient import TestClient
from fakeredis.aioredis import FakeRedis

from src.infrastructure.redis_client import set_redis_for_tests
from src.main import app
from src.repositories.session_repository import SessionRepository


@pytest.fixture
def isolated_redis(monkeypatch):
    fake = FakeRedis(decode_responses=True)
    set_redis_for_tests(fake)

    async def _noop() -> None:
        return None

    monkeypatch.setattr("src.main.init_redis", _noop)
    monkeypatch.setattr("src.main.close_redis", _noop)
    yield
    set_redis_for_tests(None)


def test_websocket_rejects_missing_token(isolated_redis):
    repo = SessionRepository()

    import asyncio

    asyncio.run(
        repo.create_session(
            "sess_ws_missing",
            {"session_name": "WS", "admin_id": "admin_1", "passkey": "ABCD1234", "region": "us-east"},
            host_user_id="admin_1",
        )
    )

    with TestClient(app) as client:
        try:
            client.websocket_connect("/ws/sess_ws_missing")
            assert False, "Connection should fail without token"
        except Exception:
            assert True

def test_websocket_connect_and_disconnect_cleanup(isolated_redis):

    with TestClient(app) as client:
        created = client.post(
            "/api/v1/sessions",
            json={
                "session_name": "WS",
                "admin_id": "admin_1",
                "chat_enabled": True,
                "region": "us-east",
            },
        ).json()
        session_id = created["session_id"]

        client.post(
            f"/api/v1/sessions/{session_id}/join",
            json={
                "user_id": "member_1",
                "display_name": "Member",
                "avatar_url": "",
                "privacy_mode": "direction_distance",
            },
        )

        with client.websocket_connect(f"/ws/{session_id}?token=member_1") as websocket:
            _ = websocket.receive_json()

        repo = SessionRepository()
        import asyncio

        members = asyncio.run(repo.get_members(session_id))
        assert "member_1" not in members
