from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path
from typing import Any

import pytest

from forgehand.config import (
    ForgehandConfig,
    RepositorySettings,
    RuntimeSettings,
    WorkerSettings,
    load_config,
    write_config,
)
from forgehand.executor import ForgehandExecutor
from forgehand.inference import InferenceResponseError
from forgehand.models import (
    AgentState,
    ForgehandDecision,
    InferenceResult,
    RepoCommand,
    StateOperation,
    StepUsage,
    TaskRequest,
    WorkerAction,
    apply_state_operations,
)
from forgehand.runtime import ForgehandRuntime
from forgehand.store import ForgehandStore, StaleStateError
from forgehand.tasks import TaskRunner


def _git(repository: Path, *arguments: str) -> str:
    return subprocess.run(
        ["git", "-C", str(repository), *arguments],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    ).stdout


def _repository(tmp_path: Path) -> Path:
    repository = tmp_path / "repository"
    (repository / "src").mkdir(parents=True)
    (repository / "src" / "value.txt").write_text("before\n", encoding="utf-8")
    (repository / "README.md").write_text("outside\n", encoding="utf-8")
    _git(repository, "init")
    _git(repository, "config", "user.email", "tests@example.invalid")
    _git(repository, "config", "user.name", "Test Runner")
    _git(repository, "add", ".")
    _git(repository, "commit", "-m", "fixture")
    return repository.resolve()


def _config(tmp_path: Path, repository: Path) -> ForgehandConfig:
    return ForgehandConfig(
        project_root=tmp_path,
        worker=WorkerSettings(name="Fixture", model="fixture-worker"),
        repo_tasks=RepositorySettings(
            roots=[repository],
            worktree_root=tmp_path / "tasks",
            retain_worktrees=False,
        ),
        forgehand=RuntimeSettings(),
    )


def _decision(
    revision: int,
    action_type: str,
    arguments: dict[str, Any],
    *operations: StateOperation,
) -> InferenceResult:
    return InferenceResult(
        decision=ForgehandDecision(
            state_operations=list(operations),
            action=WorkerAction(type=action_type, arguments=arguments),
            confidence=0.95,
        ),
        usage=StepUsage(
            prompt_tokens=100,
            completion_tokens=20,
            total_tokens=120,
            model="fixture-worker",
        ),
        response_hash=f"hash-{revision}-{action_type}",
    )


class ScriptedInference:
    def __init__(self) -> None:
        self.contexts: list[dict[str, Any]] = []

    def decide(self, context: dict[str, Any]) -> InferenceResult:
        self.contexts.append(context)
        actions = [
            ("list_files", {"path": "src"}),
            ("read_file", {"path": "src/value.txt"}),
            (
                "replace_text",
                {
                    "path": "src/value.txt",
                    "old_text": "before",
                    "new_text": "after",
                    "expected_replacements": 1,
                },
            ),
            ("inspect_diff", {}),
            (
                "complete",
                {
                    "status": "success",
                    "summary": "Updated the scoped fixture.",
                    "acceptance_notes": ["The requested diff is present."],
                },
            ),
        ]
        action_type, arguments = actions[len(self.contexts) - 1]
        return _decision(
            int(context["state_revision"]),
            action_type,
            arguments,
            StateOperation(
                op="set",
                path="/next_intent",
                value=f"Continue with {action_type}",
            ),
        )


class InvalidThenScriptedInference(ScriptedInference):
    def __init__(self) -> None:
        super().__init__()
        self.failed = False

    def decide(self, context: dict[str, Any]) -> InferenceResult:
        if not self.failed:
            self.failed = True
            raise InferenceResponseError(
                "response contained no valid decision",
                usage=StepUsage(
                    prompt_tokens=90,
                    completion_tokens=30,
                    total_tokens=120,
                    model="fixture-worker",
                ),
                response_hash="invalid-response-hash",
            )
        return super().decide(context)


