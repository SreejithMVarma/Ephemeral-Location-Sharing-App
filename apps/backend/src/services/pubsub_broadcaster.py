import json
import logging
from typing import Any, Dict

from src.infrastructure.redis_client import get_redis

logger = logging.getLogger(__name__)


class PubSubBroadcaster:
    """Publish location events to Redis pub/sub so other backend instances
    can forward them to their local WS connections.
    Channel format: session:{session_id}:events
    """

    async def publish(self, session_id: str, event: Dict[str, Any]) -> None:
        try:
            redis = get_redis()
            channel = f"session:{session_id}:events"
            await redis.publish(channel, json.dumps(event))
        except Exception:
            logger.exception("Failed to publish session event", extra={"session_id": session_id})
