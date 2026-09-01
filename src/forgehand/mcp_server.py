from __future__ import annotations

from functools import lru_cache
from typing import Any

from mcp.server.fastmcp import FastMCP
from mcp.types import ToolAnnotations

from forgehand.config import ForgehandConfig, load_config
from forgehand.models import RepoCommand, TaskRequest
from forgehand.tasks import TaskRunner

MCP = FastMCP(
    "forgehand",
    instructions=(
        "Delegate complete, bounded repository tasks to one local worker. "
        "Forgehand isolates edits in Git worktrees, accepts only declared paths "
        "and approved commands, archives full evidence locally, and returns compact "
        "receipts. Always review the patch and critical tests before accepting work."
    ),
)

READ_ONLY = ToolAnnotations(
    readOnlyHint=True,
    destructiveHint=False,
    idempotentHint=True,
    openWorldHint=False,
)
LOCAL_WRITE = ToolAnnotations(
    readOnlyHint=False,
    destructiveHint=False,
    idempotentHint=False,
    openWorldHint=True,
)


@lru_cache(maxsize=1)
def _config() -> ForgehandConfig:
    return load_config()


@lru_cache(maxsize=1)
def _runner() -> TaskRunner:
    return TaskRunner(_config())


@MCP.tool(annotations=READ_ONLY)
def forgehand_health() -> dict[str, Any]:
    """Return active worker, safety limits, registered repositories, and paths."""
    config = _config()
    return {
        "ok": bool(config.forgehand.enabled),
        "runtime": "forgehand",
        "worker": {
            "name": config.worker.name,
            "model": config.worker.model,
            "base_url": config.worker.base_url,
            "api_key_env": config.worker.api_key_env,
        },
        "registered_repositories": [str(path) for path in config.repo_tasks.roots],
        "task_root": str(config.repo_tasks.worktree_root),
        "limits": {
            "max_steps": min(config.forgehand.max_steps, config.repo_tasks.max_steps),
            "max_context_chars": config.forgehand.max_context_chars,
            "max_state_chars": config.forgehand.max_state_chars,
            "max_changed_files": config.repo_tasks.max_changed_files,
        },
        "security": {
            "registered_git_roots_only": True,
            "isolated_worktrees": True,
            "declared_scope_only": True,
            "approved_argv_commands_only": True,
            "shell_disabled": True,
            "worker_network_tools": False,
            "command_environment_secrets_removed": True,
            "os_level_command_sandbox": False,
            "commands_inherit_host_network": True,
            "commands_inherit_host_os_permissions": True,
            "host_command_risk_acknowledgement_required": True,
            "required_command_success_gate": True,
            "final_review_required": True,
        },
    }


@MCP.tool(annotations=LOCAL_WRITE)
def forgehand_delegate(
    repository_root: str,
    objective: str,
    scope: list[str],
    acceptance_criteria: list[str],
    constraints: list[str] | None = None,
    commands: list[RepoCommand] | None = None,
    required_command_ids: list[str] | None = None,
    acknowledge_host_command_risk: bool = False,
    base_revision: str = "HEAD",
    max_iterations: int = 10,
    keep_worktree: bool = True,
) -> dict[str, Any]:
    """Run one complete implementation task with bounded files and commands.

    The repository must be registered first. Scope contains the only paths the
    worker may read or edit. Commands are supervisor-authored argv arrays invoked
    by ID without a shell, but inherit host permissions and network. Set the risk
    acknowledgement explicitly whenever commands are present. Required command IDs
    must all exit zero before the worker can return success.
    """
    request = TaskRequest(
        repository_root=repository_root,
        objective=objective,
        scope=scope,
        constraints=constraints or [],
        acceptance_criteria=acceptance_criteria,
        commands=commands or [],
        required_command_ids=required_command_ids or [],
        acknowledge_host_command_risk=acknowledge_host_command_risk,
        base_revision=base_revision,
        max_iterations=max_iterations,
        keep_worktree=keep_worktree,
    )
    return _runner().run(request)


@MCP.tool(annotations=READ_ONLY)
def forgehand_tasks(limit: int = 20) -> dict[str, Any]:
    """List compact receipts for recent tasks without loading raw logs or diffs."""
    rows = _runner().list_tasks(limit)
    return {"count": len(rows), "tasks": rows}


@MCP.tool(annotations=READ_ONLY)
def forgehand_result(task_id: str) -> dict[str, Any]:
    """Return one compact task receipt by ID."""
    return _runner().get_task(task_id)


def main() -> None:
    MCP.run(transport="stdio")


if __name__ == "__main__":
    main()
