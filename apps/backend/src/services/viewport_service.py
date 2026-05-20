import asyncio
from typing import Dict, List, Set

from fastapi import WebSocket

from src.infrastructure.metrics import (
    increment_viewport_subscriptions,
    increment_viewport_unsubscriptions,
)


def _cell_size_for_zoom(zoom: int) -> float:
    # returns approximate degrees per cell for a given zoom level
    if zoom <= 5:
        return 5.0
    if zoom <= 10:
        return 0.5
    if zoom <= 13:
        return 0.05
    if zoom <= 16:
        return 0.01
    return 0.002


def _cell_key(lat: float, lng: float, cell_size: float) -> str:
    return f"{int(lat / cell_size)}:{int(lng / cell_size)}"


class ViewportService:
    def __init__(self) -> None:
        # session_id -> token -> subscription meta (websocket, bbox, zoom)
        self._sessions_tokens: Dict[str, Dict[str, dict]] = {}
        # session_id -> cell_key -> set of tokens subscribed to that cell
        self._sessions_cells: Dict[str, Dict[str, Set[str]]] = {}
        self._lock = asyncio.Lock()

    async def subscribe(self, session_id: str, token: str, websocket: WebSocket, bbox: Dict[str, float], zoom: int) -> None:
        async with self._lock:
            toks = self._sessions_tokens.setdefault(session_id, {})
            toks[token] = {"websocket": websocket, "bbox": bbox, "zoom": zoom}
            try:
                increment_viewport_subscriptions()
            except Exception:
                pass

            # Compute covered cells for this bbox and add token to each cell
            cell_size = _cell_size_for_zoom(zoom)
            north = bbox.get("north", 90)
            south = bbox.get("south", -90)
            east = bbox.get("east", 180)
            west = bbox.get("west", -180)

            cells = self._sessions_cells.setdefault(session_id, {})
            lat = south
            while lat <= north:
                lng = west
                while lng <= east:
                    key = _cell_key(lat, lng, cell_size)
                    cellset = cells.setdefault(key, set())
                    cellset.add(token)
                    lng += cell_size
                lat += cell_size

    async def unsubscribe(self, session_id: str, token: str) -> None:
        async with self._lock:
            toks = self._sessions_tokens.get(session_id, {})
            toks.pop(token, None)
            try:
                increment_viewport_unsubscriptions()
            except Exception:
                pass
            if not toks:
                self._sessions_tokens.pop(session_id, None)

            cells = self._sessions_cells.get(session_id, {})
            to_delete = []
            for key, tokenset in cells.items():
                tokenset.discard(token)
                if not tokenset:
                    to_delete.append(key)
            for key in to_delete:
                cells.pop(key, None)
            if not cells:
                self._sessions_cells.pop(session_id, None)

    async def subscribers_for_point(self, session_id: str, lat: float, lng: float, zoom_hint: int | None = None) -> List[WebSocket]:
        async with self._lock:
            cells = self._sessions_cells.get(session_id, {})
            if not cells:
                return []
            # Choose cell size from hint or default
            cell_size = _cell_size_for_zoom(zoom_hint or 12)
            key = _cell_key(lat, lng, cell_size)
            tokens = cells.get(key, set())
            sockets: List[WebSocket] = []
            tokens_meta = self._sessions_tokens.get(session_id, {})
            for t in tokens:
                meta = tokens_meta.get(t)
                if meta is None:
                    continue
                sockets.append(meta["websocket"])
            return sockets
