from __future__ import annotations

import json
from copy import deepcopy
from typing import Any, Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

Phase = Literal[
    "exploring",
    "implementing",
    "validating",
    "debugging",
    "completed",
    "blocked",
]


class Hypothesis(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(pattern=r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$")
    claim: str = Field(min_length=1, max_length=500)
    status: Literal["open", "testing", "confirmed", "rejected"] = "open"


class ArtifactRef(BaseModel):
    model_config = ConfigDict(extra="forbid")

    id: str = Field(min_length=1, max_length=120)
    kind: str = Field(min_length=1, max_length=80)
    path: str = Field(min_length=1, max_length=1000)
    summary: str = Field(min_length=1, max_length=500)


class AgentState(BaseModel):
    model_config = ConfigDict(extra="forbid")

    phase: Phase = "exploring"
    current_goal: str = Field(min_length=1, max_length=1000)
    hypotheses: list[Hypothesis] = Field(default_factory=list, max_length=16)
    decisions: list[str] = Field(default_factory=list, max_length=24)
    blockers: list[str] = Field(default_factory=list, max_length=12)
    artifact_refs: list[ArtifactRef] = Field(default_factory=list, max_length=20)
    next_intent: str = Field(min_length=1, max_length=1000)

    @field_validator("decisions", "blockers")
    @classmethod
    def bounded_strings(cls, values: list[str]) -> list[str]:
        if any(not value.strip() or len(value) > 500 for value in values):
            raise ValueError("state list entries must contain 1 to 500 characters")
        return list(dict.fromkeys(value.strip() for value in values))


class StateOperation(BaseModel):
    model_config = ConfigDict(extra="forbid")

    op: Literal[
        "set",
        "append_unique",
        "remove_value",
        "upsert_hypothesis",
        "remove_hypothesis",
    ]
    path: Literal[
        "/phase",
        "/current_goal",
        "/next_intent",
        "/decisions",
        "/blockers",
        "/hypotheses",
    ]
    value: Any = None
    id: str | None = Field(default=None, max_length=64)


class WorkerAction(BaseModel):
    model_config = ConfigDict(extra="forbid")

    type: Literal[
        "list_files",
        "read_file",
        "search_text",
        "replace_text",
        "write_file",
        "create_file",
        "run_command",
        "inspect_diff",
        "complete",
    ]
    arguments: dict[str, Any] = Field(default_factory=dict)


class ForgehandDecision(BaseModel):
    model_config = ConfigDict(extra="forbid")

    state_operations: list[StateOperation] = Field(default_factory=list, max_length=20)
    action: WorkerAction
    confidence: float = Field(ge=0, le=1)


class StepUsage(BaseModel):
    prompt_tokens: int = Field(default=0, ge=0)
    completion_tokens: int = Field(default=0, ge=0)
    total_tokens: int = Field(default=0, ge=0)
    latency_seconds: float = Field(default=0, ge=0)
    model: str


class InferenceResult(BaseModel):
    decision: ForgehandDecision
    usage: StepUsage
    response_hash: str


class RepoCommand(BaseModel):
    model_config = ConfigDict(extra="forbid")

    command_id: str = Field(pattern=r"^[a-zA-Z0-9][a-zA-Z0-9_.-]{0,63}$")
    argv: list[str] = Field(min_length=1, max_length=32)
    cwd: str = Field(default=".", min_length=1, max_length=500)
    timeout_seconds: int = Field(default=300, ge=1, le=1_200)

    @field_validator("argv")
    @classmethod
    def valid_argv(cls, values: list[str]) -> list[str]:
        if any(not value or "\x00" in value for value in values):
            raise ValueError("command argv entries must be non-empty")
        return values


class TaskRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    repository_root: str = Field(min_length=1, max_length=1_024)
    objective: str = Field(min_length=1, max_length=8_000)
    scope: list[str] = Field(min_length=1, max_length=100)
    constraints: list[str] = Field(default_factory=list, max_length=100)
    acceptance_criteria: list[str] = Field(min_length=1, max_length=100)
    commands: list[RepoCommand] = Field(default_factory=list, max_length=20)
    base_revision: str = Field(default="HEAD", min_length=1, max_length=200)
    max_iterations: int = Field(default=8, ge=1, le=100)
    keep_worktree: bool = True

    @field_validator("scope")
    @classmethod
    def valid_scope(cls, values: list[str]) -> list[str]:
        normalized: list[str] = []
        for value in values:
            candidate = value.strip().replace("\\", "/").strip("/")
            if not candidate or candidate == "." or ".." in candidate.split("/"):
                raise ValueError("scope entries must be repository-relative paths")
            normalized.append(candidate)
        return list(dict.fromkeys(normalized))

    @model_validator(mode="after")
    def unique_commands(self) -> TaskRequest:
        command_ids = [command.command_id for command in self.commands]
        if len(command_ids) != len(set(command_ids)):
            raise ValueError("command_id values must be unique")
        return self


SCALAR_PATHS = {
    "/phase": "phase",
    "/current_goal": "current_goal",
    "/next_intent": "next_intent",
}
LIST_PATHS = {"/decisions": "decisions", "/blockers": "blockers"}


def apply_state_operations(
    state: AgentState,
    operations: list[StateOperation],
    *,
    max_state_chars: int,
) -> AgentState:
    """Apply a deliberately small operation language and enforce the state budget."""
    candidate = deepcopy(state.model_dump(mode="json"))
    for operation in operations:
        if operation.op == "set":
            field = SCALAR_PATHS.get(operation.path)
            if field is None:
                raise ValueError(f"set is not allowed for {operation.path}")
            candidate[field] = operation.value
        elif operation.op in {"append_unique", "remove_value"}:
            field = LIST_PATHS.get(operation.path)
            if field is None or not isinstance(operation.value, str):
                raise ValueError(f"{operation.op} requires a string-list path and value")
            value = operation.value.strip()
            if not value or len(value) > 500:
                raise ValueError("state list operation value must contain 1 to 500 characters")
            if operation.op == "append_unique" and value not in candidate[field]:
                candidate[field].append(value)
            elif operation.op == "remove_value":
                candidate[field] = [item for item in candidate[field] if item != value]
        elif operation.op == "upsert_hypothesis":
            if operation.path != "/hypotheses" or not isinstance(operation.value, dict):
                raise ValueError("upsert_hypothesis requires /hypotheses and an object value")
            hypothesis = Hypothesis.model_validate(operation.value).model_dump(mode="json")
            existing = [item for item in candidate["hypotheses"] if item["id"] != hypothesis["id"]]
            existing.append(hypothesis)
            candidate["hypotheses"] = existing
        elif operation.op == "remove_hypothesis":
            if operation.path != "/hypotheses" or not operation.id:
                raise ValueError("remove_hypothesis requires /hypotheses and id")
            candidate["hypotheses"] = [
                item for item in candidate["hypotheses"] if item["id"] != operation.id
            ]
        else:  # pragma: no cover - guarded by the model
            raise ValueError(f"unsupported state operation: {operation.op}")

    validated = AgentState.model_validate(candidate)
    encoded = json.dumps(validated.model_dump(mode="json"), separators=(",", ":"))
    if len(encoded) > max_state_chars:
        raise ValueError(f"state budget exceeded: {len(encoded)} characters > {max_state_chars}")
    return validated
