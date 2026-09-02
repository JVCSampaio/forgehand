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
    r"(?:API[_-]?KEY|ACCESS[_-]?KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTH|COOKIE|"
    r"BEARER|PRIVATE[_-]?KEY|PROXY|SSH_AUTH_SOCK|AWS_|AZURE_|GOOGLE_APPLICATION_|"
    r"GITHUB_|GH_|DOCKER_AUTH)",
    re.IGNORECASE,
)


def _git_bytes(root: Path, *arguments: str, timeout: int = 60) -> bytes:
    environment = dict(os.environ)
    environment.update({"GIT_PAGER": "cat", "GIT_OPTIONAL_LOCKS": "0"})
    completed = subprocess.run(
        ["git", "-C", str(root), *arguments],
        env=environment,
        stdin=subprocess.DEVNULL,
        capture_output=True,
        timeout=timeout,
        check=False,
    )
    if completed.returncode != 0:
        message = (completed.stderr or completed.stdout).decode("utf-8", errors="replace")
        raise RuntimeError(message.strip()[-2000:])
    return completed.stdout


def _git(root: Path, *arguments: str, timeout: int = 60) -> str:
    return _git_bytes(root, *arguments, timeout=timeout).decode("utf-8", errors="replace")


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
        self._repository_generation = 0
        self._complete_reads: dict[str, int] = {}
        self._last_repeatable_action: tuple[str, str] | None = None
        self._has_edit = False

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
        if len(raw) > 500:
            raise ValueError("path must not exceed 500 characters")
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
        if isinstance(value, str) and value.isascii() and value.isdecimal():
            value = int(value)
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

    def _repository_fingerprint(self) -> str:
        """Hash the Git-visible checkout state without exposing its contents."""
        digest = hashlib.sha256()
        digest.update(b"forgehand-repository-state-v1\0")
        tracked = _git_bytes(
            self.checkout,
            "diff",
            "HEAD",
            "--no-ext-diff",
            "--binary",
            "--",
            timeout=180,
        )
        digest.update(len(tracked).to_bytes(8, "big"))
        digest.update(tracked)

        untracked = _git_bytes(
            self.checkout,
            "ls-files",
            "--others",
            "--exclude-standard",
            "-z",
            timeout=180,
        )
        for relative_bytes in sorted(path for path in untracked.split(b"\0") if path):
            path = self.checkout / os.fsdecode(relative_bytes)
            digest.update(len(relative_bytes).to_bytes(8, "big"))
            digest.update(relative_bytes)
            if path.is_symlink():
                target = os.fsencode(os.readlink(path))
                digest.update(b"symlink\0")
                digest.update(len(target).to_bytes(8, "big"))
                digest.update(target)
                continue
            digest.update(b"file\0")
            digest.update(b"executable\0" if path.stat().st_mode & 0o111 else b"regular\0")
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        return digest.hexdigest()

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

    def execute(self, step: int, action: WorkerAction, *, internal: bool = False) -> dict[str, Any]:
        arguments = action.arguments
        if not isinstance(arguments, dict):
            raise ValueError("action arguments must be an object")
        if self.request.requires_changes and not internal:
            if not self._has_edit and action.type == "run_command" and self.command_results:
                raise ValueError("only one pre-edit validation is permitted")
            if self._has_edit and action.type == "run_command":
                raise ValueError("validation is runtime-controlled after an edit")
        if self.request.requires_changes and action.type == "run_command" and not self._has_edit:
            raise ValueError("validation cannot run before the first scoped edit")
        if action.type == "run_command":
            current_tree_hash = self._repository_fingerprint()
            signature = json.dumps(
                {"type": action.type, "arguments": arguments},
                sort_keys=True,
                separators=(",", ":"),
            )
            if self._last_repeatable_action == (signature, current_tree_hash):
                raise ValueError(
                    "the same command was already run on the unchanged repository; "
                    "make a change or choose a different approved check"
                )
        if action.type == "read_file" and isinstance(arguments.get("path"), str):
            target = self._resolve(arguments["path"])
            relative = target.relative_to(self.checkout).as_posix()
            if self._complete_reads.get(relative) == self._repository_generation:
                raise ValueError(
                    f"{relative} was already read completely and the repository is unchanged; "
                    "do not read it again—complete, run an approved check, or choose new work"
                )
        if action.type == "read_files" and isinstance(arguments.get("paths"), list):
            repeated = [
                path
                for path in arguments["paths"]
                if isinstance(path, str)
                and self._complete_reads.get(path.replace("\\", "/").strip("/"))
                == self._repository_generation
            ]
            if repeated:
                raise ValueError(
                    "files were already read completely and the repository is unchanged: "
                    + ", ".join(repeated)
                )
        handler = getattr(self, f"_action_{action.type}", None)
        if handler is None:  # pragma: no cover - guarded by the schema
            raise ValueError(f"unsupported action: {action.type}")
        result = handler(arguments)
        if action.type in {"replace_text", "write_file", "create_file", "apply_patch"}:
            self._has_edit = True
        if action.type == "run_command":
            self._last_repeatable_action = (
                signature,
                result.get("validated_tree_hash", self._repository_fingerprint()),
            )
        if (
            action.type == "read_file"
            and not result.get("truncated")
            and result.get("offset_chars") == 0
        ):
            self._complete_reads[str(result["path"])] = self._repository_generation
        if action.type == "read_files":
            for item in result.get("files", []):
                if not item.get("truncated"):
                    self._complete_reads[str(item["path"])] = self._repository_generation
        if action.type in {
            "replace_text",
            "write_file",
            "create_file",
            "apply_patch",
            "run_command",
        }:
            self._repository_generation += 1
        artifact = self._artifact(step, action.type, result)
        observation = json.dumps(
            {"action": action.type, "result": result},
            ensure_ascii=False,
            separators=(",", ":"),
        )
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

    def _action_read_files(self, arguments: dict[str, Any]) -> dict[str, Any]:
        paths = arguments.get("paths")
        if (
            not isinstance(paths, list)
            or not 1 <= len(paths) <= 8
            or not all(isinstance(path, str) for path in paths)
        ):
            raise ValueError("paths must be a list of 1 to 8 repository-relative strings")
        normalized_paths = [path.replace("\\", "/").strip("/") for path in paths]
        if len(normalized_paths) != len(set(normalized_paths)):
            raise ValueError("paths must not contain duplicates")
        maximum_each = max(
            1,
            self._integer(
                arguments,
                "max_chars_each",
                min(4_000, self.config.repo_tasks.max_file_chars),
                self.config.repo_tasks.max_file_chars,
            ),
        )
        # Reserve enough room for eight bounded paths, hashes, and JSON framing.
        remaining = max(1_000, self.config.forgehand.max_observation_chars - 6_000)
        files: list[dict[str, Any]] = []
        for value in normalized_paths:
            path = self._resolve(value)
            if not path.is_file():
                raise IsADirectoryError(path)
            text = path.read_text(encoding="utf-8")
            take = min(maximum_each, remaining)
            chunk = text[:take]
            relative = path.relative_to(self.checkout).as_posix()
            files.append(
                {
                    "path": relative,
                    "text": chunk,
                    "next_offset_chars": len(chunk),
                    "truncated": len(chunk) < len(text),
                    "sha256": self._hash(path),
                }
            )
            remaining -= len(chunk)
            if remaining <= 0:
                break
        return {
            "files": files,
            "requested_file_count": len(paths),
            "returned_file_count": len(files),
            "observation_budget_exhausted": len(files) < len(paths),
            "summary": f"Read {len(files)} of {len(paths)} requested file(s)",
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
        environment.update(
            {
                "GIT_TERMINAL_PROMPT": "0",
                "GCM_INTERACTIVE": "Never",
                "GIT_ASKPASS": "",
                "SSH_ASKPASS": "",
            }
        )
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
            "validated_tree_hash": self._repository_fingerprint(),
            "output": output,
            "output_truncated": truncated,
            "summary": f"{command_id} exited {completed.returncode}",
        }
        self.command_results[command_id] = result
        return result

    def _action_apply_patch(self, arguments: dict[str, Any]) -> dict[str, Any]:
        patch = arguments.get("patch")
        if not isinstance(patch, str) or not patch.strip():
            raise ValueError("patch must be a non-empty unified diff")
        if len(patch) > self.config.repo_tasks.max_file_chars:
            raise ValueError("patch exceeds the configured size limit")
        touched: list[str] = []
        for line in patch.splitlines():
            if line.startswith("+++ b/") or line.startswith("--- a/"):
                relative = line[6:].strip()
                if relative == "/dev/null":
                    continue
                if relative.startswith("a/") or relative.startswith("b/"):
                    relative = relative[2:]
                relative = relative.replace("\\", "/")
                if ".." in relative.split("/") or not self._in_scope(relative):
                    raise PermissionError(f"patch touches path outside declared scope: {relative}")
                touched.append(relative)
        if not touched:
            raise ValueError("patch does not contain a scoped file header")
        patch_file = self.artifact_dir / ".pending.patch"
        patch_file.write_text(patch, encoding="utf-8", newline="")
        environment = dict(os.environ)
        for name in list(environment):
            if SENSITIVE_ENV_NAME.search(name):
                environment.pop(name, None)
        checked = subprocess.run(
            [
                "git",
                "-C",
                str(self.checkout),
                "apply",
                "--check",
                "--whitespace=nowarn",
                str(patch_file),
            ],
            env=environment,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
            check=False,
        )
        if checked.returncode:
            raise ValueError((checked.stderr or checked.stdout).strip()[-2000:])
        applied = subprocess.run(
            ["git", "-C", str(self.checkout), "apply", "--whitespace=nowarn", str(patch_file)],
            env=environment,
            stdin=subprocess.DEVNULL,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
            check=False,
        )
        if applied.returncode:
            raise ValueError((applied.stderr or applied.stdout).strip()[-2000:])
        return {
            "changed_files": sorted(set(touched)),
            "summary": f"Applied patch to {len(set(touched))} scoped file(s)",
        }

    def command_evidence(self) -> dict[str, dict[str, Any]]:
        return {
            command_id: {
                "exit_code": result["exit_code"],
                "runtime_seconds": result["runtime_seconds"],
                "validated_tree_hash": result["validated_tree_hash"],
            }
            for command_id, result in self.command_results.items()
        }

    def required_command_gate(self) -> dict[str, Any]:
        required = self.request.required_command_ids
        missing = [command_id for command_id in required if command_id not in self.command_results]
        failed = [
            command_id
            for command_id in required
            if command_id in self.command_results
            and self.command_results[command_id]["exit_code"] != 0
        ]
        successful = [
            command_id
            for command_id in required
            if command_id in self.command_results
            and self.command_results[command_id]["exit_code"] == 0
        ]
        current_tree_hash = self._repository_fingerprint() if successful else None
        stale = [
            command_id
            for command_id in successful
            if self.command_results[command_id]["validated_tree_hash"] != current_tree_hash
        ]
        return {
            "enforced": True,
            "required_command_ids": required,
            "missing_command_ids": missing,
            "failed_command_ids": failed,
            "stale_command_ids": stale,
            "current_tree_hash": current_tree_hash,
            "passed": not missing and not failed and not stale,
        }

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
        if status in {"complete", "completed", "done"}:
            status = "success"
        if status not in {"success", "partial", "needs_review", "blocked"}:
            raise ValueError("completion status is invalid")
        gate = self.required_command_gate()
        if status == "success" and self.request.requires_changes:
            changed = [
                line for line in _git(self.checkout, "status", "--short").splitlines() if line
            ]
            if not changed:
                raise ValueError("success requires at least one changed file")
            if not self.request.required_command_ids:
                raise ValueError("success requires at least one required validation command")
            if not self.command_results:
                raise ValueError("success requires validation after the edit")
        if status == "success" and not gate["passed"]:
            problems = []
            if gate["missing_command_ids"]:
                problems.append("not run: " + ", ".join(gate["missing_command_ids"]))
            if gate["failed_command_ids"]:
                problems.append("failed: " + ", ".join(gate["failed_command_ids"]))
            if gate["stale_command_ids"]:
                problems.append("stale: " + ", ".join(gate["stale_command_ids"]))
            raise ValueError(
                "success requires passing required commands (" + "; ".join(problems) + ")"
            )
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
        if self.request.requires_changes:
            if self._has_edit:
                allowed_actions = ["replace_text", "write_file", "create_file", "complete"]
            else:
                allowed_actions = [
                    "list_files",
                    "read_file",
                    "read_files",
                    "search_text",
                    "replace_text",
                    "write_file",
                    "create_file",
                    "apply_patch",
                    "inspect_diff",
                ]
                if not self.command_results:
                    allowed_actions.append("run_command")
        else:
            allowed_actions = [
                "complete",
                "list_files",
                "read_file",
                "read_files",
                "search_text",
                "replace_text",
                "write_file",
                "create_file",
                "apply_patch",
                "run_command",
                "inspect_diff",
            ]
        return {
            "step": step,
            "workflow_phase": ("validate_or_complete" if self._has_edit else "inspect_then_edit"),
            "source_revision": source_revision,
            "allowed_action_types": allowed_actions,
            "changed_files": changed,
            "changed_file_count": len(changed),
            "approved_command_ids": sorted(self.commands),
            "required_command_gate": self.required_command_gate(),
            "command_security": {
                "shell": False,
                "os_level_sandbox": False,
                "host_network_inherited": True,
                "host_os_permissions_inherited": True,
                "sensitive_environment_removed": True,
                "host_risk_acknowledged": self.request.acknowledge_host_command_risk,
            },
            "command_results": self.command_evidence(),
        }
