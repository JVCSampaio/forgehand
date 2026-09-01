from __future__ import annotations

import os
import subprocess
from pathlib import Path

import pytest

from forgehand.config import RepositorySettings, load_config
from forgehand.models import TaskRequest
from forgehand.tasks import TaskRunner


def _git(repository: Path, *arguments: str) -> None:
    subprocess.run(
        ["git", "-C", str(repository), *arguments],
        capture_output=True,
        text=True,
        check=True,
    )


@pytest.mark.skipif(
    not os.getenv("RUN_FORGEHAND_LIVE"),
    reason="set RUN_FORGEHAND_LIVE=1 when the configured local worker is available",
)
def test_live_local_worker(tmp_path: Path) -> None:
    repository = tmp_path / "repository"
    repository.mkdir()
    (repository / "value.txt").write_text("before\n", encoding="utf-8")
    _git(repository, "init")
    _git(repository, "config", "user.email", "tests@example.invalid")
    _git(repository, "config", "user.name", "Test Runner")
    _git(repository, "add", ".")
    _git(repository, "commit", "-m", "fixture")
    config = load_config().model_copy(deep=True)
    config.repo_tasks = RepositorySettings(
        roots=[repository.resolve()],
        worktree_root=tmp_path / "tasks",
        retain_worktrees=False,
    )
    result = TaskRunner(config).run(
        TaskRequest(
            repository_root=str(repository.resolve()),
            objective="Replace the complete contents of value.txt with after and a newline.",
            scope=["value.txt"],
            acceptance_criteria=["value.txt contains exactly after and a newline."],
            max_iterations=8,
            keep_worktree=False,
        )
    )
    assert result["status"] == "success", result
    assert result["changed_files"] == ["value.txt"]
