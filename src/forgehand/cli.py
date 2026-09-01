from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any

from forgehand.config import (
    ForgehandConfig,
    WorkerSettings,
    default_config_path,
    load_config,
    write_config,
)
from forgehand.doctor import _git_root, check
from forgehand.models import TaskRequest
from forgehand.tasks import TaskRunner


def _print(value: Any) -> None:
    print(json.dumps(value, ensure_ascii=False, indent=2))


def _config(args: argparse.Namespace) -> ForgehandConfig:
    return load_config(args.config)


def command_init(args: argparse.Namespace) -> int:
    path = Path(args.config).expanduser().resolve() if args.config else default_config_path()
    if path.exists() and not args.force:
        raise FileExistsError(f"configuration already exists: {path}; use --force")
    config = ForgehandConfig(
        project_root=path.parent,
        worker=WorkerSettings(
            name=args.worker_name,
            model=args.model,
            base_url=args.base_url,
            api_key_env=args.api_key_env,
        ),
    )
    written = write_config(config, path)
    _print({"ok": True, "config": str(written), "next": "forgehand doctor"})
    return 0


def command_doctor(args: argparse.Namespace) -> int:
    result = check(_config(args), args.config)
    _print(result)
    return 0 if result["ok"] else 1


def command_repo_add(args: argparse.Namespace) -> int:
    config = _config(args)
    repository = Path(args.path).expanduser().resolve()
    if not repository.is_dir() or _git_root(repository) != repository:
        raise ValueError("path must be an exact Git top-level directory")
    if repository not in config.repo_tasks.roots:
        config.repo_tasks.roots.append(repository)
    written = write_config(config, args.config)
    _print({"ok": True, "repository": str(repository), "config": str(written)})
    return 0


def command_repo_list(args: argparse.Namespace) -> int:
    _print({"repositories": [str(path) for path in _config(args).repo_tasks.roots]})
    return 0


def command_repo_remove(args: argparse.Namespace) -> int:
    config = _config(args)
    repository = Path(args.path).expanduser().resolve()
    config.repo_tasks.roots = [
        path for path in config.repo_tasks.roots if path.resolve() != repository
    ]
    written = write_config(config, args.config)
    _print({"ok": True, "repository": str(repository), "config": str(written)})
    return 0


def command_run(args: argparse.Namespace) -> int:
    payload = json.loads(Path(args.contract).read_text(encoding="utf-8"))
    result = TaskRunner(_config(args)).run(TaskRequest.model_validate(payload))
    _print(result)
    return 0 if result["status"] == "success" else 2


def command_tasks(args: argparse.Namespace) -> int:
    _print({"tasks": TaskRunner(_config(args)).list_tasks(args.limit)})
    return 0


def command_result(args: argparse.Namespace) -> int:
    _print(TaskRunner(_config(args)).get_task(args.task_id))
    return 0


def command_mcp(_: argparse.Namespace) -> int:
    from forgehand.mcp_server import main

    main()
    return 0


def command_dashboard(args: argparse.Namespace) -> int:
    from forgehand.dashboard import serve_dashboard

    serve_dashboard(_config(args), port=args.port, open_browser=not args.no_open)
    return 0


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser(
        prog="forgehand",
        description="Offload bounded coding work to one local model.",
    )
    root.add_argument("--config", help="path to config.yaml")
    commands = root.add_subparsers(dest="command", required=True)

    init = commands.add_parser("init", help="create a minimal local configuration")
    init.add_argument("--worker-name", default="Ornith 1.5 9B")
    init.add_argument("--model", default="ornith-ai/Ornith-1.5-9B")
    init.add_argument("--base-url", default="http://127.0.0.1:1234/v1")
    init.add_argument("--api-key-env", default="FORGEHAND_API_KEY")
    init.add_argument("--force", action="store_true")
    init.set_defaults(handler=command_init)

    doctor = commands.add_parser("doctor", help="verify Git, worker, and repositories")
    doctor.set_defaults(handler=command_doctor)

    repo = commands.add_parser("repo", help="manage exact allowed Git roots")
    repo_commands = repo.add_subparsers(dest="repo_command", required=True)
    repo_add = repo_commands.add_parser("add")
    repo_add.add_argument("path")
    repo_add.set_defaults(handler=command_repo_add)
    repo_list = repo_commands.add_parser("list")
    repo_list.set_defaults(handler=command_repo_list)
    repo_remove = repo_commands.add_parser("remove")
    repo_remove.add_argument("path")
    repo_remove.set_defaults(handler=command_repo_remove)

    run = commands.add_parser("run", help="run a task contract JSON file")
    run.add_argument("contract")
    run.set_defaults(handler=command_run)

    tasks = commands.add_parser("tasks", help="list recent compact receipts")
    tasks.add_argument("--limit", type=int, default=20)
    tasks.set_defaults(handler=command_tasks)
    result = commands.add_parser("result", help="read one compact receipt")
    result.add_argument("task_id")
    result.set_defaults(handler=command_result)
    dashboard = commands.add_parser("dashboard", help="open the local usage dashboard")
    dashboard.add_argument("--port", type=int, default=8765)
    dashboard.add_argument("--no-open", action="store_true")
    dashboard.set_defaults(handler=command_dashboard)
    mcp = commands.add_parser("mcp", help="start the stdio MCP server")
    mcp.set_defaults(handler=command_mcp)
    return root


def main() -> None:
    try:
        arguments = parser().parse_args()
        raise SystemExit(arguments.handler(arguments))
    except (OSError, ValueError, KeyError, PermissionError) as exc:
        print(f"forgehand: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc


if __name__ == "__main__":
    main()
