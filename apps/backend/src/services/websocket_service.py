import json
from datetime import UTC, datetime

from fastapi import WebSocket, WebSocketDisconnect

from src.core.config import settings
from src.models.ws import WsEnvelope, WsMessageType
from src.repositories.session_repository import SessionRepository
from src.services.connection_manager import ConnectionManager


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
                # Connection may be closed, skip
                print(f"Failed to send message: {e}")

    async def _handle_location(self, session_id: str, envelope: WsEnvelope) -> None:
        """Store location and broadcast to session."""
        payload = envelope.payload
        lat = float(payload.get("lat", 0))
        lng = float(payload.get("lng", 0))
        
        # Store location in Redis
        await self.repository.add_location(session_id, envelope.sender_id, lng=lng, lat=lat)
        
        # Broadcast to all users in session
        outgoing = {
            "type": WsMessageType.LOCATION_UPDATE,
            "payload": payload,
            "sender_id": envelope.sender_id,
            "timestamp": envelope.timestamp,
        }
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
        await self.connections.connect(session_id, websocket)

        # Notify others that user connected
        await self._send_room(
            session_id,
            {
                "type": WsMessageType.USER_CONNECTED,
                "payload": {"user_id": token},
                "sender_id": token,
                "timestamp": datetime.now(UTC).isoformat(),
            },
        )

        try:
            while True:
                # Receive message from client
                raw_text = await websocket.receive_text()
                if not raw_text:
                    continue

                data = json.loads(raw_text)
                if not data:
                    continue

                envelope = WsEnvelope.model_validate(data)

                # Handle different message types
                if envelope.type == WsMessageType.LOCATION_UPDATE:
                    await self._handle_location(session_id, envelope)
                elif envelope.type == WsMessageType.PONG:
                    # Ignore pong for now
                    pass

        except WebSocketDisconnect:
            pass
        finally:
            # Cleanup on disconnect
            await self.connections.disconnect(session_id, websocket)
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
