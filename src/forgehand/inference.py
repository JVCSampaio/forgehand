from __future__ import annotations

import hashlib
import json
import os
import time
from typing import Any, Protocol
from urllib.parse import urlparse

import httpx

from forgehand.config import ForgehandConfig
from forgehand.models import (
    ForgehandDecision,
    InferenceResult,
    StepUsage,
)

FORGEHAND_SKILL = """You are the single implementation worker inside Forgehand.
You receive no conversational history. Treat CURRENT_STATE and RUNTIME_FACTS as the
only authoritative memory. RUNTIME_FACTS overrides model beliefs. Choose exactly one
bounded action. Never invent a command: run_command accepts only an approved command_id.
For requires_changes=true contracts, follow workflow_phase: inspect_then_edit permits
reads/searches, one optional baseline validation, or a scoped edit, while
validate_or_complete permits repair or completion. The runtime validates automatically
after each edit; do not request validation repeatedly.
Only choose an action listed in RUNTIME_FACTS.allowed_action_types.
Never claim that an action or test succeeded before its observation proves it.
REQUIRED_COMMAND_GATE.enforced describes the runtime capability. An empty
required_command_ids list means only that the current task has no required commands;
it does not mean the success gate is absent.
Before choosing any repository tool, decide whether the latest observation already
proves the task contract. If it does, the action MUST be complete. Complete is a
terminal action, not a claim made outside the schema.
Do not repeat a successful read_file or inspect_diff when no write or command has
changed the repository since that observation. After the requested edit is verified
and every available acceptance check is satisfied, choose complete immediately.
STATE_REVISION is runtime-owned metadata: do not return it. Artifact references are
summaries, not readable repository paths. All action paths are repository-relative;
use "." to list or search across the declared scope. JSON string escapes follow JSON:
"\n" represents a newline; do not double-escape it.

State operations are limited to:
- set on /phase, /current_goal, or /next_intent
- append_unique or remove_value on /decisions or /blockers
- upsert_hypothesis on /hypotheses with {id, claim, status}
- remove_hypothesis on /hypotheses with id

Actions and required arguments:
- complete: {status, summary, uncertainties?, acceptance_notes?}

Efficiency rules:
- Never repeat the same approved command while the repository is unchanged.
- If an action is rejected, choose a different corrective action or complete with
  needs_review; do not retry the identical payload.
- For implementation contracts with requires_changes=true, success requires a
  real scoped diff plus every required command passing on that exact tree.
- list_files: {path, limit?}
- read_file: {path, max_chars?, offset_chars?}
- read_files: {paths, max_chars_each?} (batch up to 8 files within one observation budget)
- search_text: {path, query, limit?}
- replace_text: {path, old_text, new_text, expected_replacements?}
- write_file: {path, content} (replace the complete file, or create it)
- create_file: {path, content}
- run_command: {command_id}
- inspect_diff: {max_chars?}

Return only the JSON object required by the response schema. Keep state concise. Put
code and logs in actions or artifacts, never in state."""


def extract_json(text: str) -> Any:
    stripped = text.strip()
    try:
        return json.loads(stripped)
    except json.JSONDecodeError:
        pass
    start = stripped.find("{")
    end = stripped.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("worker response contains no JSON object")
    try:
        return json.loads(stripped[start : end + 1])
    except json.JSONDecodeError as exc:
        raise ValueError("worker response contains invalid JSON") from exc


class InferenceAdapter(Protocol):
    def decide(self, context: dict[str, Any]) -> InferenceResult: ...


class InferenceResponseError(ValueError):
    """A billed worker response that could not become a valid decision."""

    def __init__(
        self,
        message: str,
        *,
        usage: StepUsage,
        response_hash: str,
    ) -> None:
        super().__init__(message)
        self.usage = usage
        self.response_hash = response_hash


