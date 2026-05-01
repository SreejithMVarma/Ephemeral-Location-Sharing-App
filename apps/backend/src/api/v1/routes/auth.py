import hmac

from fastapi import APIRouter, HTTPException

from src.core.security import create_token, get_jwks
from src.models.auth import AuthTokenRequest, AuthTokenResponse
from src.repositories.session_repository import SessionRepository

router = APIRouter(prefix="/auth", tags=["auth"])
repository = SessionRepository()


@router.post("/token", response_model=AuthTokenResponse)
async def issue_token(payload: AuthTokenRequest) -> AuthTokenResponse:
    session = await repository.get_hash(repository.session_key(payload.session_id))
    if not session:
        raise HTTPException(status_code=404, detail="Radar not found")
    if not hmac.compare_digest(session.get("passkey", ""), payload.passkey):
        raise HTTPException(status_code=404, detail="Radar not found")

    role = "admin" if payload.user_id == session.get("admin_id") else "member"
    token = create_token(payload.user_id, payload.session_id, role)
    return AuthTokenResponse(access_token=token)


@router.get("/jwks")
async def jwks() -> dict:
    return get_jwks()
