import jwt
import pytest
from fastapi.testclient import TestClient
from fakeredis.aioredis import FakeRedis

from src.core.security import blacklist_token_jti, create_token, decode_token
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


def test_expired_token_decode_raises():
    token = create_token("u1", "s1", "member", expires_seconds=-1)
    with pytest.raises(jwt.ExpiredSignatureError):
        decode_token(token)


def test_tampered_token_decode_raises():
    token = create_token("u1", "s1", "member")
    header, payload, signature = token.split(".")
    tampered_signature = ("a" if signature[0] != "a" else "b") + signature[1:]
    tampered = ".".join([header, payload, tampered_signature])
    with pytest.raises(jwt.InvalidTokenError):
        decode_token(tampered)


def test_blacklisted_token_rejected_on_session_delete(client: TestClient):
    created = client.post(
        "/api/v1/sessions",
        json={"session_name": "Auth", "admin_id": "admin_1", "chat_enabled": True, "region": "us-east"},
    ).json()

    token = client.post(
        "/api/v1/auth/token",
        json={"user_id": "admin_1", "session_id": created["session_id"], "passkey": created["passkey"]},
    ).json()["access_token"]

    claims = decode_token(token)

    import asyncio

    asyncio.run(blacklist_token_jti(claims["jti"], 3600))

    response = client.delete(
        f"/api/v1/sessions/{created['session_id']}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 401
