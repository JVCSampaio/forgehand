from __future__ import annotations

import json
import time
from pathlib import Path
from typing import Any

from forgehand.config import ForgehandConfig
from forgehand.executor import ForgehandExecutor
from forgehand.inference import (
    InferenceAdapter,
    InferenceResponseError,
    OpenAICompatibleInference,
)
from forgehand.models import (
    AgentState,
    ArtifactRef,
    TaskRequest,
    apply_state_operations,
)
from forgehand.store import ForgehandStore


class ForgehandRuntime:
    """Own the stateless worker loop: project context, reduce state, execute, repeat."""

    def __init__(
        self,
        config: ForgehandConfig,
        inference: InferenceAdapter | None = None,
    ):
        self.config = config
        self.inference = inference or OpenAICompatibleInference(config)

    @staticmethod
    def _bounded(text: str, maximum: int) -> str:
        if len(text) <= maximum:
            return text
        head = maximum * 2 // 3
        return text[:head] + "\n... observation truncated ...\n" + text[-(maximum - head) :]

    def _context(
        self,
        *,
        request: TaskRequest,
        source_revision: str,
        revision: int,
        state: AgentState,
        runtime_facts: dict[str, Any],
        observation: str,
    ) -> dict[str, Any]:
        state_payload = state.model_dump(mode="json")
        state_payload["artifact_refs"] = [
            {
                "id": artifact["id"],
                "kind": artifact["kind"],
                "summary": artifact["summary"],
            }
            for artifact in state_payload["artifact_refs"]
        ]
        context = {
            "protocol": "forgehand_step_v1",
            "task_contract": {
                "objective": request.objective,
                "scope": request.scope,
                "constraints": request.constraints,
                "acceptance_criteria": request.acceptance_criteria,
                "approved_commands": [
                    {
                        "command_id": command.command_id,
                        "argv": command.argv,
                        "cwd": command.cwd,
                    }
                    for command in request.commands
                ],
                "required_command_ids": request.required_command_ids,
                "requires_changes": request.requires_changes,
                "command_security": {
                    "shell": False,
                    "os_level_sandbox": False,
                    "host_network_inherited": True,
                    "host_os_permissions_inherited": True,
                },
                "source_revision": source_revision,
            },
            "state_revision": revision,
            "current_state": state_payload,
            "runtime_facts": runtime_facts,
            "latest_observation": self._bounded(
                observation, self.config.forgehand.max_observation_chars
            ),
        }
        encoded = json.dumps(context, ensure_ascii=False, separators=(",", ":"))
        if len(encoded) > self.config.forgehand.max_context_chars:
            # The contract and state are authoritative; only the observation is
            # compressible here. Artifact retrieval can recover the full payload.
            over = len(encoded) - self.config.forgehand.max_context_chars
            current_observation = str(context["latest_observation"])
            keep = max(500, len(current_observation) - over - 100)
            context["latest_observation"] = self._bounded(current_observation, keep)
            encoded = json.dumps(context, ensure_ascii=False, separators=(",", ":"))
        if len(encoded) > self.config.forgehand.max_context_chars:
            raise ValueError(
                "Forgehand context budget is too small for the task contract and state"
            )
        return context

    @staticmethod
    def _initial_state(request: TaskRequest) -> AgentState:
        return AgentState(
            phase="exploring",
            current_goal=request.objective[:1000],
            next_intent=f"Inspect the declared scope: {', '.join(request.scope)[:800]}",
        )

    @staticmethod
    def _with_artifact(state: AgentState, artifact: ArtifactRef) -> AgentState:
        payload = state.model_dump(mode="json")
        refs = [item for item in payload["artifact_refs"] if item["id"] != artifact.id]
        refs.append(artifact.model_dump(mode="json"))
        payload["artifact_refs"] = refs[-20:]
        return AgentState.model_validate(payload)

    @staticmethod
    def _with_runtime_intent(state: AgentState, action_result: dict[str, Any]) -> AgentState:
        action_type = action_result["action_type"]
        if action_type == "read_file" and not action_result["result"].get("truncated"):
            intent = (
                "The latest file observation is complete and current. Do not read that file "
                "again unless the repository changes. Compare it with the task contract; "
                "complete now if satisfied, otherwise edit or run an approved check."
            )
        elif action_type == "read_files":
            intent = (
                "Use the current bounded batch observation. Do not reread complete files while "
                "the repository is unchanged. Read only truncated continuations if necessary, "
                "then complete or take the specific next action required by the contract."
            )
        elif action_type in {"replace_text", "write_file", "create_file"}:
            intent = (
                "The repository changed. Validate it once with a distinct read, diff, or "
                "approved command, then complete when the acceptance criteria are satisfied."
            )
        elif action_type == "run_command":
            intent = (
                "Use the latest approved command result. Complete if it proves the acceptance "
                "criteria; otherwise fix the observed failure without repeating the same check."
            )
        elif action_type == "inspect_diff":
            intent = (
                "The current diff has been inspected. Complete if it satisfies the task "
                "contract; otherwise make the specific remaining change."
            )
        else:
            return state
        return state.model_copy(update={"next_intent": intent})

    def run(
        self,
        request: TaskRequest,
        *,
        task_root: Path,
        checkout: Path,
        contract_path: Path,
        source_revision: str,
    ) -> dict[str, Any]:
        if not self.config.forgehand.enabled:
            raise PermissionError("Forgehand runtime is disabled")
        started = time.monotonic()
        root = task_root / "forgehand"
        store = ForgehandStore(root)
        revision, completed_step, state = store.initialize(self._initial_state(request))
        executor = ForgehandExecutor(
            self.config,
            request,
            checkout=checkout,
            task_root=task_root,
        )
        observation = (
            "Task initialized. Inspect the declared scope before editing. "
            f"The immutable contract is stored at {contract_path}."
        )
        if completed_step:
            latest = store.latest_event()
            artifact_path = (
                latest.get("payload", {}).get("artifact", {}).get("path") if latest else None
            )
            if artifact_path and Path(artifact_path).is_file():
                observation = "RESUMED_FROM_DURABLE_STATE: " + Path(artifact_path).read_text(
                    encoding="utf-8"
                )
            else:
                observation = (
                    f"RESUMED_FROM_DURABLE_STATE at step {completed_step}, "
                    f"revision {revision}. Reinspect runtime facts before acting."
                )
        invalid_attempts = 0
        action_rejections = 0
        no_progress_steps = 0
        maximum_steps = min(
            request.max_iterations,
            self.config.forgehand.max_steps,
            self.config.repo_tasks.max_steps,
        )

        for step in range(completed_step + 1, maximum_steps + 1):
            facts = executor.runtime_facts(step=step, source_revision=source_revision)
            context = self._context(
                request=request,
                source_revision=source_revision,
                revision=revision,
                state=state,
                runtime_facts=facts,
                observation=observation,
            )
            result = None
            validation_error: Exception | None = None
            for attempt in range(1, self.config.forgehand.invalid_output_retries + 2):
                try:
                    result = self.inference.decide(context)
                    store.record_usage(
                        step=step,
                        attempt=attempt,
                        usage=result.usage,
                        response_hash=result.response_hash,
                    )
                    candidate = apply_state_operations(
                        state,
                        result.decision.state_operations,
                        max_state_chars=self.config.forgehand.max_state_chars,
                    )
                    validation_error = None
                    break
                except Exception as exc:
                    if isinstance(exc, InferenceResponseError):
                        store.record_usage(
                            step=step,
                            attempt=attempt,
                            usage=exc.usage,
                            response_hash=exc.response_hash,
                        )
                    validation_error = exc
                    invalid_attempts += 1
                    store.record_event(
                        step=step,
                        revision=revision,
                        event_type="invalid_decision",
                        event={"attempt": attempt, "error": f"{type(exc).__name__}: {exc}"[:2000]},
                    )
                    context = dict(context)
                    context["validation_error"] = (
                        f"Your previous response was rejected: {type(exc).__name__}: {exc}"
                    )[:2000]
            if result is None or validation_error is not None:
                return self._blocked(
                    store,
                    started,
                    invalid_attempts,
                    f"structured worker decision failed: {validation_error}",
                    executor=executor,
                )

            try:
                before_tree = executor._repository_fingerprint()
                action_result = executor.execute(step, result.decision.action)
                candidate = self._with_artifact(candidate, action_result["artifact"])
                candidate = self._with_runtime_intent(candidate, action_result)

                # For implementation tasks, validation is a runtime concern:
                # execute declared required checks immediately after an edit so
                # the worker only receives a compact pass/fail observation.
                if (
                    result.decision.action.type in {"replace_text", "write_file", "create_file"}
                    and request.requires_changes
                    and request.required_command_ids
                ):
                    validations = []
                    for command_id in request.required_command_ids:
                        validation = executor.execute(
                            step,
                            type(result.decision.action)(
                                type="run_command",
                                arguments={"command_id": command_id},
                            ),
                            internal=True,
                        )
                        candidate = self._with_artifact(candidate, validation["artifact"])
                        validations.append(validation["result"])
                    action_result["observation"] = json.dumps(
                        {
                            "edit": json.loads(action_result["observation"]),
                            "automatic_validation": [
                                {
                                    "command_id": item["command_id"],
                                    "exit_code": item["exit_code"],
                                    "output": item["output"],
                                }
                                for item in validations
                            ],
                        },
                        ensure_ascii=False,
                        separators=(",", ":"),
                    )
                after_tree = executor._repository_fingerprint()
                if result.decision.action.type == "inspect_diff":
                    no_progress_steps += 1
                elif (
                    result.decision.action.type in {"replace_text", "write_file", "create_file"}
                    or before_tree != after_tree
                ):
                    no_progress_steps = 0
                if no_progress_steps >= self.config.forgehand.max_no_progress_steps:
                    return self._blocked(
                        store,
                        started,
                        invalid_attempts,
                        f"worker made no progress for {no_progress_steps} steps",
                        executor=executor,
                    )
            except Exception as exc:
                invalid_attempts += 1
                action_rejections += 1
                observation = f"ACTION_REJECTED: {type(exc).__name__}: {exc}"[
                    : self.config.forgehand.max_observation_chars
                ]
                store.record_event(
                    step=step,
                    revision=revision,
                    event_type="action_rejected",
                    event={
                        "action": result.decision.action.model_dump(mode="json"),
                        "error": observation,
                    },
                )
                if action_rejections >= self.config.forgehand.max_action_rejections:
                    return self._blocked(
                        store,
                        started,
                        invalid_attempts,
                        f"worker made {action_rejections} rejected actions without progress",
                        executor=executor,
                    )
                continue

            revision = store.commit(
                expected_revision=revision,
                step=step,
                state=candidate,
                event_type="action_executed",
                event={
                    "action": result.decision.action.model_dump(mode="json"),
                    "artifact": action_result["artifact"].model_dump(mode="json"),
                    "response_hash": result.response_hash,
                    "confidence": result.decision.confidence,
                },
            )
            state = candidate
            observation = action_result["observation"]

            if action_result["completed"]:
                completion = action_result["result"]
                metrics = store.metrics()
                metrics.update(
                    {
                        "invalid_attempts": invalid_attempts,
                        "wall_seconds": round(time.monotonic() - started, 3),
                        "state_database": str(store.database),
                        "state_export": str(store.export_path),
                    }
                )
                return {
                    "json": {
                        "status": completion["status"],
                        "summary": completion["summary"],
                        "changed_files": facts["changed_files"],
                        "commands_run": sorted(executor.command_results),
                        "command_results": executor.command_evidence(),
                        "required_command_gate": executor.required_command_gate(),
                        "confidence": result.decision.confidence,
                        "uncertainties": completion["uncertainties"],
                        "acceptance_notes": completion["acceptance_notes"],
                    },
                    "forgehand": metrics,
                    "model": self.config.worker.model,
                }

        return self._blocked(
            store,
            started,
            invalid_attempts,
            f"Forgehand reached the {maximum_steps}-step budget",
            executor=executor,
        )

    def _blocked(
        self,
        store: ForgehandStore,
        started: float,
        invalid_attempts: int,
        message: str,
        *,
        executor: ForgehandExecutor | None = None,
    ) -> dict[str, Any]:
        metrics = store.metrics()
        metrics.update(
            {
                "invalid_attempts": invalid_attempts,
                "wall_seconds": round(time.monotonic() - started, 3),
                "state_database": str(store.database),
                "state_export": str(store.export_path),
            }
        )
        return {
            "json": {
                "status": "blocked",
                "summary": message[:2000],
                "changed_files": [],
                "commands_run": sorted(executor.command_results) if executor else [],
                "command_results": executor.command_evidence() if executor else {},
                "required_command_gate": (
                    executor.required_command_gate()
                    if executor
                    else {
                        "enforced": True,
                        "required_command_ids": [],
                        "missing_command_ids": [],
                        "failed_command_ids": [],
                        "stale_command_ids": [],
                        "current_tree_hash": None,
                        "passed": True,
                    }
                ),
                "confidence": 0.0,
                "uncertainties": [message[:500]],
                "acceptance_notes": [],
            },
            "forgehand": metrics,
            "model": self.config.worker.model,
        }
