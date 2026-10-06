"""Ponto de entrada da API.

Rodar localmente (a partir da pasta backend/):
    uvicorn app.main:app --reload
"""

from fastapi import FastAPI

from app.modules.plat.router import router as plat_router

API_PREFIX = "/api/v1"


def create_app() -> FastAPI:
    """Monta a aplicação. Uma função facilita criar instâncias isoladas nos testes."""
    application = FastAPI(title="App Finanças API", version="0.1.0")
    application.include_router(plat_router, prefix=API_PREFIX)
    return application


app = create_app()
