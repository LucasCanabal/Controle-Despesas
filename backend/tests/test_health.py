from fastapi.testclient import TestClient

from app.main import create_app


def test_health_retorna_200_e_status_ok() -> None:
    client = TestClient(create_app())

    response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_health_nao_exige_autenticacao() -> None:
    client = TestClient(create_app())

    # Nenhum header Authorization enviado: deve responder 200 mesmo assim.
    response = client.get("/api/v1/health")

    assert "authorization" not in response.request.headers
    assert response.status_code == 200


def test_rota_inexistente_retorna_404() -> None:
    client = TestClient(create_app())

    assert client.get("/api/v1/nao-existe").status_code == 404
