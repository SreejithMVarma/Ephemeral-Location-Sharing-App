import re
from collections.abc import Mapping
from typing import Any

try:
    import sentry_sdk
except ImportError:  # pragma: no cover - optional dependency in local dev
    sentry_sdk = None

from src.core.config import settings

_COORD_TOKEN_PATTERN = re.compile(r"(lat|lng|latitude|longitude|token|passkey)", re.IGNORECASE)


def _redact_dict(data: Mapping[str, Any]) -> dict[str, Any]:
    redacted: dict[str, Any] = {}
    for key, value in data.items():
        if _COORD_TOKEN_PATTERN.search(str(key)):
            redacted[key] = "[REDACTED]"
        elif isinstance(value, Mapping):
            redacted[key] = _redact_dict(value)
        else:
            redacted[key] = value
    return redacted


def _before_send(event: dict[str, Any], _: dict[str, Any]) -> dict[str, Any]:
    request = event.get("request")
    if isinstance(request, dict):
        headers = request.get("headers")
        data = request.get("data")
        if isinstance(headers, Mapping):
            request["headers"] = _redact_dict(headers)
        if isinstance(data, Mapping):
            request["data"] = _redact_dict(data)
    return event


def configure_sentry() -> None:
    if not settings.sentry_dsn or sentry_sdk is None:
        return

    sentry_sdk.init(
        dsn=settings.sentry_dsn,
        traces_sample_rate=0.1 if settings.app_env != "production" else 0.02,
        send_default_pii=False,
        before_send=_before_send,
    )
