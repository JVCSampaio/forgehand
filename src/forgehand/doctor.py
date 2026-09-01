from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path
from typing import Any
from urllib.parse import urlparse

import httpx

from forgehand.config import ForgehandConfig, default_config_path


def _git_root(path: Path) -> Path | None:
    completed = subprocess.run(
        ["git", "-C", str(path), "rev-parse", "--show-toplevel"],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=20,
        check=False,
    )
    if completed.returncode:
        return None
    return Path(completed.stdout.strip()).resolve()


def check(config: ForgehandConfig, config_path: str | Path | None = None) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []
    active_config = (
        Path(config_path).expanduser().resolve() if config_path else default_config_path()
    )
    checks.append(
        {
            "name": "config",
            "ok": active_config.is_file(),
            "detail": str(active_config),
        }
    )
    git = shutil.which("git")
    checks.append({"name": "git", "ok": bool(git), "detail": git or "not found"})

    host = (urlparse(config.worker.base_url).hostname or "").lower()
    key = os.getenv(config.worker.api_key_env)
    parsed = urlparse(config.worker.base_url)
    loopback = host in {"127.0.0.1", "localhost", "::1"}
    endpoint_allowed = loopback or (parsed.scheme == "https" and bool(key))
    worker_detail = "remote endpoint requires HTTPS and the configured API key"
    worker_ok = False
    models: list[str] = []
    if endpoint_allowed:
        try:
            headers = {"Authorization": f"Bearer {key}"} if key else {}
            response = httpx.get(
                f"{config.worker.base_url.rstrip('/')}/models",
                headers=headers,
                timeout=10,
            )
            response.raise_for_status()
            models = [
                str(item.get("id"))
                for item in (response.json().get("data") or [])
                if isinstance(item, dict) and item.get("id")
            ]
            worker_ok = config.worker.model in models
            worker_detail = (
                f"configured model is available ({len(models)} discovered)"
                if worker_ok
                else f"configured model not found; discovered: {', '.join(models[:8])}"
            )
        except Exception as exc:
            worker_detail = f"{type(exc).__name__}: {exc}"
    checks.append({"name": "worker", "ok": worker_ok, "detail": worker_detail})

    for repository in config.repo_tasks.roots:
        actual = _git_root(repository) if repository.is_dir() else None
        checks.append(
            {
                "name": f"repository:{repository}",
                "ok": actual == repository.resolve(),
                "detail": str(actual) if actual else "not an exact Git root",
            }
        )
    return {
        "ok": all(item["ok"] for item in checks),
        "worker": config.worker.model,
        "checks": checks,
    }
