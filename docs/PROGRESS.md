# Progresso

## S00 — Monorepo, Docker Compose e CI (partes 1 e 3 de 4) (2026-10-06)
- Status: parcial
- Requisitos atendidos: parte de RNF-14 / D05 (estrutura do monorepo e backend mínimo); RNF-09 (`/health`)
- Decisões: app em `create_app()`; health em `app/modules/plat/router.py`; dependências mínimas por ora
- CI (parte 3): `.github/workflows/backend-ci.yml` roda ruff, ruff format, mypy e pytest com cobertura mínima de 80%. service container Postgres 15 já no CI (ainda sem testes que o usem; `DATABASE_URL` pronta para a S01); Redis entra quando for usado
- Problemas encontrados (não corrigidos): —
- Pendências para próximas sessões: Docker Compose (parte 2), `flutter create` (parte 4); CI rodar de fato no GitHub (depende do push)
