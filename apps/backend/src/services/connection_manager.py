import asyncio
from collections import defaultdict

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)
        # Maps session_id -> {token -> websocket} for targeted DM delivery
        self._token_map: dict[str, dict[str, WebSocket]] = defaultdict(dict)
        self._lock = asyncio.Lock()

    async def connect(self, session_id: str, websocket: WebSocket, token: str = "") -> int:
        async with self._lock:
            self._connections[session_id].add(websocket)
            if token:
                self._token_map[session_id][token] = websocket
            return len(self._connections[session_id])

    async def disconnect(self, session_id: str, websocket: WebSocket, token: str = "") -> None:
        async with self._lock:
            if session_id in self._connections:
                self._connections[session_id].discard(websocket)
                if not self._connections[session_id]:
                    self._connections.pop(session_id, None)
            if token and session_id in self._token_map:
                self._token_map[session_id].pop(token, None)
                if not self._token_map[session_id]:
                    self._token_map.pop(session_id, None)

    async def count(self, session_id: str) -> int:
        async with self._lock:
            return len(self._connections.get(session_id, set()))

    async def room_connections(self, session_id: str) -> list[WebSocket]:
        async with self._lock:
            return list(self._connections.get(session_id, set()))

    async def get_connection_by_token(self, session_id: str, token: str) -> WebSocket | None:
        """Return the WebSocket for a specific user token (for DM delivery)."""
        async with self._lock:
            return self._token_map.get(session_id, {}).get(token)
