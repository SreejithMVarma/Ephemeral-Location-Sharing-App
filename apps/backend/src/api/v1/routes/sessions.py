import hmac
import json
import logging
import secrets
from uuid import uuid4

from fastapi import APIRouter, HTTPException, Query

from src.core.config import settings
from src.core.exceptions import NotFoundError
from src.models.session import (
    CreateSessionRequest,
    CreateSessionResponse,
    JoinSessionRequest,
    VerifySessionResponse,
)
from src.repositories.session_repository import SessionRepository

router = APIRouter(prefix="/sessions", tags=["sessions"])
repository = SessionRepository()
logger = logging.getLogger(__name__)


def _generate_passkey() -> str:
    """Generate a simple 8-character alphanumeric passkey."""
    while True:
        candidate = "".join(ch for ch in secrets.token_urlsafe(8) if ch.isalnum())
        if len(candidate) >= 8:
            return candidate[:8]


def _ws_url_for_region(region: str) -> str:
    """Get WebSocket URL for region."""
    region_map = json.loads(settings.region_ws_urls)
    return str(region_map.get(region) or region_map.get("us-east") or next(iter(region_map.values())))


@router.post("", response_model=CreateSessionResponse)
async def create_session(payload: CreateSessionRequest) -> CreateSessionResponse:
    """Create a new session (radar)."""
    session_id = str(uuid4())
    passkey = _generate_passkey()
    deep_link_url = f"{settings.deep_link_scheme}://join?s={session_id}&p={passkey}&r={payload.region}"

    logger.info(f"Creating session: {session_id} ({payload.session_name})")

    # Create session in Redis
    await repository.create_session(
        session_id,
        {
            "session_id": session_id,
            "session_name": payload.session_name,
            "admin_id": payload.admin_id,
            "region": payload.region,
            "passkey": passkey,
        },
        host_user_id=payload.admin_id,
    )
    
    # Set admin profile
    await repository.set_user_profile(
        payload.admin_id,
        {
            "display_name": payload.admin_display_name,
            "current_session": session_id,
        },
    )

    return CreateSessionResponse(session_id=session_id, passkey=passkey, deep_link_url=deep_link_url)


@router.get("/verify", response_model=VerifySessionResponse)
async def verify_session(
    s: str = Query(alias="s"),
    p: str = Query(alias="p"),
) -> VerifySessionResponse:
    """Verify session exists and return WebSocket URL."""
    session = await repository.get_hash(repository.session_key(s))
    if not session:
        raise NotFoundError("Radar not found")

    stored_passkey = session.get("passkey", "")
    if not hmac.compare_digest(stored_passkey, p):
        raise NotFoundError("Radar not found")

    members = await repository.get_members(s)
    return VerifySessionResponse(
        session_name=session.get("session_name", "Unnamed session"),
        host_name=session.get("admin_id", "host"),
        active_members=len(members),
        websocket_url=_ws_url_for_region(session.get("region", "us-east")),
    )


@router.post("/{session_id}/join")
async def join_session(session_id: str, payload: JoinSessionRequest) -> dict[str, str]:
    """Join an existing session."""
    session = await repository.get_hash(repository.session_key(session_id))
    if not session:
        raise NotFoundError("Radar not found")

    logger.info(f"User {payload.user_id} joining session {session_id}")

    # Add user to session members
    await repository.add_member(session_id, payload.user_id)
    
    # Set user profile
    await repository.set_user_profile(
        payload.user_id,
        {
            "display_name": payload.display_name,
            "current_session": session_id,
        },
    )
    
    return {"status": "joined"}
