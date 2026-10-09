"""Rotas da plataforma, incluindo a página inicial e o healthcheck (RNF-09)."""

from fastapi import APIRouter

router = APIRouter(tags=["plat"])


@router.get("/amazon")
async def home() -> dict[str, str]:
    """Retorna uma mensagem inicial para a API."""
    return {"message": "Bem-vindo à API App Finanças"}


@router.get("/health")
async def health() -> dict[str, str]:
    """Responde 200 se o processo da API está de pé. Não exige autenticação."""
    return {"status": "ok"}
