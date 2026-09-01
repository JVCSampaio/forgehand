from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path
from typing import Any

from forgehand.config import ForgehandConfig
from forgehand.models import ArtifactRef, TaskRequest, WorkerAction

SENSITIVE_ENV_NAME = re.compile(
    r"(?:API[_-]?KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTH|COOKIE|BEARER|PRIVATE[_-]?KEY)",
    re.IGNORECASE,
)


def _git(root: Path, *arguments: str, timeout: int = 60) -> str:
    environment = dict(os.environ)
    environment.update({"GIT_PAGER": "cat", "GIT_OPTIONAL_LOCKS": "0"})
    completed = subprocess.run(
        ["git", "-C", str(root), *arguments],
        env=environment,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
        check=False,
    )
    if completed.returncode != 0:
        raise RuntimeError((completed.stderr or completed.stdout).strip()[-2000:])
    return completed.stdout


class ForgehandExecutor:
    """Execute one typed action inside the isolated worktree and declared scope."""

    def __init__(
        self,
        config: ForgehandConfig,
        request: TaskRequest,
        *,
        checkout: Path,
        task_root: Path,
    ):
        self.config = config
        self.request = request
        self.checkout = checkout.resolve()
        self.artifact_dir = task_root / "forgehand" / "artifacts"
        self.artifact_dir.mkdir(parents=True, exist_ok=True)
        self.commands = {command.command_id: command for command in request.commands}
        self.command_results: dict[str, dict[str, Any]] = {}

    def _in_scope(self, relative: str) -> bool:
        normalized = relative.replace("\\", "/").strip("/")
        return any(
            normalized == item or normalized.startswith(item.rstrip("/") + "/")
            for item in self.request.scope
        )

    def _resolve(
        self,
        value: Any,
        *,
        must_exist: bool = True,
        allow_scope_root: bool = False,
    ) -> Path:
        if not isinstance(value, str):
            raise ValueError("path must be a string")
        raw = value.strip().replace("\\", "/").strip("/")
        if raw == "." and allow_scope_root:
            return self.checkout
        if not raw or raw == "." or ".." in raw.split("/"):
            raise ValueError("path must be repository-relative")
        target = (self.checkout / raw).resolve()
        if self.checkout not in target.parents:
            raise PermissionError("path escapes the isolated worktree")
        relative = target.relative_to(self.checkout).as_posix()
        if not self._in_scope(relative):
            raise PermissionError(f"path is outside declared scope: {relative}")
        if must_exist and not target.exists():
            raise FileNotFoundError(relative)
        return target

    def _safe_discovered_file(self, path: Path) -> bool:
        if path.is_symlink() or not path.is_file():
            return False
        try:
            resolved = path.resolve()
            if self.checkout not in resolved.parents:
                return False
            relative = resolved.relative_to(self.checkout).as_posix()
        except (OSError, ValueError):
            return False
        return self._in_scope(relative)

    def _discovery_candidates(self, root: Path) -> list[Path]:
        roots = [root]
        if root == self.checkout:
            roots = [(self.checkout / item).resolve() for item in self.request.scope]
        candidates: list[Path] = []
        for candidate_root in roots:
            if not candidate_root.exists():
                continue
            candidates.extend(
                [candidate_root] if candidate_root.is_file() else sorted(candidate_root.rglob("*"))
            )
        return list(dict.fromkeys(candidates))

    @staticmethod
    def _integer(arguments: dict[str, Any], key: str, default: int, maximum: int) -> int:
        value = arguments.get(key, default)
        if not isinstance(value, int):
            raise ValueError(f"{key} must be an integer")
        return max(0, min(value, maximum))

    @staticmethod
    def _bounded(text: str, limit: int) -> tuple[str, bool]:
        if len(text) <= limit:
            return text, False
        head = limit * 2 // 3
        return text[:head] + "\n... truncated ...\n" + text[-(limit - head) :], True

    @staticmethod
    def _hash(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    def _artifact(self, step: int, action_type: str, result: dict[str, Any]) -> ArtifactRef:
        artifact_id = f"step:{step:03d}:{action_type}"
        path = self.artifact_dir / f"step-{step:03d}-{action_type}.json"
        path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
        summary = str(result.get("summary") or result.get("path") or action_type)
        return ArtifactRef(
            id=artifact_id,
            kind=action_type,
            path=str(path),
            summary=summary[:500],
        )

    def execute(self, step: int, action: WorkerAction) -> dict[str, Any]:
        arguments = action.arguments
        if not isinstance(arguments, dict):
            raise ValueError("action arguments must be an object")
        handler = getattr(self, f"_action_{action.type}", None)
        if handler is None:  # pragma: no cover - guarded by the schema
            raise ValueError(f"unsupported action: {action.type}")
        result = handler(arguments)
        artifact = self._artifact(step, action.type, result)
        observation = json.dumps(result, ensure_ascii=False, separators=(",", ":"))
        return {
            "action_type": action.type,
            "result": result,
            "observation": observation,
            "artifact": artifact,
            "completed": action.type == "complete",
        }

    def _action_list_files(self, arguments: dict[str, Any]) -> dict[str, Any]:
        root = self._resolve(arguments.get("path"), allow_scope_root=True)
        limit = max(1, self._integer(arguments, "limit", 200, 500))
        candidates = self._discovery_candidates(root)
        files = []
        for path in candidates:
            if self._safe_discovered_file(path):
                files.append(
                    {
                        "path": path.relative_to(self.checkout).as_posix(),
                        "size": path.stat().st_size,
                    }
                )
            if len(files) >= limit:
                break
        return {
            "files": files,
            "truncated": len(files) >= limit,
            "summary": f"{len(files)} file(s)",
        }

    def _action_read_file(self, arguments: dict[str, Any]) -> dict[str, Any]:
        path = self._resolve(arguments.get("path"))
        if not path.is_file():
            raise IsADirectoryError(path)
        text = path.read_text(encoding="utf-8")
        offset = self._integer(arguments, "offset_chars", 0, len(text))
        maximum = max(
            1,
            self._integer(
                arguments,
                "max_chars",
                min(12000, self.config.repo_tasks.max_file_chars),
                self.config.repo_tasks.max_file_chars,
            ),
        )
        chunk = text[offset : offset + maximum]
        relative = path.relative_to(self.checkout).as_posix()
        return {
            "path": relative,
            "text": chunk,
            "offset_chars": offset,
            "next_offset_chars": offset + len(chunk),
            "truncated": offset + len(chunk) < len(text),
            "sha256": self._hash(path),
            "summary": f"Read {len(chunk)} characters from {relative}",
        }

    def _action_search_text(self, arguments: dict[str, Any]) -> dict[str, Any]:
        root = self._resolve(arguments.get("path"), allow_scope_root=True)
        query = arguments.get("query")
        if not isinstance(query, str) or not query or len(query) > 500:
            raise ValueError("query must contain 1 to 500 characters")
        limit = max(1, self._integer(arguments, "limit", 100, 300))
        candidates = self._discovery_candidates(root)
        matches = []
        for candidate in candidates:
            if not self._safe_discovered_file(candidate):
                continue
            try:
                lines = candidate.read_text(encoding="utf-8").splitlines()
            except (UnicodeDecodeError, OSError):
                continue
            for line_number, line in enumerate(lines, 1):
                if query in line:
                    matches.append(
                        {
                            "path": candidate.relative_to(self.checkout).as_posix(),
                            "line": line_number,
                            "text": line[:1000],
                        }
                    )
                if len(matches) >= limit:
                    break
            if len(matches) >= limit:
                break
        return {
            "matches": matches,
            "truncated": len(matches) >= limit,
            "summary": f"{len(matches)} match(es)",
        }

    def _action_replace_text(self, arguments: dict[str, Any]) -> dict[str, Any]:
        path = self._resolve(arguments.get("path"))
        old_text = arguments.get("old_text")
        new_text = arguments.get("new_text")
        if not isinstance(old_text, str) or not old_text:
            raise ValueError("old_text must be a non-empty string")
        if not isinstance(new_text, str):
            raise ValueError("new_text must be a string")
        expected = self._integer(arguments, "expected_replacements", 1, 100)
        if expected < 1:
            raise ValueError("expected_replacements must be at least one")
        original = path.read_text(encoding="utf-8")
        count = original.count(old_text)
        if count != expected:
            raise ValueError(f"replacement guard expected {expected}, found {count}")
        updated = original.replace(old_text, new_text)
        if len(updated) > self.config.repo_tasks.max_file_chars:
            raise ValueError("updated file exceeds the repository task limit")
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            delete=False,
            dir=path.parent,
            prefix=f".{path.name}.forgehand-",
            suffix=".tmp",
        ) as handle:
            handle.write(updated)
            temporary = Path(handle.name)
        os.replace(temporary, path)
        relative = path.relative_to(self.checkout).as_posix()
        return {
            "path": relative,
            "replacements": count,
            "sha256": self._hash(path),
            "summary": f"Updated {relative}",
        }

    def _action_create_file(self, arguments: dict[str, Any]) -> dict[str, Any]:
        path = self._resolve(arguments.get("path"), must_exist=False)
        content = arguments.get("content")
        if not isinstance(content, str):
            raise ValueError("content must be a string")
        if path.exists():
            raise FileExistsError(path.relative_to(self.checkout).as_posix())
        if len(content) > self.config.repo_tasks.max_file_chars:
            raise ValueError("new file exceeds the repository task limit")
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8", newline="")
        relative = path.relative_to(self.checkout).as_posix()
        return {"path": relative, "sha256": self._hash(path), "summary": f"Created {relative}"}

    def _action_write_file(self, arguments: dict[str, Any]) -> dict[str, Any]:
        path = self._resolve(arguments.get("path"), must_exist=False)
        content = arguments.get("content")
        if not isinstance(content, str):
            raise ValueError("content must be a string")
        if len(content) > self.config.repo_tasks.max_file_chars:
            raise ValueError("file content exceeds the repository task limit")
        existed = path.exists()
        if existed and not path.is_file():
            raise IsADirectoryError(path.relative_to(self.checkout).as_posix())
        path.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            newline="",
            delete=False,
            dir=path.parent,
            prefix=f".{path.name}.forgehand-",
            suffix=".tmp",
        ) as handle:
            handle.write(content)
            temporary = Path(handle.name)
        os.replace(temporary, path)
        relative = path.relative_to(self.checkout).as_posix()
        verb = "Updated" if existed else "Created"
        return {
            "path": relative,
            "sha256": self._hash(path),
            "summary": f"{verb} {relative}",
        }

    def _action_run_command(self, arguments: dict[str, Any]) -> dict[str, Any]:
        command_id = arguments.get("command_id")
        if not isinstance(command_id, str) or command_id not in self.commands:
            raise PermissionError("command_id is not in the task contract")
        command = self.commands[command_id]
        cwd = (self.checkout / command.cwd).resolve()
        if cwd != self.checkout and self.checkout not in cwd.parents:
            raise PermissionError("command cwd escapes the isolated worktree")
        environment = dict(os.environ)
        for name in list(environment):
            if SENSITIVE_ENV_NAME.search(name):
                environment.pop(name, None)
        started = time.monotonic()
        completed = subprocess.run(
            command.argv,
            cwd=cwd,
            env=environment,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=command.timeout_seconds,
            check=False,
            shell=False,
        )
        combined = completed.stdout + (("\n" + completed.stderr) if completed.stderr else "")
        output, truncated = self._bounded(combined, self.config.repo_tasks.max_command_output_chars)
        result = {
            "command_id": command_id,
            "argv": command.argv,
            "exit_code": completed.returncode,
            "runtime_seconds": round(time.monotonic() - started, 3),
            "output": output,
            "output_truncated": truncated,
            "summary": f"{command_id} exited {completed.returncode}",
        }
        self.command_results[command_id] = result
        return result

    def _action_inspect_diff(self, arguments: dict[str, Any]) -> dict[str, Any]:
        maximum = max(
            1000,
            self._integer(
                arguments,
                "max_chars",
                self.config.repo_tasks.max_command_output_chars,
                self.config.repo_tasks.max_command_output_chars,
            ),
        )
        status = _git(self.checkout, "status", "--short")
        diff = _git(self.checkout, "diff", "--no-ext-diff", "--unified=3", "--")
        bounded, truncated = self._bounded(diff, maximum)
        changed = [line[3:] for line in status.splitlines() if len(line) >= 4]
        return {
            "changed_files": changed,
            "changed_file_count": len(changed),
            "status": status,
            "diff": bounded,
            "diff_truncated": truncated,
            "summary": f"{len(changed)} changed file(s)",
        }

    def _action_complete(self, arguments: dict[str, Any]) -> dict[str, Any]:
        status = arguments.get("status")
        if status not in {"success", "partial", "needs_review", "blocked"}:
            raise ValueError("completion status is invalid")
        summary = arguments.get("summary")
        if not isinstance(summary, str) or not summary.strip() or len(summary) > 2000:
            raise ValueError("completion summary must contain 1 to 2000 characters")
        uncertainties = arguments.get("uncertainties", [])
        acceptance_notes = arguments.get("acceptance_notes", [])
        if isinstance(uncertainties, str):
            uncertainties = [uncertainties]
        if isinstance(acceptance_notes, str):
            acceptance_notes = [acceptance_notes]
        if not isinstance(uncertainties, list) or not all(
            isinstance(item, str) for item in uncertainties
        ):
            raise ValueError("uncertainties must be a string list")
        if not isinstance(acceptance_notes, list) or not all(
            isinstance(item, str) for item in acceptance_notes
        ):
            raise ValueError("acceptance_notes must be a string list")
        return {
            "status": status,
            "summary": summary.strip(),
            "uncertainties": uncertainties[:20],
            "acceptance_notes": acceptance_notes[:20],
            "summary_detail": "Worker requested completion",
        }

    def runtime_facts(self, *, step: int, source_revision: str) -> dict[str, Any]:
        status = _git(self.checkout, "status", "--short")
        changed = [line[3:] for line in status.splitlines() if len(line) >= 4]
        return {
            "step": step,
            "source_revision": source_revision,
            "changed_files": changed,
            "changed_file_count": len(changed),
            "approved_command_ids": sorted(self.commands),
            "command_results": {
                key: {
                    "exit_code": value["exit_code"],
                    "runtime_seconds": value["runtime_seconds"],
                }
                for key, value in self.command_results.items()
            },
        }
