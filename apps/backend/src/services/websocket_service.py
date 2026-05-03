import json
import logging
from datetime import UTC, datetime

from fastapi import WebSocket, WebSocketDisconnect

from src.core.config import settings
from src.models.ws import WsEnvelope, WsMessageType
from src.repositories.session_repository import SessionRepository
from src.services.connection_manager import ConnectionManager

logger = logging.getLogger(__name__)


class WebSocketService:
    def __init__(self) -> None:
        self.connections = ConnectionManager()
        self.repository = SessionRepository()

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
        await self._send_room(session_id, outgoing)

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
                elif envelope.type == WsMessageType.PONG:
                    pass

        except WebSocketDisconnect:
            logger.info(f"[WS] DISCONNECTED session={session_id} user={token}")
        finally:
            await self.connections.disconnect(session_id, websocket, token=token)
            await self.repository.remove_member(session_id, token)
            await self.repository.remove_location_member(session_id, token)

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
