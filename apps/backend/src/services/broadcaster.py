import logging

logger = logging.getLogger(__name__)


class EventBroadcaster:
    async def broadcast(self, session_id: str, event_type: str, payload: dict) -> None:
        logger.info(
            "Broadcast event",
            extra={"session_id": session_id, "event_type": event_type, "payload": payload},
        )
