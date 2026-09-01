from __future__ import annotations

import json
import subprocess
import threading
from datetime import UTC, datetime
from pathlib import Path
from typing import Any
from uuid import UUID, uuid4

from forgehand.config import ForgehandConfig
from forgehand.models import TaskRequest
from forgehand.runtime import ForgehandRuntime


def _git(repository: Path, *arguments: str, timeout: int = 120) -> str:
    completed = subprocess.run(
        ["git", "-C", str(repository), *arguments],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        check=False,
    )
    if completed.returncode:
        detail = (completed.stderr or completed.stdout).strip()[-2_000:]
        raise RuntimeError(f"git {' '.join(arguments)} failed: {detail}")
    return completed.stdout


class TaskRunner:
    """Run one Forgehand task in a detached, explicitly registered worktree."""

    def __init__(self, config: ForgehandConfig, runtime: ForgehandRuntime | None = None):
        self.config = config
        self.runtime = runtime or ForgehandRuntime(config)
        self._lock = threading.Lock()

    def _registered_repository(self, value: str) -> Path:
        repository = Path(value).expanduser().resolve()
        registered = {path.resolve() for path in self.config.repo_tasks.roots}
        if repository not in registered:
            raise PermissionError(
                "repository_root is not registered; run `forgehand repo add PATH`"
            )
        if not repository.is_dir():
            raise NotADirectoryError(repository)
        actual = Path(_git(repository, "rev-parse", "--show-toplevel").strip()).resolve()
        if actual != repository:
            raise ValueError("repository_root must be the exact Git top-level directory")
        return repository

    @staticmethod
    def _in_scope(path: str, scope: list[str]) -> bool:
        normalized = path.replace("\\", "/").strip("/")
        return any(
            normalized == item or normalized.startswith(item.rstrip("/") + "/") for item in scope
        )

    def run(self, request: TaskRequest) -> dict[str, Any]:
        with self._lock:
            return self._run_locked(request)

    def _run_locked(self, request: TaskRequest) -> dict[str, Any]:
        repository = self._registered_repository(request.repository_root)
        revision = _git(
            repository,
            "rev-parse",
            "--verify",
            f"{request.base_revision}^{{commit}}",
        ).strip()
        task_id = str(uuid4())
        task_root = self.config.repo_tasks.worktree_root / task_id
        checkout = task_root / "checkout"
        task_root.mkdir(parents=True, exist_ok=False)
        _git(repository, "worktree", "add", "--detach", str(checkout), revision)

        contract = {
            "schema_version": "forgehand_task_v1",
            "task_id": task_id,
            "repository_root": str(repository),
            "source_revision": revision,
            "scope": request.scope,
            "objective": request.objective,
            "constraints": request.constraints,
            "acceptance_criteria": request.acceptance_criteria,
            "commands": [command.model_dump() for command in request.commands],
            "max_iterations": request.max_iterations,
            "limits": {
                "max_file_chars": self.config.repo_tasks.max_file_chars,
                "max_changed_files": self.config.repo_tasks.max_changed_files,
                "max_command_output_chars": (self.config.repo_tasks.max_command_output_chars),
            },
            "created_at": datetime.now(UTC).isoformat(),
        }
        contract_path = task_root / "contract.json"
        contract_path.write_text(
            json.dumps(contract, ensure_ascii=False, indent=2), encoding="utf-8"
        )

        worker_response: dict[str, Any] | None = None
        worker_error: str | None = None
        try:
            worker_response = self.runtime.run(
                request,
                task_root=task_root,
                checkout=checkout,
                contract_path=contract_path,
                source_revision=revision,
            )
        except Exception as exc:
            worker_error = f"{type(exc).__name__}: {exc}"[:4_000]

        status_entries = [
            entry
            for entry in _git(
                checkout,
                "-c",
                "core.quotepath=false",
                "status",
                "--porcelain=v1",
                "-z",
            ).split("\x00")
            if entry
        ]
        changed_files: list[str] = []
        untracked: list[str] = []
        index = 0
        while index < len(status_entries):
            entry = status_entries[index]
            if len(entry) < 4:
                index += 1
                continue
            path = entry[3:].replace("\\", "/")
            changed_files.append(path)
            if entry.startswith("?? "):
                untracked.append(entry[3:])
            if "R" in entry[:2] or "C" in entry[:2]:
                index += 1
                if index < len(status_entries):
                    changed_files.append(status_entries[index].replace("\\", "/"))
            index += 1
        changed_files = list(dict.fromkeys(changed_files))
        out_of_scope = sorted(
            path for path in changed_files if not self._in_scope(path, request.scope)
        )
        too_many_files = len(changed_files) > self.config.repo_tasks.max_changed_files

        if untracked:
            _git(checkout, "add", "-N", "--", *untracked)
        diff = _git(
            checkout,
            "diff",
            "--no-ext-diff",
            "--binary",
            "--",
            timeout=180,
        )
        diff_path = task_root / "changes.patch"
        diff_path.write_text(diff, encoding="utf-8")

        parsed = (worker_response or {}).get("json", {})
        status = parsed.get("status", "blocked") if isinstance(parsed, dict) else "blocked"
        if status not in {"success", "partial", "needs_review", "blocked"}:
            status = "needs_review"
        if worker_error:
            status = "blocked"
        if out_of_scope or too_many_files:
            status = "needs_review"

        retained = request.keep_worktree or self.config.repo_tasks.retain_worktrees
        result = {
            "schema_version": "forgehand_result_v1",
            "task_id": task_id,
            "status": status,
            "model": self.config.worker.model,
            "source_revision": revision,
            "repository_root": str(repository),
            "worktree": str(checkout),
            "contract_path": str(contract_path),
            "diff_path": str(diff_path),
            "changed_files": changed_files,
            "changed_file_count": len(changed_files),
            "out_of_scope_files": out_of_scope,
            "changed_file_limit_exceeded": too_many_files,
            "worker_summary": parsed.get("summary") if isinstance(parsed, dict) else None,
            "confidence": parsed.get("confidence") if isinstance(parsed, dict) else None,
            "uncertainties": (parsed.get("uncertainties", []) if isinstance(parsed, dict) else []),
            "acceptance_notes": (
                parsed.get("acceptance_notes", []) if isinstance(parsed, dict) else []
            ),
            "worker_error": worker_error,
            "metrics": (worker_response or {}).get("forgehand"),
            "review_required": True,
            "retained": retained,
            "finished_at": datetime.now(UTC).isoformat(),
        }
        result_path = task_root / "result.json"
        result["result_path"] = str(result_path)
        result_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")

        if not retained:
            _git(repository, "worktree", "remove", "--force", str(checkout))
        return result

    def list_tasks(self, limit: int = 20) -> list[dict[str, Any]]:
        root = self.config.repo_tasks.worktree_root
        if not root.is_dir():
            return []
        rows: list[dict[str, Any]] = []
        paths = sorted(
            root.glob("*/result.json"), key=lambda path: path.stat().st_mtime, reverse=True
        )
        for path in paths:
            try:
                result = json.loads(path.read_text(encoding="utf-8"))
                metrics = result.get("metrics") or {}
                rows.append(
                    {
                        "task_id": result.get("task_id"),
                        "status": result.get("status"),
                        "model": result.get("model"),
                        "repository_root": result.get("repository_root"),
                        "source_revision": result.get("source_revision"),
                        "changed_files": result.get("changed_files", []),
                        "changed_file_count": result.get("changed_file_count", 0),
                        "worker_summary": result.get("worker_summary"),
                        "confidence": result.get("confidence"),
                        "uncertainties": result.get("uncertainties", []),
                        "metrics": {
                            key: metrics.get(key)
                            for key in (
                                "model_calls",
                                "prompt_tokens",
                                "completion_tokens",
                                "total_tokens",
                                "inference_seconds",
                                "invalid_attempts",
                                "wall_seconds",
                            )
                        },
                        "review_required": True,
                        "finished_at": result.get("finished_at"),
                    }
                )
            except (OSError, json.JSONDecodeError):
                continue
            if len(rows) >= max(1, min(limit, 200)):
                break
        return rows

    def get_task(self, task_id: str) -> dict[str, Any]:
        try:
            parsed = str(UUID(task_id))
        except (ValueError, AttributeError) as exc:
            raise ValueError("invalid task ID") from exc
        result_path = self.config.repo_tasks.worktree_root / parsed / "result.json"
        if not result_path.is_file():
            raise KeyError(task_id)
        return json.loads(result_path.read_text(encoding="utf-8"))
