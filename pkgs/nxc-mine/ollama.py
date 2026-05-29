"""Ollama HTTP client — embeddings + JSON-mode chat.

Single connection-per-call (Ollama is local, latency dominated by model
inference, not socket setup). All non-200 responses raise.
"""

from __future__ import annotations

import json
from typing import Any

import httpx

from config import llm_cfg


def embed(text: str | list[str], model: str | None = None) -> list[list[float]]:
    """Return one embedding per input.

    Uses the legacy `/api/embeddings` (single-text) endpoint and loops. The
    newer `/api/embed` (batched) is flaky across Ollama versions — it 404s on
    older builds and 400s intermittently with batched inputs on some newer
    ones. The legacy path is ubiquitous; with bge-m3's 8192-token context we
    don't need to truncate inputs.
    """
    cfg = llm_cfg()
    inputs = [text] if isinstance(text, str) else list(text)
    model = model or cfg["embed_model"]
    vectors: list[list[float]] = []
    with httpx.Client(timeout=cfg["request_timeout"]) as client:
        for t in inputs:
            r = client.post(
                f"{cfg['host']}/api/embeddings",
                json={"model": model, "prompt": t},
            )
            r.raise_for_status()
            vectors.append(r.json()["embedding"])
    return vectors


def chat_json(
    *,
    system: str,
    user: str,
    schema: dict[str, Any] | None = None,
    model: str | None = None,
    temperature: float | None = None,
) -> dict[str, Any]:
    """Call /api/chat with format=json (or a schema) and return parsed JSON.

    Ollama's `format` accepts the string "json" (looser) or a full JSON schema
    object (strict). When `schema` is provided we use the schema for tighter
    guarantees on field presence/types.
    """
    cfg = llm_cfg()
    model = model or cfg["extract_model"]
    temperature = cfg["temperature_extract"] if temperature is None else temperature
    body: dict[str, Any] = {
        "model": model,
        "stream": False,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": user},
        ],
        "options": {"temperature": temperature},
        "format": schema if schema is not None else "json",
    }
    with httpx.Client(timeout=cfg["request_timeout"]) as client:
        r = client.post(f"{cfg['host']}/api/chat", json=body)
        r.raise_for_status()
        envelope = r.json()
    content = envelope.get("message", {}).get("content", "")
    if not content:
        raise RuntimeError(f"empty model response (envelope={envelope!r})")
    try:
        return json.loads(content)
    except json.JSONDecodeError as e:
        # JSON-mode should make this rare; surface the raw output for debugging.
        raise RuntimeError(
            f"model returned invalid JSON despite format constraint: {e}\n"
            f"--- raw content ---\n{content}\n--- end ---"
        ) from e
