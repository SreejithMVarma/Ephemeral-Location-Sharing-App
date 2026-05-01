from dataclasses import dataclass
from enum import Enum
from typing import Any

from src.core.config import settings


class NotificationType(str, Enum):
    NEW_LOCATION_DATA = "NEW_LOCATION_DATA"
    PROXIMITY_ALERT = "PROXIMITY_ALERT"
    CHAT_MESSAGE = "CHAT_MESSAGE"
    SESSION_ENDED = "SESSION_ENDED"
    PULSE_PING = "PULSE_PING"


@dataclass(frozen=True)
class FcmPayload:
    type: NotificationType
    session_id: str

    def to_wire_data(self) -> dict[str, str]:
        # Privacy-safe contract: only type + session_id are allowed.
        return {"type": self.type.value, "session_id": self.session_id}


class NotificationService:
    def __init__(self) -> None:
        self.sender_id = settings.fcm_sender_id

    def build_payload(self, notification_type: NotificationType, session_id: str) -> dict[str, str]:
        payload = FcmPayload(type=notification_type, session_id=session_id).to_wire_data()
        self._validate_zero_data(payload)
        return payload

    def _validate_zero_data(self, payload: dict[str, Any]) -> None:
        if set(payload.keys()) != {"type", "session_id"}:
            raise ValueError("FCM payload must contain only type and session_id")

        blocked_keys = {
            "lat",
            "lng",
            "latitude",
            "longitude",
            "name",
            "display_name",
            "email",
            "phone",
            "token",
        }
        if blocked_keys.intersection(payload.keys()):
            raise ValueError("FCM payload contains disallowed fields")

    async def send_multicast(
        self,
        notification_type: NotificationType,
        session_id: str,
        tokens: list[str],
    ) -> dict[str, int]:
        # Keep backend testable in local/dev environments without hard dependency
        # on Firebase credentials while preserving payload validation.
        payload = self.build_payload(notification_type, session_id)
        if not tokens:
            return {"success": 0, "failure": 0}

        # Placeholder send result: wiring to firebase_admin can be enabled when
        # service-account credentials are present in the deployment environment.
        _ = payload
        return {"success": len(tokens), "failure": 0}
