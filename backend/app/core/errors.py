import logging
from collections.abc import Mapping
from typing import Any
from uuid import uuid4

from fastapi import FastAPI, Request
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse
from starlette.exceptions import HTTPException as StarletteHTTPException

from app.core.logging import redact_sensitive_text

logger = logging.getLogger("app.errors")

HTTP_ERROR_CODES = {
    400: "BAD_REQUEST",
    401: "UNAUTHORIZED",
    403: "FORBIDDEN",
    404: "NOT_FOUND",
    409: "BOT_INVALID_STATE",
    422: "VALIDATION_ERROR",
    429: "RATE_LIMITED",
    500: "INTERNAL_ERROR",
    502: "EXCHANGE_UNAVAILABLE",
    503: "EXCHANGE_UNAVAILABLE",
}
HTTP_ERROR_MESSAGES = {
    400: "Solicitação inválida.",
    401: "Não autorizado.",
    403: "Acesso negado.",
    404: "Recurso não encontrado.",
    409: "Conflito de estado.",
    422: "Dados inválidos.",
    429: "Muitas solicitações.",
    500: "Erro interno do servidor.",
    502: "Serviço externo indisponível.",
    503: "Serviço temporariamente indisponível.",
}


def normalize_error_details(value: Any) -> list[dict[str, str]]:
    if not isinstance(value, list):
        return []
    return [
        {
            "field": redact_sensitive_text(str(item["field"])),
            "issue": redact_sensitive_text(str(item["issue"])),
        }
        for item in value
        if isinstance(item, dict) and "field" in item and "issue" in item
    ]


def error_response(
    request: Request,
    *,
    status_code: int,
    code: str,
    message: str,
    details: list[dict[str, str]],
    headers: Mapping[str, str] | None = None,
) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    if request_id is None:
        from app.core.middleware import request_id_context

        request_id = request_id_context.get()
    if request_id is None:
        request_id = uuid4().hex

    response_headers = dict(headers or {})
    response_headers["X-Request-ID"] = request_id
    return JSONResponse(
        status_code=status_code,
        headers=response_headers,
        content={
            "error": {
                "code": code,
                "message": redact_sensitive_text(message),
                "details": details,
                "request_id": request_id,
            }
        },
    )


async def http_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    if not isinstance(exc, StarletteHTTPException):
        raise TypeError("HTTP exception handler received an unsupported exception")
    detail: Any = exc.detail
    status_code = exc.status_code
    default_code = HTTP_ERROR_CODES.get(status_code, "BAD_REQUEST")
    default_message = HTTP_ERROR_MESSAGES.get(status_code, "Solicitação inválida.")

    if isinstance(detail, dict):
        code = str(detail.get("code", default_code))
        message = str(detail.get("message", default_message))
        raw_details = detail.get("details", [])
        details = normalize_error_details(raw_details)
    else:
        code = default_code
        message = str(detail) if status_code < 500 and detail else default_message
        details = []

    if status_code >= 500:
        code = (
            "INTERNAL_ERROR"
            if status_code == 500
            else HTTP_ERROR_CODES.get(status_code, "INTERNAL_ERROR")
        )
        message = HTTP_ERROR_MESSAGES.get(status_code, "Erro interno do servidor.")
        details = []

    return error_response(
        request,
        status_code=status_code,
        code=code,
        message=message,
        details=details,
        headers=exc.headers,
    )


async def validation_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    if not isinstance(exc, RequestValidationError):
        raise TypeError("Validation exception handler received an unsupported exception")
    details = [
        {
            "field": redact_sensitive_text(".".join(str(part) for part in error["loc"])),
            "issue": redact_sensitive_text(str(error["msg"])),
        }
        for error in exc.errors()
    ]
    return error_response(
        request,
        status_code=422,
        code="VALIDATION_ERROR",
        message="Dados inválidos.",
        details=details,
    )


async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    request_id = getattr(request.state, "request_id", None)
    logger.error(
        "Unhandled application exception",
        exc_info=(type(exc), exc, exc.__traceback__),
        extra={"request_id": request_id},
    )
    return error_response(
        request,
        status_code=500,
        code="INTERNAL_ERROR",
        message="Erro interno do servidor.",
        details=[],
    )


def register_exception_handlers(application: FastAPI) -> None:
    application.add_exception_handler(StarletteHTTPException, http_exception_handler)
    application.add_exception_handler(RequestValidationError, validation_exception_handler)
    application.add_exception_handler(Exception, unhandled_exception_handler)
