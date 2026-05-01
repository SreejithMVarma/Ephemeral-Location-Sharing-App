import pytest

from src.services.notifications import NotificationService, NotificationType


def test_build_payload_is_zero_data_contract() -> None:
    service = NotificationService()

    payload = service.build_payload(NotificationType.NEW_LOCATION_DATA, "session_123")

    assert payload == {"type": "NEW_LOCATION_DATA", "session_id": "session_123"}
    assert set(payload.keys()) == {"type", "session_id"}
    forbidden = {"lat", "lng", "name", "token"}
    assert forbidden.isdisjoint(payload.keys())


@pytest.mark.asyncio
async def test_send_multicast_returns_counts() -> None:
    service = NotificationService()

    result = await service.send_multicast(
        NotificationType.CHAT_MESSAGE,
        "session_456",
        ["token_a", "token_b"],
    )

    assert result == {"success": 2, "failure": 0}
