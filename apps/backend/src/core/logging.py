import contextvars
import json
import logging
import re
from datetime import UTC, datetime

from src.core.config import settings

_request_id_var = contextvars.ContextVar("request_id", default="-")
_session_id_var = contextvars.ContextVar("session_id", default="-")

# Redact location and token-like values from logs before external shipping.
_SENSITIVE_VALUE_PATTERNS = [
    re.compile(r"\b(lat|lng|latitude|longitude)\b\s*[:=]\s*[-+]?\d+(\.\d+)?", re.IGNORECASE),
    re.compile(r"\b(passkey|token|authorization|fcm_token)\b\s*[:=]\s*[^\s,}]+", re.IGNORECASE),
]


def set_log_context(request_id: str, session_id: str = "-") -> None:
    _request_id_var.set(request_id)
    _session_id_var.set(session_id)


def clear_log_context() -> None:
    _request_id_var.set("-")
    _session_id_var.set("-")


def sanitize_log_message(raw: str) -> str:
    sanitized = raw
    for pattern in _SENSITIVE_VALUE_PATTERNS:
        sanitized = pattern.sub("[REDACTED]", sanitized)
    return sanitized


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "service": "backend",
            "logger": record.name,
            "request_id": _request_id_var.get(),
            "session_id": _session_id_var.get(),
            "message": sanitize_log_message(record.getMessage()),
        }
        return json.dumps(payload, ensure_ascii=True)


def configure_logging() -> None:
    root = logging.getLogger()
    root.handlers.clear()

    handler = logging.StreamHandler()
    handler.setFormatter(JsonLogFormatter())
    root.addHandler(handler)

    env_level = {
        "development": logging.DEBUG,
        "staging": logging.INFO,
        "production": logging.WARNING,
    }.get(settings.app_env, logging.INFO)
    root.setLevel(env_level)
