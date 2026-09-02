from __future__ import annotations

import os
from pathlib import Path

import yaml
from pydantic import BaseModel, Field, model_validator


def default_config_path() -> Path:
    override = os.getenv("FORGEHAND_CONFIG")
    if override:
        return Path(override).expanduser().resolve()
    if os.name == "nt" and os.getenv("APPDATA"):
        return Path(os.environ["APPDATA"]) / "Forgehand" / "config.yaml"
    root = Path(os.getenv("XDG_CONFIG_HOME", Path.home() / ".config"))
    return root / "forgehand" / "config.yaml"


def default_data_path() -> Path:
    if os.name == "nt" and os.getenv("LOCALAPPDATA"):
        return Path(os.environ["LOCALAPPDATA"]) / "Forgehand"
    root = Path(os.getenv("XDG_DATA_HOME", Path.home() / ".local" / "share"))
    return root / "forgehand"


class WorkerSettings(BaseModel):
    name: str = Field("Ornith 1.5 9B", min_length=1, max_length=120)
    model: str = Field("ornith-ai/Ornith-1.5-9B", min_length=1, max_length=300)
    base_url: str = "http://127.0.0.1:1234/v1"
    api_key_env: str = Field("FORGEHAND_API_KEY", min_length=1, max_length=120)


class RepositorySettings(BaseModel):
    roots: list[Path] = Field(default_factory=list, max_length=64)
    worktree_root: Path = Field(default_factory=lambda: default_data_path() / "tasks")
    max_steps: int = Field(50, ge=1, le=100)
    max_file_chars: int = Field(120_000, ge=1_000, le=1_000_000)
    max_changed_files: int = Field(80, ge=1, le=500)
    max_command_output_chars: int = Field(20_000, ge=1_000, le=100_000)
    retain_worktrees: bool = True


class RuntimeSettings(BaseModel):
    enabled: bool = True
    max_steps: int = Field(50, ge=1, le=100)
    max_state_chars: int = Field(12_288, ge=1_000, le=100_000)
    max_observation_chars: int = Field(12_000, ge=1_000, le=100_000)
    max_context_chars: int = Field(32_000, ge=4_000, le=200_000)
    max_output_tokens: int = Field(1_400, ge=256, le=8_192)
    temperature: float = Field(0.6, ge=0, le=2)
    top_p: float = Field(0.95, gt=0, le=1)
    seed: int | None = Field(default=None, ge=0, le=2_147_483_647)
    reasoning_effort: str = Field("none", pattern=r"^(none|minimal|low|medium|high)$")
    inference_timeout_seconds: int = Field(240, ge=10, le=1_200)
    invalid_output_retries: int = Field(2, ge=0, le=5)
    max_action_rejections: int = Field(3, ge=1, le=20)
    max_no_progress_steps: int = Field(2, ge=1, le=10)


class ForgehandConfig(BaseModel):
    project_root: Path
    worker: WorkerSettings = Field(default_factory=WorkerSettings)
    repo_tasks: RepositorySettings = Field(default_factory=RepositorySettings)
    forgehand: RuntimeSettings = Field(default_factory=RuntimeSettings)

    @model_validator(mode="after")
    def resolve_paths(self) -> ForgehandConfig:
        root = self.project_root.resolve()

        def absolute(path: Path) -> Path:
            return path.resolve() if path.is_absolute() else (root / path).resolve()

        self.repo_tasks.roots = [absolute(path) for path in self.repo_tasks.roots]
        self.repo_tasks.worktree_root = absolute(self.repo_tasks.worktree_root)
        return self


def load_config(path: str | Path | None = None) -> ForgehandConfig:
    config_path = Path(path).expanduser().resolve() if path else default_config_path()
    raw: dict = {}
    if config_path.is_file():
        raw = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    worker = raw.setdefault("worker", {})
    for field, environment in {
        "name": "FORGEHAND_WORKER_NAME",
        "model": "FORGEHAND_MODEL",
        "base_url": "FORGEHAND_BASE_URL",
        "api_key_env": "FORGEHAND_API_KEY_ENV",
    }.items():
        if value := os.getenv(environment):
            worker[field] = value
    return ForgehandConfig(project_root=config_path.parent, **raw)


def write_config(config: ForgehandConfig, path: str | Path | None = None) -> Path:
    config_path = Path(path).expanduser().resolve() if path else default_config_path()
    config_path.parent.mkdir(parents=True, exist_ok=True)
    payload = config.model_dump(mode="json", exclude={"project_root"})
    config_path.write_text(
        yaml.safe_dump(payload, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    return config_path
