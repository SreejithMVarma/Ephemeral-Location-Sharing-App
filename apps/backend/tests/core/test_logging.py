from src.core.logging import sanitize_log_message


def test_log_sanitizer_redacts_coordinates_and_tokens() -> None:
    raw = "lat=37.7749 lng=-122.4194 token=abc123 passkey=QWERTY12"

    sanitized = sanitize_log_message(raw)

    assert "37.7749" not in sanitized
    assert "-122.4194" not in sanitized
    assert "abc123" not in sanitized
    assert "QWERTY12" not in sanitized
    assert sanitized.count("[REDACTED]") >= 4
