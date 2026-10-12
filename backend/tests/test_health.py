from fastapi.testclient import TestClient

from app.main import create_app


def test_home_retorna_mensagem_de_boas_vindas() -> None:
    with TestClient(create_app()) as client:
        response = client.get("/api/v1/")

    assert response.status_code == 200
    assert response.json() == {"message": "Bem-vindo à API App Finanças"}


def test_health_retorna_200_e_status_ok() -> None:
    with TestClient(create_app()) as client:
        response = client.get("/api/v1/health")

    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
    assert response.headers["x-request-id"]


def test_health_nao_exige_autenticacao() -> None:
    # Nenhum header Authorization enviado: deve responder 200 mesmo assim.
    with TestClient(create_app()) as client:
        response = client.get("/api/v1/health")

    assert "authorization" not in response.request.headers
    assert response.status_code == 200


def test_rota_inexistente_retorna_404() -> None:
    with TestClient(create_app()) as client:
        response = client.get("/api/v1/nao-existe")

    assert response.status_code == 404
    assert response.json()["error"]["code"] == "NOT_FOUND"
    assert response.json()["error"]["request_id"] == response.headers["x-request-id"]
