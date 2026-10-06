"""Rotas da plataforma. Por enquanto, apenas o healthcheck (RNF-09)."""

from fastapi import APIRouter

router = APIRouter(tags=["plat"])


@router.get("/health")
async def health() -> dict[str, str]:
    """Responde 200 se o processo da API está de pé. Não exige autenticação."""
    return {"status": "ok"}
