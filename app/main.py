import os

import httpx
from fastapi import FastAPI, HTTPException, status
from prometheus_fastapi_instrumentator import Instrumentator
from pydantic import BaseModel, Field

app = FastAPI(
    title="LLM API Wrapper",
    description="FastAPI service wrapper around internal Ollama model server",
    version="1.0.0"
)

# Initialize Prometheus instrumentator
Instrumentator().instrument(app).expose(app)

# Fetch internal Ollama URL from environment variable; default to localhost for local testing
OLLAMA_HOST = os.getenv("OLLAMA_HOST", "http://localhost:11434")
MODEL_NAME = os.getenv("MODEL_NAME", "qwen2.5:0.5b")


class GenerateRequest(BaseModel):
    prompt: str = Field(..., description="Prompt text sent to the model")
    model: str | None = Field(default=None, description="Optional model override")
    stream: bool = Field(default=False, description="Whether to stream the response")


class GenerateResponse(BaseModel):
    model: str
    response: str
    done: bool


@app.get("/health", status_code=status.HTTP_200_OK)
async def health_check():
    """Liveness/Readiness probe endpoint for Kubernetes."""
    return {"status": "ok", "ollama_host": OLLAMA_HOST}


@app.post("/generate", response_model=GenerateResponse)
async def generate(payload: GenerateRequest):
    """Proxies inference requests to the internal Ollama engine."""
    target_model = payload.model if payload.model else MODEL_NAME

    ollama_url = f"{OLLAMA_HOST}/api/generate"
    req_body = {
        "model": target_model,
        "prompt": payload.prompt,
        "stream": payload.stream
    }

    async with httpx.AsyncClient(timeout=60.0) as client:
        try:
            resp = await client.post(ollama_url, json=req_body)
            resp.raise_for_status()
            data = resp.json()
            return GenerateResponse(
                model=data.get("model", target_model),
                response=data.get("response", ""),
                done=data.get("done", True)
            )
        except httpx.ConnectError:
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail=f"Unable to connect to Ollama service at {OLLAMA_HOST}"
            )
        except httpx.HTTPStatusError as e:
            raise HTTPException(
                status_code=e.response.status_code,
                detail=f"Ollama returned error: {e.response.text}",
            )
