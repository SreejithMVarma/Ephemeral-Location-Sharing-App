from fastapi import APIRouter, HTTPException

router = APIRouter(tags=["compliance"])


@router.get("/privacy")
async def privacy_policy() -> dict[str, str]:
    """
    Privacy policy endpoint — GDPR/App Store compliance.
    
    Returns data processing statement for user consent and legal compliance.
    """
    return {
        "title": "Ephemeral Radar Privacy Policy",
        "version": "1.0.0",
        "effective_date": "2026-04-01",
        "data_collection": "Location data shared only during active sessions with explicit user consent via permission prompt.",
        "data_retention": "No persistent user database. Session data retained only for session duration (default 12 hours). All data deleted immediately on session termination or 12h TTL expiry.",
        "third_party_sharing": "No third-party data sharing. Location data shared only with session members via end-to-end encrypted WebSocket.",
        "user_rights": "Users can request data deletion by leaving session or waiting for automatic 12h expiry. No account recovery or historical data available.",
        "contact": "privacy@radarapp.io",
    }
