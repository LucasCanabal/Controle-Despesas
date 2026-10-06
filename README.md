# App Finanças

App de planejamento financeiro (backend em Python/FastAPI). Monorepo: `/backend`, `/mobile` (futuro), `/docs`.

## Rodar o backend (Windows PowerShell)

```powershell
cd backend
py -m venv .venv
.venv\Scripts\Activate.ps1
pip install -e ".[dev]"
pytest
uvicorn app.main:app --reload
```

Depois abra http://127.0.0.1:8000/api/v1/health — deve mostrar `{"status":"ok"}`.

Se o `Activate.ps1` for bloqueado, rode antes (vale só para esta janela):
`Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`

## Checagens de qualidade

```powershell
ruff check .
ruff format --check .
mypy app tests
pytest
```
