import pytest

from src.services.viewport_service import ViewportService


@pytest.mark.asyncio
async def test_subscribe_and_query_point():
    svc = ViewportService()
    session = 'sess1'
    token = 'user_1'
    # Dummy websocket-like object
    ws = object()
    bbox = {'north': 10.0, 'south': 0.0, 'east': 10.0, 'west': 0.0}
    zoom = 12

    await svc.subscribe(session, token, ws, bbox, zoom)

    subs = await svc.subscribers_for_point(session, 5.0, 5.0, zoom_hint=zoom)
    assert ws in subs

    # Point outside bbox should not be returned
    subs2 = await svc.subscribers_for_point(session, 50.0, 50.0, zoom_hint=zoom)
    assert ws not in subs2

    await svc.unsubscribe(session, token)
    subs3 = await svc.subscribers_for_point(session, 5.0, 5.0, zoom_hint=zoom)
    assert ws not in subs3
