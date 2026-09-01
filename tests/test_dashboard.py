from __future__ import annotations

import json

from test_forgehand import _config, _repository

from forgehand.dashboard import dashboard_snapshot
from forgehand.tasks import TaskRunner


def test_dashboard_snapshot_is_aggregated_and_hides_paths(tmp_path) -> None:
    repository = _repository(tmp_path)
    config = _config(tmp_path, repository)
    task_root = config.repo_tasks.worktree_root / "00000000-0000-0000-0000-000000000001"
    task_root.mkdir(parents=True)
    (task_root / "result.json").write_text(
        json.dumps(
            {
                "task_id": task_root.name,
                "status": "success",
                "repository_root": str(repository),
                "worker_summary": "Done",
                "changed_file_count": 1,
                "required_command_gate": {
                    "required_command_ids": ["tests"],
                    "missing_command_ids": [],
                    "failed_command_ids": [],
                    "passed": True,
                },
                "metrics": {"total_tokens": 120, "model_calls": 2, "wall_seconds": 3.5},
            }
        ),
        encoding="utf-8",
    )

    snapshot = dashboard_snapshot(config)

    assert snapshot["totals"] == {
        "tasks": 1,
        "tokens": 120,
        "calls": 2,
        "wall_seconds": 3.5,
        "required_gates": 1,
        "passed_gates": 1,
    }
    assert snapshot["tasks"][0]["repository"] == repository.name
    assert snapshot["tasks"][0]["validation_gate"] == "passed"
    assert str(repository) not in json.dumps(snapshot)
    assert TaskRunner(config).list_tasks(1)
