import base64
import uuid
from datetime import UTC, datetime, timedelta

import jwt
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from fastapi import Header, HTTPException

from src.repositories.session_repository import SESSION_TTL_SECONDS, SessionRepository

AUDIENCE = "ephemeral-radar-backend"
KID = "local-dev-rs256-1"

_private_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
_public_key = _private_key.public_key()

_private_pem = _private_key.private_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PrivateFormat.PKCS8,
    encryption_algorithm=serialization.NoEncryption(),
)
_public_pem = _public_key.public_bytes(
    encoding=serialization.Encoding.PEM,
    format=serialization.PublicFormat.SubjectPublicKeyInfo,
)


def _b64url_uint(value: int) -> str:
    b = value.to_bytes((value.bit_length() + 7) // 8, "big")
    return base64.urlsafe_b64encode(b).decode("utf-8").rstrip("=")


def create_token(user_id: str, session_id: str, role: str, expires_seconds: int = SESSION_TTL_SECONDS) -> str:
    now = datetime.now(UTC)
    payload = {
        "sub": user_id,
        "session_id": session_id,
        "role": role,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(seconds=expires_seconds)).timestamp()),
        "aud": AUDIENCE,
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, _private_pem, algorithm="RS256", headers={"kid": KID})


def decode_token(token: str) -> dict:
    return jwt.decode(token, _public_pem, algorithms=["RS256"], audience=AUDIENCE)


def get_jwks() -> dict:
    public_numbers = _public_key.public_numbers()
    return {
        "keys": [
            {
                "kty": "RSA",
                "use": "sig",
                "alg": "RS256",
                "kid": KID,
                "n": _b64url_uint(public_numbers.n),
                "e": _b64url_uint(public_numbers.e),
            }
        ]
    }


def get_bearer_token(authorization: str | None = Header(default=None)) -> str | None:
    if not authorization:
        return None
    if not authorization.startswith("Bearer "):
        return None
    return authorization.removeprefix("Bearer ").strip()


async def assert_token_valid_for_session(token: str | None, session_id: str) -> dict:
    if not token:
        raise HTTPException(status_code=401, detail="Missing token")

    try:
        claims = decode_token(token)
    except jwt.InvalidTokenError as exc:
        raise HTTPException(status_code=401, detail="Invalid token") from exc

    if claims.get("session_id") != session_id:
        raise HTTPException(status_code=401, detail="Invalid session scope")

    blacklist_key = f"token:blacklist:{claims['jti']}"
    repo = SessionRepository()
    is_blacklisted = await repo.redis.exists(blacklist_key)
    if is_blacklisted:
        raise HTTPException(status_code=401, detail="Token revoked")
    return claims


async def blacklist_token_jti(jti: str, ttl_seconds: int) -> None:
    repo = SessionRepository()
    await repo.redis.set(f"token:blacklist:{jti}", "1", ex=ttl_seconds)
