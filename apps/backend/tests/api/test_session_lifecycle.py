import pytest
from fastapi.testclient import TestClient
from fakeredis.aioredis import FakeRedis

from src.infrastructure.redis_client import set_redis_for_tests
from src.main import app


@pytest.fixture
def client(monkeypatch):
    fake = FakeRedis(decode_responses=True)
    set_redis_for_tests(fake)

    async def _noop() -> None:
        return None

    monkeypatch.setattr("src.main.init_redis", _noop)
    monkeypatch.setattr("src.main.close_redis", _noop)

    with TestClient(app) as test_client:
        yield test_client
    set_redis_for_tests(None)


def test_full_session_lifecycle_create_verify_join_leave_terminate(client: TestClient):
    create_resp = client.post(
        "/api/v1/sessions",
        json={
            "session_name": "Test Session",
            "admin_id": "admin_1",
            "chat_enabled": True,
            "region": "us-east",
        },
    )
    assert create_resp.status_code == 200
    created = create_resp.json()

    verify_resp = client.get(f"/api/v1/sessions/verify?s={created['session_id']}&p={created['passkey']}")
    assert verify_resp.status_code == 200
    verify_data = verify_resp.json()
    assert verify_data["session_name"] == "Test Session"
    assert "websocket_url" in verify_data

    join_resp = client.post(
        f"/api/v1/sessions/{created['session_id']}/join",
        json={
            "user_id": "member_1",
            "display_name": "Member",
            "avatar_url": "",
            "privacy_mode": "direction_distance",
            "fcm_token": "fcm_token_initial_123456",
        },
    )
    assert join_resp.status_code == 200

    token_refresh_resp = client.post(
        f"/api/v1/sessions/{created['session_id']}/device-token",
        json={
            "user_id": "member_1",
            "fcm_token": "fcm_token_rotated_123456",
        },
    )
    assert token_refresh_resp.status_code == 200
    assert token_refresh_resp.json()["status"] == "updated"

    admin_token = client.post(
        "/api/v1/auth/token",
        json={
            "user_id": "admin_1",
            "session_id": created["session_id"],
            "passkey": created["passkey"],
        },
    ).json()["access_token"]

    member_token = client.post(
        "/api/v1/auth/token",
        json={
            "user_id": "member_1",
            "session_id": created["session_id"],
            "passkey": created["passkey"],
        },
    ).json()["access_token"]

    leave_resp = client.post(
        f"/api/v1/sessions/{created['session_id']}/leave",
        json={"user_id": "member_1"},
        headers={"Authorization": f"Bearer {member_token}"},
    )
    assert leave_resp.status_code == 200

    terminate_resp = client.delete(
        f"/api/v1/sessions/{created['session_id']}",
        headers={"Authorization": f"Bearer {admin_token}"},
    )
    assert terminate_resp.status_code == 200
    assert terminate_resp.json()["status"] == "deleted"


def test_verify_wrong_passkey_returns_404(client: TestClient):
    create_resp = client.post(
        "/api/v1/sessions",
        json={
            "session_name": "Test Session",
            "admin_id": "admin_1",
            "chat_enabled": True,
            "region": "us-east",
        },
    )
    created = create_resp.json()

    verify_resp = client.get(f"/api/v1/sessions/verify?s={created['session_id']}&p=WRONGKEY")
    assert verify_resp.status_code == 404


def test_admin_only_delete_forbidden_for_non_admin(client: TestClient):
    create_resp = client.post(
        "/api/v1/sessions",
        json={
            "session_name": "Test Session",
            "admin_id": "admin_1",
            "chat_enabled": True,
            "region": "us-east",
        },
    )
    created = create_resp.json()

    member_token = client.post(
        "/api/v1/auth/token",
        json={
            "user_id": "member_2",
            "session_id": created["session_id"],
            "passkey": created["passkey"],
        },
    ).json()["access_token"]

    terminate_resp = client.delete(
        f"/api/v1/sessions/{created['session_id']}",
        headers={"Authorization": f"Bearer {member_token}"},
    )
    assert terminate_resp.status_code == 403


def test_create_session_rate_limit_returns_429_after_five_requests(client: TestClient):
    payload = {
        "session_name": "Rate Limit Test",
        "admin_id": "admin_1",
        "chat_enabled": True,
        "region": "us-east",
    }

    for _ in range(5):
        response = client.post("/api/v1/sessions", json=payload)
        assert response.status_code == 200

    limited = client.post("/api/v1/sessions", json=payload)
    assert limited.status_code == 429


def test_verify_rate_limit_headers_and_retry_after(client: TestClient):
    created = client.post(
        "/api/v1/sessions",
        json={
            "session_name": "Verify Limit",
            "admin_id": "admin_1",
            "chat_enabled": True,
            "region": "us-east",
        },
    ).json()

    first = client.get(f"/api/v1/sessions/verify?s={created['session_id']}&p={created['passkey']}")
    assert first.status_code == 200
    assert "X-RateLimit-Remaining" in first.headers
    assert "X-RateLimit-Reset" in first.headers

    for _ in range(19):
        response = client.get(f"/api/v1/sessions/verify?s={created['session_id']}&p={created['passkey']}")
        assert response.status_code == 200

    limited = client.get(f"/api/v1/sessions/verify?s={created['session_id']}&p={created['passkey']}")
    assert limited.status_code == 429
    assert "Retry-After" in limited.headers