class FailedCommandThenCompleteInference:
    def __init__(self) -> None:
        self.calls = 0

    def decide(self, context: dict[str, Any]) -> InferenceResult:
        self.calls += 1
        if self.calls == 1:
            return _decision(
                int(context["state_revision"]),
                "run_command",
                {"command_id": "validate"},
            )
        return _decision(
            int(context["state_revision"]),
            "complete",
            {"status": "success", "summary": "Incorrectly claimed success."},
        )


def _request(repository: Path) -> TaskRequest:
    return TaskRequest(
        repository_root=str(repository),
        objective="Update the scoped fixture value.",
        scope=["src"],
        acceptance_criteria=["The value file contains the updated value."],
        max_iterations=5,
        keep_worktree=False,
    )


def test_stateless_bounded_task_loop(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    inference = ScriptedInference()
    runner = TaskRunner(
        _config(tmp_path, repository),
        ForgehandRuntime(_config(tmp_path, repository), inference),
    )

    result = runner.run(_request(repository))

    assert result["status"] == "success"
    assert result["changed_files"] == ["src/value.txt"]
    assert result["metrics"]["model_calls"] == 5
    assert result["metrics"]["total_tokens"] == 600
    assert result["review_required"] is True
    assert result["required_command_gate"]["passed"] is True
    assert Path(result["diff_path"]).is_file()
    assert (repository / "src" / "value.txt").read_text(encoding="utf-8") == "before\n"
    assert all("history" not in context for context in inference.contexts)
    assert "before" in json.dumps(inference.contexts[2])
    assert "before" not in json.dumps(inference.contexts[3])
    assert "Do not read that file again" in inference.contexts[2]["current_state"]["next_intent"]


def test_scope_root_discovery_reads_only_declared_scope(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    executor = ForgehandExecutor(
        _config(tmp_path, repository),
        _request(repository),
        checkout=repository,
        task_root=tmp_path / "task",
    )

    listed = executor.execute(1, WorkerAction(type="list_files", arguments={"path": "."}))

    paths = [item["path"] for item in listed["result"]["files"]]
    assert paths == ["src/value.txt"]
    assert "README.md" not in paths


def test_completion_normalizes_single_notes_without_another_model_call(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    executor = ForgehandExecutor(
        _config(tmp_path, repository),
        _request(repository),
        checkout=repository,
        task_root=tmp_path / "task",
    )

    completed = executor.execute(
        1,
        WorkerAction(
            type="complete",
            arguments={
                "status": "completed",
                "summary": "Done",
                "uncertainties": "None",
                "acceptance_notes": "The requested content is present.",
            },
        ),
    )

    assert completed["result"]["uncertainties"] == ["None"]
    assert completed["result"]["status"] == "success"
    assert completed["result"]["acceptance_notes"] == ["The requested content is present."]


def test_success_requires_every_required_command_to_pass(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    request = TaskRequest(
        repository_root=str(repository),
        objective="Validate the fixture.",
        scope=["src"],
        acceptance_criteria=["The validation command passes."],
        commands=[
            RepoCommand(
                command_id="validate",
                argv=[sys.executable, "-c", "print('validated')"],
            )
        ],
        required_command_ids=["validate"],
        acknowledge_host_command_risk=True,
    )
    executor = ForgehandExecutor(
        _config(tmp_path, repository),
        request,
        checkout=repository,
        task_root=tmp_path / "task",
    )
    completion = WorkerAction(
        type="complete",
        arguments={"status": "success", "summary": "Validated."},
    )

    with pytest.raises(ValueError, match="not run: validate"):
        executor.execute(1, completion)

    command = executor.execute(
        2,
        WorkerAction(type="run_command", arguments={"command_id": "validate"}),
    )
    completed = executor.execute(3, completion)

    assert command["result"]["exit_code"] == 0
    assert completed["result"]["status"] == "success"
    assert executor.required_command_gate()["passed"] is True


def test_failed_required_command_blocks_success(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    request = TaskRequest(
        repository_root=str(repository),
        objective="Validate the fixture.",
        scope=["src"],
        acceptance_criteria=["The validation command passes."],
        commands=[
            RepoCommand(
                command_id="validate",
                argv=[sys.executable, "-c", "raise SystemExit(7)"],
            )
        ],
        required_command_ids=["validate"],
        acknowledge_host_command_risk=True,
    )
    executor = ForgehandExecutor(
        _config(tmp_path, repository),
        request,
        checkout=repository,
        task_root=tmp_path / "task",
    )
    executor.execute(
        1,
        WorkerAction(type="run_command", arguments={"command_id": "validate"}),
    )

    with pytest.raises(ValueError, match="failed: validate"):
        executor.execute(
            2,
            WorkerAction(
                type="complete",
                arguments={"status": "success", "summary": "Validated."},
            ),
        )


def test_blocked_receipt_preserves_failed_required_command_evidence(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    config = _config(tmp_path, repository)
    request = TaskRequest(
        repository_root=str(repository),
        objective="Validate the fixture.",
        scope=["src"],
        acceptance_criteria=["The validation command passes."],
        commands=[
            RepoCommand(
                command_id="validate",
                argv=[sys.executable, "-c", "raise SystemExit(9)"],
            )
        ],
        required_command_ids=["validate"],
        acknowledge_host_command_risk=True,
        max_iterations=3,
        keep_worktree=False,
    )

    result = TaskRunner(
        config,
        ForgehandRuntime(config, FailedCommandThenCompleteInference()),
    ).run(request)

    assert result["status"] == "blocked"
    assert result["commands_run"] == ["validate"]
    assert result["command_results"]["validate"]["exit_code"] == 9
    assert result["required_command_gate"] == {
        "enforced": True,
        "required_command_ids": ["validate"],
        "missing_command_ids": [],
        "failed_command_ids": ["validate"],
        "passed": False,
    }


def test_host_commands_require_explicit_risk_acknowledgement(tmp_path: Path) -> None:
    repository = _repository(tmp_path)

    with pytest.raises(ValueError, match="inherit host OS permissions and network"):
        TaskRequest(
            repository_root=str(repository),
            objective="Run a check.",
            scope=["src"],
            acceptance_criteria=["The check passes."],
            commands=[RepoCommand(command_id="check", argv=["tool", "--check"])],
        )

    with pytest.raises(ValueError, match="must reference declared commands"):
        TaskRequest(
            repository_root=str(repository),
            objective="Run a check.",
            scope=["src"],
            acceptance_criteria=["The check passes."],
            required_command_ids=["missing"],
        )


def test_numeric_action_arguments_accept_json_digit_strings(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    executor = ForgehandExecutor(
        _config(tmp_path, repository),
        _request(repository),
        checkout=repository,
        task_root=tmp_path / "task",
    )

    read = executor.execute(
        1,
        WorkerAction(
            type="read_file",
            arguments={"path": "src/value.txt", "max_chars": "7"},
        ),
    )

    assert read["result"]["text"] == "before\n"
    assert '"action":"read_file"' in read["observation"]

    with pytest.raises(ValueError, match="already read completely"):
        executor.execute(
            2,
            WorkerAction(
                type="read_file",
                arguments={"path": "src/value.txt", "max_chars": 100},
            ),
        )

    executor.execute(
        3,
        WorkerAction(
            type="replace_text",
            arguments={
                "path": "src/value.txt",
                "old_text": "before",
                "new_text": "after",
            },
        ),
    )
    reread = executor.execute(
        4,
        WorkerAction(type="read_file", arguments={"path": "src/value.txt"}),
    )
    assert reread["result"]["text"] == "after\n"


def test_bounded_batch_read_reduces_multi_file_round_trips(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    (repository / "src" / "second.txt").write_text("second\n", encoding="utf-8")
    executor = ForgehandExecutor(
        _config(tmp_path, repository),
        _request(repository),
        checkout=repository,
        task_root=tmp_path / "task",
    )

    batch = executor.execute(
        1,
        WorkerAction(
            type="read_files",
            arguments={"paths": ["src/value.txt", "src/second.txt"]},
        ),
    )

    assert [item["path"] for item in batch["result"]["files"]] == [
        "src/value.txt",
        "src/second.txt",
    ]
    assert batch["result"]["returned_file_count"] == 2
    assert batch["result"]["observation_budget_exhausted"] is False
    assert '"action":"read_files"' in batch["observation"]
    assert (
        len(batch["observation"]) <= _config(tmp_path, repository).forgehand.max_observation_chars
    )

    with pytest.raises(ValueError, match="already read completely"):
        executor.execute(
            2,
            WorkerAction(
                type="read_files",
                arguments={"paths": ["src/value.txt", "src/second.txt"]},
            ),
        )


def test_billed_invalid_response_is_counted(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    config = _config(tmp_path, repository)
    result = TaskRunner(
        config,
        ForgehandRuntime(config, InvalidThenScriptedInference()),
    ).run(_request(repository))

    assert result["status"] == "success"
    assert result["metrics"]["model_calls"] == 6
    assert result["metrics"]["total_tokens"] == 720
    assert result["metrics"]["invalid_attempts"] == 1


def test_state_operations_are_typed_and_budgeted() -> None:
    state = AgentState(current_goal="goal", next_intent="next")
    updated = apply_state_operations(
        state,
        [
            StateOperation(
                op="upsert_hypothesis",
                path="/hypotheses",
                value={"id": "H1", "claim": "A bounded claim", "status": "testing"},
            ),
            StateOperation(op="append_unique", path="/decisions", value="Keep API stable"),
        ],
        max_state_chars=2_000,
    )
    assert updated.hypotheses[0].id == "H1"
    assert updated.decisions == ["Keep API stable"]

    with pytest.raises(ValueError, match="state budget exceeded"):
        apply_state_operations(
            updated,
            [StateOperation(op="set", path="/current_goal", value="x" * 900)],
            max_state_chars=200,
        )


def test_state_store_rejects_stale_revision_and_recovers(tmp_path: Path) -> None:
    store = ForgehandStore(tmp_path / "state")
    state = AgentState(current_goal="goal", next_intent="next")
    assert store.initialize(state)[0:2] == (0, 0)
    assert (
        store.commit(
            expected_revision=0,
            step=1,
            state=state,
            event_type="action_executed",
            event={"ok": True},
        )
        == 1
    )
    with pytest.raises(StaleStateError):
        store.commit(
            expected_revision=0,
            step=2,
            state=state,
            event_type="action_executed",
            event={"ok": False},
        )
    assert ForgehandStore(tmp_path / "state").current()[0:2] == (1, 1)


def test_executor_rejects_out_of_scope_action(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    config = _config(tmp_path, repository)
    executor = ForgehandExecutor(
        config,
        _request(repository),
        checkout=repository,
        task_root=tmp_path / "task",
    )
    with pytest.raises(PermissionError, match="outside declared scope"):
        executor.execute(
            1,
            WorkerAction(type="read_file", arguments={"path": "README.md"}),
        )


def test_search_skips_symlinked_files(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    outside = tmp_path / "secret.txt"
    outside.write_text("DO_NOT_READ\n", encoding="utf-8")
    link = repository / "src" / "linked-secret.txt"
    try:
        link.symlink_to(outside)
    except OSError:
        pytest.skip("symlink creation is unavailable")
    config = _config(tmp_path, repository)
    executor = ForgehandExecutor(
        config,
        _request(repository),
        checkout=repository,
        task_root=tmp_path / "task",
    )

    result = executor.execute(
        1,
        WorkerAction(
            type="search_text",
            arguments={"path": "src", "query": "DO_NOT_READ"},
        ),
    )

    assert result["result"]["matches"] == []


def test_configuration_round_trip_and_environment_override(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    path = tmp_path / "config.yaml"
    config = ForgehandConfig(project_root=tmp_path)
    write_config(config, path)
    monkeypatch.setenv("FORGEHAND_MODEL", "override-model")

    loaded = load_config(path)

    assert loaded.worker.model == "override-model"
    assert loaded.repo_tasks.worktree_root.is_absolute()


def test_unregistered_repository_is_rejected(tmp_path: Path) -> None:
    repository = _repository(tmp_path)
    config = ForgehandConfig(project_root=tmp_path)
    with pytest.raises(PermissionError, match="not registered"):
        TaskRunner(config).run(_request(repository))
