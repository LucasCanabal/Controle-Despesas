import json
import logging
from collections.abc import AsyncIterator
from io import StringIO
from typing import Annotated
from uuid import UUID

import pytest
import pytest_asyncio
from fastapi import APIRouter, Depends
from httpx import ASGITransport, AsyncClient
from pydantic import ValidationError
from sqlalchemy import String, select
from sqlalchemy.ext.asyncio import (
    AsyncConnection,
    AsyncSession,
    async_sessionmaker,
    create_async_engine,
)
from sqlalchemy.orm import Mapped, mapped_column

from app.core.config import Settings, load_settings
from app.core.database import get_db_session
from app.core.logging import JsonLogFormatter, SensitiveDataFilter, redact_sensitive_text
from app.core.models import Base, UUIDTimestampMixin
from app.main import create_app


class _TestRecord(UUIDTimestampMixin, Base):
    __tablename__ = "test_records"

    name: Mapped[str] = mapped_column(String(40), nullable=False)


@pytest_asyncio.fixture
async def database_connection() -> AsyncIterator[AsyncConnection]:
    engine = create_async_engine(load_settings().database_url)
    connection = await engine.connect()
    transaction = await connection.begin()
    await connection.run_sync(Base.metadata.create_all)
    try:
        yield connection
    finally:
        await transaction.rollback()
        await connection.close()
        await engine.dispose()


@pytest_asyncio.fixture
async def database_session(
    database_connection: AsyncConnection,
) -> AsyncIterator[AsyncSession]:
    factory = async_sessionmaker(
        bind=database_connection,
        expire_on_commit=False,
        join_transaction_mode="create_savepoint",
    )
    async with factory() as session:
        yield session


@pytest_asyncio.fixture
async def error_client(database_connection: AsyncConnection) -> AsyncIterator[AsyncClient]:
    application = create_app()
    router = APIRouter()
    factory = async_sessionmaker(
        bind=database_connection,
        expire_on_commit=False,
        join_transaction_mode="create_savepoint",
    )

    async def override_db_session() -> AsyncIterator[AsyncSession]:
        async with factory() as session:
            yield session

    @router.get("/test-validation")
    async def validation_endpoint(count: int) -> dict[str, int]:
        return {"count": count}

    @router.get("/test-failure")
    async def failure_endpoint() -> None:
        raise RuntimeError("password=never-return-this")

    @router.post("/test-db")
    async def database_endpoint(
        session: Annotated[AsyncSession, Depends(get_db_session)],
    ) -> dict[str, str]:
        record = _TestRecord(name="transaction")
        session.add(record)
        await session.commit()
        return {"id": str(record.id)}

    application.dependency_overrides[get_db_session] = override_db_session
    application.include_router(router, prefix="/api/v1")
    transport = ASGITransport(app=application, raise_app_exceptions=False)
    try:
        async with AsyncClient(transport=transport, base_url="http://test") as client:
            yield client
    finally:
        await application.state.engine.dispose()


def test_settings_rejeita_segredo_obrigatorio_ausente(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.delenv("APP_SECRET")

    with pytest.raises(ValidationError):
        load_settings()


def test_settings_rejeita_segredo_vazio(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("APP_SECRET", " ")
    monkeypatch.setenv("DATABASE_URL", "sqlite+aiosqlite:///:memory:")

    with pytest.raises(ValidationError, match="APP_SECRET must not be empty"):
        load_settings()


@pytest.mark.parametrize(
    ("database_url", "expected"),
    [
        ("postgres://app:pass@localhost/db", "postgresql+asyncpg://app:pass@localhost/db"),
        ("postgresql://app:pass@localhost/db", "postgresql+asyncpg://app:pass@localhost/db"),
        ("sqlite+aiosqlite:///:memory:", "sqlite+aiosqlite:///:memory:"),
    ],
)
def test_settings_normaliza_url_assincrona(database_url: str, expected: str) -> None:
    settings = Settings.model_validate(
        {"APP_SECRET": "test-only-secret", "DATABASE_URL": database_url}
    )

    assert settings.database_url == expected
    assert "test-only-secret" not in repr(settings)


@pytest.mark.asyncio
async def test_sessao_de_banco_persiste_na_transacao_de_teste(
    database_session: AsyncSession,
) -> None:
    record = _TestRecord(name="rollback")
    database_session.add(record)
    await database_session.commit()

    saved_record = await database_session.scalar(
        select(_TestRecord).where(_TestRecord.name == "rollback")
    )

    assert saved_record is not None
    assert isinstance(saved_record.id, UUID)
    assert saved_record.created_at is not None
    assert saved_record.updated_at is not None


@pytest.mark.asyncio
async def test_validation_error_usa_contrato_unico(error_client: AsyncClient) -> None:
    response = await error_client.get("/api/v1/test-validation?count=invalid")

    assert response.status_code == 422
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert response.json()["error"]["message"] == "Dados inválidos."
    assert response.json()["error"]["details"][0]["field"] == "query.count"
    assert response.json()["error"]["request_id"] == response.headers["x-request-id"]


@pytest.mark.asyncio
async def test_erro_interno_nao_expoe_detalhes(error_client: AsyncClient) -> None:
    app_logger = logging.getLogger("app")
    handler = next(
        item
        for item in app_logger.handlers
        if isinstance(item, logging.StreamHandler) and getattr(item, "_app_json_handler", False)
    )
    log_stream = StringIO()
    original_stream = handler.setStream(log_stream)
    try:
        response = await error_client.get("/api/v1/test-failure")
    finally:
        handler.setStream(original_stream)
    log_entries = [json.loads(line) for line in log_stream.getvalue().splitlines()]

    assert response.status_code == 500
    assert response.json()["error"] == {
        "code": "INTERNAL_ERROR",
        "message": "Erro interno do servidor.",
        "details": [],
        "request_id": response.headers["x-request-id"],
    }
    assert any(entry["request_id"] == response.headers["x-request-id"] for entry in log_entries)
    assert "never-return-this" not in log_stream.getvalue()


@pytest.mark.asyncio
async def test_sessao_de_requisicao_compartilha_transacao_de_teste(
    error_client: AsyncClient,
    database_session: AsyncSession,
) -> None:
    response = await error_client.post("/api/v1/test-db")

    assert response.status_code == 200
    assert UUID(response.json()["id"])
    records = await database_session.scalars(select(_TestRecord))
    assert len(list(records)) == 1


def test_filtro_e_formatter_mascaram_campos_sensiveis() -> None:
    original_message = (
        "Authorization: Bearer abc123 password=hunter2 "
        "api_secret=private accessToken=access-value "
        "postgresql://app:db-password@localhost/database"
    )
    record = logging.LogRecord(
        "app.test",
        logging.INFO,
        __file__,
        1,
        original_message,
        (),
        None,
    )
    data_filter = SensitiveDataFilter()

    assert data_filter.filter(record)
    formatted = JsonLogFormatter().format(record)

    assert "abc123" not in formatted
    assert "hunter2" not in formatted
    assert "private" not in formatted
    assert "access-value" not in formatted
    assert "db-password" not in formatted
    assert redact_sensitive_text('"token": "secret-value"') == '"token": "[REDACTED]"'


def test_formatter_mascara_segredo_em_traceback() -> None:
    try:
        raise RuntimeError("api_secret=private-value")
    except RuntimeError as exception:
        record = logging.LogRecord(
            "app.test",
            logging.ERROR,
            __file__,
            1,
            "Request failed",
            (),
            (type(exception), exception, exception.__traceback__),
        )

    formatted = JsonLogFormatter().format(record)

    assert "private-value" not in formatted
