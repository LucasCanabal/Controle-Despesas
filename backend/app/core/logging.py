import json
import logging
import re
from datetime import UTC, datetime
from typing import Any

SENSITIVE_FIELD_PATTERN = re.compile(
    r"""(?i)(["']?(?:authorization|password|passwd|(?:access|refresh|api)?[_-]?token|api[_-]?key|api[_-]?secret|secret)["']?\s*[:=]\s*["']?)([^"'\s,;}]+)"""
)
BEARER_TOKEN_PATTERN = re.compile(r"(?i)\bBearer\s+[A-Za-z0-9._~+/=-]+")
URL_PASSWORD_PATTERN = re.compile(r"(?i)(://(?:[^:/@\s]+)?:)([^@\s/]+)(@)")
REDACTED = "[REDACTED]"


def redact_sensitive_text(value: str) -> str:
    value = URL_PASSWORD_PATTERN.sub(rf"\1{REDACTED}\3", value)
    value = BEARER_TOKEN_PATTERN.sub(f"Bearer {REDACTED}", value)
    return SENSITIVE_FIELD_PATTERN.sub(rf"\1{REDACTED}", value)


class SensitiveDataFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.msg = redact_sensitive_text(record.getMessage())
        record.args = ()
        return True


class JsonLogFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(UTC).isoformat(),
            "level": record.levelname,
            "logger": record.name,
            "message": redact_sensitive_text(record.getMessage()),
            "request_id": getattr(record, "request_id", None),
        }
        if payload["request_id"] is None:
            from app.core.middleware import request_id_context

            payload["request_id"] = request_id_context.get()
        for field in ("method", "path", "status_code"):
            if hasattr(record, field):
                payload[field] = getattr(record, field)
        if record.exc_info:
            payload["exception"] = redact_sensitive_text(self.formatException(record.exc_info))
        return json.dumps(payload, ensure_ascii=False)


def configure_logging() -> None:
    logger = logging.getLogger("app")
    logger.setLevel(logging.INFO)
    logger.propagate = False

    if not any(getattr(handler, "_app_json_handler", False) for handler in logger.handlers):
        json_handler = logging.StreamHandler()
        json_handler.setFormatter(JsonLogFormatter())
        json_handler._app_json_handler = True  # type: ignore[attr-defined]
        logger.addHandler(json_handler)

    for handler in logger.handlers:
        if not any(isinstance(item, SensitiveDataFilter) for item in handler.filters):
            handler.addFilter(SensitiveDataFilter())
