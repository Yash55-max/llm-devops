from fastapi.testclient import TestClient

from main import GenerateRequest, app

client = TestClient(app)


def test_health_check():
    """Verify that the /health endpoint returns HTTP 200 and status ok."""
    response = client.get("/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert "ollama_host" in data


def test_generate_request_model_defaults():
    """Verify default values in the GenerateRequest Pydantic schema."""
    req = GenerateRequest(prompt="Hello world")
    assert req.prompt == "Hello world"
    assert req.model is None
    assert req.stream is False


def test_generate_request_model_custom():
    """Verify optional fields in the GenerateRequest Pydantic schema."""
    req = GenerateRequest(prompt="Explain K8s", model="llama3", stream=True)
    assert req.prompt == "Explain K8s"
    assert req.model == "llama3"
    assert req.stream is True


def test_generate_endpoint_invalid_payload():
    """Verify that missing required prompt field returns HTTP 422 Unprocessable Entity."""
    response = client.post("/generate", json={})
    assert response.status_code == 422