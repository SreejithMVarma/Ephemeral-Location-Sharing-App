import asyncio
import json
import logging
from datetime import UTC, datetime

from fastapi import WebSocket, WebSocketDisconnect

from src.core.config import settings
from src.models.ws import WsEnvelope, WsMessageType
from src.repositories.session_repository import SessionRepository
from src.services.connection_manager import ConnectionManager
from src.services.pubsub_broadcaster import PubSubBroadcaster
from src.services.viewport_service import ViewportService
from src.infrastructure.redis_client import get_redis
from src.core.rate_limit import RedisRateLimiter
from src.infrastructure.metrics import increment_active_connections, decrement_active_connections, increment_location_updates, observe_ws_broadcast_latency

logger = logging.getLogger(__name__)


class WebSocketService:
    def __init__(self) -> None:
        self.connections = ConnectionManager()
        self.repository = SessionRepository()
        self.broadcaster = PubSubBroadcaster()
        self.viewport = ViewportService()
        self._redis_listener_task: asyncio.Task | None = None

    async def _send_room(
        self,
        session_id: str,
        message: dict,
        exclude: WebSocket | None = None,
    ) -> None:
        """Broadcast message to all connections in a session."""
        sockets = await self.connections.room_connections(session_id)
        for sock in sockets:
            if exclude is not None and sock is exclude:
                continue
            try:
                await sock.send_json(message)
            except Exception as e:
                logger.warning(f"Failed to send message to socket: {e}")

    async def broadcast_session_ended(self, session_id: str) -> None:
        """Broadcast SESSION_ENDED to all connected clients in a session."""
        await self._send_room(
            session_id,
            {
                "type": WsMessageType.SESSION_ENDED,
                "payload": {"reason": "host_destroyed"},
                "sender_id": "server",
                "timestamp": datetime.now(UTC).isoformat(),
            },
        )

    async def _handle_location(self, session_id: str, envelope: WsEnvelope) -> None:
        """Store location and broadcast to session."""
        payload = envelope.payload
        lat = float(payload.get("lat", 0))
        lng = float(payload.get("lng", 0))

        logger.info(
            f"[WS] LOCATION_UPDATE session={session_id} user={envelope.sender_id} "
            f"lat={lat:.6f} lng={lng:.6f}"
        )

        # Store location in Redis
        await self.repository.add_location(session_id, envelope.sender_id, lng=lng, lat=lat)

        # Broadcast to all users in session (including sender so they can confirm)
        outgoing = {
            "type": WsMessageType.LOCATION_UPDATE,
            "payload": payload,
            "sender_id": envelope.sender_id,
            "timestamp": envelope.timestamp,
        }
        # Rate limit: enforce per-user location update limits (e.g., 10 updates per 5s)
        try:
            redis = get_redis()
            limiter = RedisRateLimiter(redis)
            key = f"rl:loc:{session_id}:{envelope.sender_id}"
            res = await limiter.hit(key, limit=10, window_seconds=5)
            if not res.allowed:
                # Optionally notify client they are rate limited
                try:
                    await self.connections.get_connection_by_token(session_id, envelope.sender_id)
                except Exception:
                    pass
                return
        except Exception:
            logger.debug("Rate limiter unavailable, proceeding without strict enforcement")

        # Local broadcast to currently connected sockets (coarse fallback)
        await self._send_room(session_id, outgoing)
        try:
            increment_location_updates()
        except Exception:
            pass

        # Publish to Redis so other instances can forward to their local subscribers
        try:
            await self.broadcaster.publish(session_id, outgoing)
        except Exception:
            logger.exception("Failed to publish location update")
        # Also, forward directly to local viewport subscribers using cell lookup
        try:
            subs = await self.viewport.subscribers_for_point(session_id, lat, lng)
            for ws in subs:
                try:
                    await ws.send_json(outgoing)
                except Exception:
                    logger.debug("Failed to forward to local viewport subscriber", exc_info=True)
        except Exception:
            logger.debug("Viewport forwarding failed", exc_info=True)

    async def _handle_chat(self, session_id: str, envelope: WsEnvelope, ws: WebSocket) -> None:
        """Persist and route a chat message (global or DM)."""
        payload = envelope.payload
        chat_type = payload.get("chat_type", "global")
        text = payload.get("text", "")
        sender_name = payload.get("sender_name", envelope.sender_id)

        outgoing = {
            "type": WsMessageType.CHAT_MESSAGE,
            "payload": payload,
            "sender_id": envelope.sender_id,
            "timestamp": envelope.timestamp,
        }

        if chat_type == "dm":
            target_user_id = payload.get("target_user_id", "")
            if not target_user_id:
                return

            logger.info(
                f"[WS] DM session={session_id} from={envelope.sender_id} to={target_user_id}"
            )

            # Persist
            msg_json = json.dumps({
                "sender_id": envelope.sender_id,
                "sender_name": sender_name,
                "text": text,
                "timestamp": envelope.timestamp,
            })
            await self.repository.append_dm_chat(
                session_id, envelope.sender_id, target_user_id, msg_json
            )

            # Deliver to target only
            target_ws = await self.connections.get_connection_by_token(session_id, target_user_id)
            if target_ws:
                try:
                    await target_ws.send_json(outgoing)
                except Exception as e:
                    logger.warning(f"Failed to deliver DM to {target_user_id}: {e}")

            # Echo back to sender
            try:
                await ws.send_json(outgoing)
            except Exception as e:
                logger.warning(f"Failed to echo DM to sender: {e}")

        else:
            # Global chat
            logger.info(
                f"[WS] GROUP_CHAT session={session_id} from={envelope.sender_id}: {text[:60]}"
            )
            msg_json = json.dumps({
                "sender_id": envelope.sender_id,
                "sender_name": sender_name,
                "text": text,
                "timestamp": envelope.timestamp,
            })
            await self.repository.append_global_chat(session_id, msg_json)
            await self._send_room(session_id, outgoing)

    async def handle_connection(self, websocket: WebSocket, session_id: str, token: str) -> None:
        """Handle WebSocket connection."""
        # Verify session exists
        session = await self.repository.get_hash(self.repository.session_key(session_id))
        if not session:
            await websocket.close(code=4404)
            return

        # Require token for identification
        if not token:
            await websocket.close(code=4401)
            return

        await websocket.accept()
        # Re-add user to session members on every WS connection (handles rejoins)
        await self.repository.add_member(session_id, token)
        await self.connections.connect(session_id, websocket, token=token)

        logger.info(f"[WS] CONNECTED session={session_id} user={token}")
        try:
            increment_active_connections()
        except Exception:
            pass

        # Notify others that user connected
        await self._send_room(
            session_id,
            {
                "type": WsMessageType.USER_CONNECTED,
                "payload": {"user_id": token},
                "sender_id": token,
                "timestamp": datetime.now(UTC).isoformat(),
            },
            exclude=websocket,
        )

        try:
            while True:
                raw_text = await websocket.receive_text()
                if not raw_text:
                    continue

                data = json.loads(raw_text)
                if not data:
                    continue

                envelope = WsEnvelope.model_validate(data)

                if envelope.type == WsMessageType.LOCATION_UPDATE:
                    await self._handle_location(session_id, envelope)
                elif envelope.type == WsMessageType.CHAT_MESSAGE:
                    await self._handle_chat(session_id, envelope, websocket)
                elif envelope.type == WsMessageType.VIEWPORT_SUBSCRIBE:
                    # Expect payload: { bbox: {north,south,east,west}, zoom }
                    bbox = envelope.payload.get("bbox", {})
                    zoom = int(envelope.payload.get("zoom", 0))
                    await self.viewport.subscribe(session_id, envelope.sender_id, websocket, bbox, zoom)
                    # Send initial snapshot: query Redis for points in bbox
                    try:
                        redis = get_redis()
                        # Use GEOSEARCH to find within bounding box if available;
                        # fallback to GEORADIUS by center+radius if not.
                        north = float(bbox.get("north", 90))
                        south = float(bbox.get("south", -90))
                        east = float(bbox.get("east", 180))
                        west = float(bbox.get("west", -180))
                        # Simple approach: fetch all members and filter by bbox
                        members = await self.repository.get_members(session_id)
                        points = []
                        for m in members:
                            pos = await redis.geopos(self.repository.locations_key(session_id), m)
                            if not pos or pos[0] is None:
                                continue
                            lng, lat = float(pos[0][0]), float(pos[0][1])
                            if south <= lat <= north and west <= lng <= east:
                                points.append({"id": m, "lat": lat, "lng": lng})
                        snapshot = {
                            "type": WsMessageType.VIEWPORT_SNAPSHOT,
                            "payload": {"users": points},
                            "sender_id": "server",
                            "timestamp": datetime.now(UTC).isoformat(),
                        }
                        await websocket.send_json(snapshot)
                    except Exception:
                        logger.exception("Failed to send viewport snapshot")
                elif envelope.type == WsMessageType.VIEWPORT_UNSUBSCRIBE:
                    await self.viewport.unsubscribe(session_id, envelope.sender_id)
                elif envelope.type == WsMessageType.PONG:
                    pass

        except WebSocketDisconnect:
            logger.info(f"[WS] DISCONNECTED session={session_id} user={token}")
        finally:
            await self.connections.disconnect(session_id, websocket, token=token)
            await self.repository.remove_member(session_id, token)
            await self.repository.remove_location_member(session_id, token)
            # Ensure viewport subscription removed
            try:
                await self.viewport.unsubscribe(session_id, token)
            except Exception:
                logger.debug("viewport unsubscribe on disconnect failed", exc_info=True)

            # Notify others that user disconnected
            await self._send_room(
                session_id,
                {
                    "type": WsMessageType.USER_DISCONNECTED,
                    "payload": {"user_id": token},
                    "sender_id": token,
                    "timestamp": datetime.now(UTC).isoformat(),
                },
            )
            try:
                decrement_active_connections()
            except Exception:
                pass

    async def start_redis_listener(self) -> None:
        """Start a background task to subscribe to Redis session event channels
        and forward relevant messages to local connections (respecting viewports).
        """
        if self._redis_listener_task is not None:
            return

        async def _listener() -> None:
            redis = get_redis()
            pubsub = redis.pubsub()
            # Pattern subscribe to session:*:events
            await pubsub.psubscribe("session:*:events")
            try:
                while True:
                    msg = await pubsub.get_message(ignore_subscribe_messages=True, timeout=1.0)
                    if not msg:
                        await asyncio.sleep(0.05)
                        continue
                    data = msg.get("data")
                    if not data:
                        continue
                    try:
                        payload = json.loads(data)
                    except Exception:
                        logger.debug("Invalid pubsub payload", exc_info=True)
                        continue
                    # Determine session id from channel name
                    channel = msg.get("channel", "")
                    # channel may be like 'session:abcd:events'
                    try:
                        if isinstance(channel, bytes):
                            channel = channel.decode()
                        parts = channel.split(":")
                        session_id = parts[1]
                    except Exception:
                        continue

                    # If payload is a location update with lat/lng, respect viewports
                    try:
                        msg_type = payload.get("type")
                        if msg_type == WsMessageType.LOCATION_UPDATE:
                            lat = float(payload.get("payload", {}).get("lat", 0))
                            lng = float(payload.get("payload", {}).get("lng", 0))
                            subs = await self.viewport.subscribers_for_point(session_id, lat, lng)
                            for ws in subs:
                                try:
                                    await ws.send_json(payload)
                                except Exception:
                                    logger.debug("Failed to forward pubsub payload to ws", exc_info=True)
                        else:
                            # Fallback: broadcast to entire local room
                            await self._send_room(session_id, payload)
                    except Exception:
                        logger.exception("Error processing pubsub message")
            finally:
                try:
                    await pubsub.punsubscribe("session:*:events")
                    await pubsub.aclose()
                except Exception:
                    pass

        self._redis_listener_task = asyncio.create_task(_listener())

    async def stop_redis_listener(self) -> None:
        if self._redis_listener_task is not None:
            self._redis_listener_task.cancel()
            try:
                await self._redis_listener_task
            except asyncio.CancelledError:
                pass
            self._redis_listener_task = None
