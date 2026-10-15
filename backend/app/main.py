"""Ponto de entrada da API.

Rodar localmente (a partir da pasta backend/):
    uvicorn app.main:app --reload
"""

from collections.abc import AsyncIterator
from contextlib import asynccontextmanager

from fastapi import FastAPI

from app.core.config import Settings, load_settings
from app.core.database import create_engine, create_session_factory
from app.core.errors import register_exception_handlers
from app.core.logging import configure_logging
from app.core.middleware import RequestIdMiddleware
from app.modules.plat.router import router as plat_router

API_PREFIX = "/api/v1"


def create_app(settings: Settings | None = None) -> FastAPI:
    """Monta a aplicação. Uma função facilita criar instâncias isoladas nos testes."""
    resolved_settings = settings or load_settings()
    engine = create_engine(resolved_settings)

    @asynccontextmanager
    async def lifespan(_: FastAPI) -> AsyncIterator[None]:
        yield
        await engine.dispose()

    configure_logging()
    application = FastAPI(title="App Finanças API", version="0.1.0", lifespan=lifespan)
    application.state.engine = engine
    application.state.session_factory = create_session_factory(engine)
    application.include_router(plat_router, prefix=API_PREFIX)
    register_exception_handlers(application)
    application.add_middleware(RequestIdMiddleware)
    return application


app = create_app()
