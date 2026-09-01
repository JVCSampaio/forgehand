from __future__ import annotations

import json
import os
import sys
from pathlib import Path

import pytest

from forgehand.config import ForgehandConfig, WorkerSettings
from forgehand.executor import ForgehandExecutor
from forgehand.inference import OpenAICompatibleInference
from forgehand.models import RepoCommand, TaskRequest, WorkerAction


def test_remote_http_endpoint_is_rejected(tmp_path: Path) -> None:
    config = ForgehandConfig(
        project_root=tmp_path,
        worker=WorkerSettings(
            model="worker",
            base_url="http://worker.example/v1",
            api_key_env="TEST_FORGEHAND_KEY",
        ),
    )
    os.environ["TEST_FORGEHAND_KEY"] = "secret"
    try:
        with pytest.raises(RuntimeError, match="must use HTTPS"):
            OpenAICompatibleInference(config)._headers()
    finally:
        os.environ.pop("TEST_FORGEHAND_KEY", None)


def test_remote_https_endpoint_requires_key(tmp_path: Path) -> None:
    config = ForgehandConfig(
        project_root=tmp_path,
        worker=WorkerSettings(
            model="worker",
            base_url="https://worker.example/v1",
            api_key_env="MISSING_FORGEHAND_KEY",
        ),
    )
    with pytest.raises(RuntimeError, match="environment variable is missing"):
        OpenAICompatibleInference(config)._headers()


def test_command_environment_removes_common_credential_channels(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    repository = tmp_path / "repository"
    repository.mkdir()
    request = TaskRequest(
        repository_root=str(repository),
        objective="Inspect the command environment.",
        scope=["fixture.txt"],
        acceptance_criteria=["Sensitive environment variables are absent."],
        commands=[
            RepoCommand(
                command_id="environment",
                argv=[
                    sys.executable,
                    "-c",
                    (
                        "import json,os; print(json.dumps({k:os.environ.get(k) for k in "
                        "['AWS_ACCESS_KEY_ID','HTTP_PROXY','SSH_AUTH_SOCK','SAFE_BUILD_FLAG',"
                        "'GIT_TERMINAL_PROMPT','GCM_INTERACTIVE']}))"
                    ),
                ],
            )
        ],
        acknowledge_host_command_risk=True,
    )
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "credential")
    monkeypatch.setenv("HTTP_PROXY", "http://credential.invalid")
    monkeypatch.setenv("SSH_AUTH_SOCK", "agent")
    monkeypatch.setenv("SAFE_BUILD_FLAG", "preserved")
    executor = ForgehandExecutor(
        ForgehandConfig(project_root=tmp_path),
        request,
        checkout=repository,
        task_root=tmp_path / "task",
    )

    result = executor.execute(
        1,
        WorkerAction(type="run_command", arguments={"command_id": "environment"}),
    )
    environment = json.loads(result["result"]["output"])

    assert environment["AWS_ACCESS_KEY_ID"] is None
    assert environment["HTTP_PROXY"] is None
    assert environment["SSH_AUTH_SOCK"] is None
    assert environment["SAFE_BUILD_FLAG"] == "preserved"
    assert environment["GIT_TERMINAL_PROMPT"] == "0"
    assert environment["GCM_INTERACTIVE"] == "Never"
