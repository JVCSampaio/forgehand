from __future__ import annotations

import os
from pathlib import Path

import pytest

from forgehand.config import ForgehandConfig, WorkerSettings
from forgehand.inference import OpenAICompatibleInference


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
