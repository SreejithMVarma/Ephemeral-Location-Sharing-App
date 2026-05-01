import asyncio
from collections import defaultdict

from fastapi import WebSocket


class ConnectionManager:
    def __init__(self) -> None:
        self._connections: dict[str, set[WebSocket]] = defaultdict(set)
        self._lock = asyncio.Lock()

    async def connect(self, session_id: str, websocket: WebSocket) -> int:
        async with self._lock:
            self._connections[session_id].add(websocket)
            return len(self._connections[session_id])

    async def disconnect(self, session_id: str, websocket: WebSocket) -> None:
        async with self._lock:
            if session_id in self._connections:
                self._connections[session_id].discard(websocket)
                if not self._connections[session_id]:
                    self._connections.pop(session_id, None)

    async def count(self, session_id: str) -> int:
        async with self._lock:
            return len(self._connections.get(session_id, set()))

    async def room_connections(self, session_id: str) -> list[WebSocket]:
        async with self._lock:
            return list(self._connections.get(session_id, set()))