class OpenAICompatibleInference:
    """One stateless structured inference against the configured worker endpoint."""

    def __init__(self, config: ForgehandConfig):
        self.config = config
        self._schema_supported: bool | None = None

    def _headers(self) -> dict[str, str]:
        key = os.getenv(self.config.worker.api_key_env)
        parsed = urlparse(self.config.worker.base_url)
        host = (parsed.hostname or "").lower()
        loopback = host in {"127.0.0.1", "localhost", "::1"}
        if not loopback and parsed.scheme != "https":
            raise RuntimeError("remote worker endpoints must use HTTPS")
        if key:
            return {"Authorization": f"Bearer {key}"}
        if not loopback:
            raise RuntimeError(
                "required runtime environment variable is missing: "
                f"{self.config.worker.api_key_env}"
            )
        return {}

    def _payload(self, context: dict[str, Any], *, schema: bool) -> dict[str, Any]:
        payload: dict[str, Any] = {
            "model": self.config.worker.model,
            "messages": [
                {"role": "system", "content": FORGEHAND_SKILL},
                {
                    "role": "user",
                    "content": json.dumps(context, ensure_ascii=False, separators=(",", ":")),
                },
            ],
            "temperature": self.config.forgehand.temperature,
            "top_p": self.config.forgehand.top_p,
            "stream": False,
            "max_tokens": self.config.forgehand.max_output_tokens,
            "reasoning_effort": self.config.forgehand.reasoning_effort,
        }
        if self.config.forgehand.seed is not None:
            payload["seed"] = self.config.forgehand.seed
        if schema:
            payload["response_format"] = {
                "type": "json_schema",
                "json_schema": {
                    "name": "forgehand_decision_v1",
                    "strict": True,
                    "schema": ForgehandDecision.model_json_schema(),
                },
            }
        else:
            payload["response_format"] = {"type": "json_object"}
        return payload

    @staticmethod
    def _content(response: dict[str, Any]) -> str:
        choices = response.get("choices") or []
        if not choices:
            raise ValueError("worker response contains no choices")
        message = choices[0].get("message", {})
        content = message.get("content")
        if isinstance(content, str) and content.strip():
            return content
        if isinstance(content, list):
            text = "".join(str(item.get("text", "")) for item in content if isinstance(item, dict))
            if text.strip():
                return text
        reasoning = message.get("reasoning_content")
        if isinstance(reasoning, str) and reasoning.strip():
            # Some local reasoning templates place the schema-constrained JSON in
            # reasoning_content. Accept it only when it is already valid JSON; never
            # persist or expose free-form reasoning traces.
            try:
                return json.dumps(extract_json(reasoning), separators=(",", ":"))
            except ValueError:
                pass
        finish_reason = choices[0].get("finish_reason") or "unknown"
        raise ValueError(
            "worker response contains no structured content "
            f"(finish_reason={finish_reason}, reasoning_chars="
            f"{len(reasoning) if isinstance(reasoning, str) else 0})"
        )

    def decide(self, context: dict[str, Any]) -> InferenceResult:
        endpoint = f"{self.config.worker.base_url.rstrip('/')}/chat/completions"
        schema = self._schema_supported is not False
        started = time.monotonic()
        with httpx.Client(timeout=self.config.forgehand.inference_timeout_seconds) as client:
            response = client.post(
                endpoint,
                headers=self._headers(),
                json=self._payload(context, schema=schema),
            )
            if schema and response.status_code in {400, 404, 422}:
                self._schema_supported = False
                response = client.post(
                    endpoint,
                    headers=self._headers(),
                    json=self._payload(context, schema=False),
                )
            response.raise_for_status()
        self._schema_supported = (
            schema if self._schema_supported is None else self._schema_supported
        )
        payload = response.json()
        usage = payload.get("usage") or {}
        prompt_tokens = int(usage.get("prompt_tokens") or 0)
        completion_tokens = int(usage.get("completion_tokens") or 0)
        step_usage = StepUsage(
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=int(usage.get("total_tokens") or prompt_tokens + completion_tokens),
            latency_seconds=round(time.monotonic() - started, 3),
            model=str(payload.get("model") or self.config.worker.model),
        )
        response_hash = hashlib.sha256(
            json.dumps(
                payload,
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode("utf-8")
        ).hexdigest()
        try:
            content = self._content(payload)
            parsed = extract_json(content)
            decision = ForgehandDecision.model_validate(parsed)
        except Exception as exc:
            raise InferenceResponseError(
                f"{type(exc).__name__}: {exc}",
                usage=step_usage,
                response_hash=response_hash,
            ) from exc
        return InferenceResult(
            decision=decision,
            usage=step_usage,
            response_hash=response_hash,
        )
