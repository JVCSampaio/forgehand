from __future__ import annotations

import json
import os
import sqlite3
import tempfile
from collections.abc import Iterator
from contextlib import contextmanager
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

from forgehand.models import AgentState, StepUsage

SCHEMA = """
PRAGMA journal_mode=WAL;
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS state_snapshots (
    revision INTEGER PRIMARY KEY,
    step INTEGER NOT NULL,
    state_json TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS events (
    event_id INTEGER PRIMARY KEY AUTOINCREMENT,
    step INTEGER NOT NULL,
    revision INTEGER NOT NULL,
    event_type TEXT NOT NULL,
    payload_json TEXT NOT NULL,
    created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS step_usage (
    step INTEGER NOT NULL,
    attempt INTEGER NOT NULL,
    prompt_tokens INTEGER NOT NULL,
    completion_tokens INTEGER NOT NULL,
    total_tokens INTEGER NOT NULL,
    latency_seconds REAL NOT NULL,
    model TEXT NOT NULL,
    response_hash TEXT NOT NULL,
    created_at TEXT NOT NULL,
    PRIMARY KEY(step, attempt)
);
"""


class StaleStateError(RuntimeError):
    pass


class ForgehandStore:
    """Transactional state snapshots plus archived events that are not auto-attended."""

    def __init__(self, root: Path):
        self.root = root
        self.root.mkdir(parents=True, exist_ok=True)
        self.database = root / "state.db"
        self.export_path = root / "current.json"
        with self.connection() as connection:
            connection.executescript(SCHEMA)

    @contextmanager
    def connection(self) -> Iterator[sqlite3.Connection]:
        connection = sqlite3.connect(self.database, timeout=10)
        connection.row_factory = sqlite3.Row
        try:
            yield connection
            connection.commit()
        finally:
            connection.close()

    @staticmethod
    def _now() -> str:
        return datetime.now(UTC).isoformat()

    def initialize(self, state: AgentState) -> tuple[int, int, AgentState]:
        with self.connection() as connection:
            row = connection.execute(
                "SELECT revision,step,state_json FROM state_snapshots "
                "ORDER BY revision DESC LIMIT 1"
            ).fetchone()
            if row is None:
                connection.execute(
                    "INSERT INTO state_snapshots(revision,step,state_json,created_at) "
                    "VALUES(0,0,?,?)",
                    (state.model_dump_json(), self._now()),
                )
                revision, step, current = 0, 0, state
            else:
                revision = int(row["revision"])
                step = int(row["step"])
                current = AgentState.model_validate_json(row["state_json"])
        self._export(revision, step, current)
        return revision, step, current

    def current(self) -> tuple[int, int, AgentState]:
        with self.connection() as connection:
            row = connection.execute(
                "SELECT revision,step,state_json FROM state_snapshots "
                "ORDER BY revision DESC LIMIT 1"
            ).fetchone()
        if row is None:
            raise RuntimeError("Forgehand state has not been initialized")
        return (
            int(row["revision"]),
            int(row["step"]),
            AgentState.model_validate_json(row["state_json"]),
        )

    def commit(
        self,
        *,
        expected_revision: int,
        step: int,
        state: AgentState,
        event_type: str,
        event: dict[str, Any],
    ) -> int:
        next_revision = expected_revision + 1
        with self.connection() as connection:
            connection.execute("BEGIN IMMEDIATE")
            row = connection.execute(
                "SELECT MAX(revision) AS revision FROM state_snapshots"
            ).fetchone()
            current_revision = int(row["revision"] if row["revision"] is not None else -1)
            if current_revision != expected_revision:
                raise StaleStateError(
                    f"stale state revision {expected_revision}; current is {current_revision}"
                )
            connection.execute(
                "INSERT INTO state_snapshots(revision,step,state_json,created_at) VALUES(?,?,?,?)",
                (next_revision, step, state.model_dump_json(), self._now()),
            )
            connection.execute(
                "INSERT INTO events(step,revision,event_type,payload_json,created_at) "
                "VALUES(?,?,?,?,?)",
                (
                    step,
                    next_revision,
                    event_type,
                    json.dumps(event, ensure_ascii=False, separators=(",", ":")),
                    self._now(),
                ),
            )
        self._export(next_revision, step, state)
        return next_revision

    def record_event(
        self,
        *,
        step: int,
        revision: int,
        event_type: str,
        event: dict[str, Any],
    ) -> None:
        with self.connection() as connection:
            connection.execute(
                "INSERT INTO events(step,revision,event_type,payload_json,created_at) "
                "VALUES(?,?,?,?,?)",
                (
                    step,
                    revision,
                    event_type,
                    json.dumps(event, ensure_ascii=False, separators=(",", ":")),
                    self._now(),
                ),
            )

    def record_usage(
        self,
        *,
        step: int,
        attempt: int,
        usage: StepUsage,
        response_hash: str,
    ) -> None:
        with self.connection() as connection:
            connection.execute(
                "INSERT OR REPLACE INTO step_usage("
                "step,attempt,prompt_tokens,completion_tokens,total_tokens,"
                "latency_seconds,model,response_hash,created_at) VALUES(?,?,?,?,?,?,?,?,?)",
                (
                    step,
                    attempt,
                    usage.prompt_tokens,
                    usage.completion_tokens,
                    usage.total_tokens,
                    usage.latency_seconds,
                    usage.model,
                    response_hash,
                    self._now(),
                ),
            )

    def metrics(self) -> dict[str, Any]:
        with self.connection() as connection:
            usage = connection.execute(
                "SELECT COUNT(*) AS calls, COALESCE(SUM(prompt_tokens),0) AS prompt_tokens,"
                "COALESCE(SUM(completion_tokens),0) AS completion_tokens,"
                "COALESCE(SUM(total_tokens),0) AS total_tokens,"
                "COALESCE(SUM(latency_seconds),0) AS latency_seconds FROM step_usage"
            ).fetchone()
            events = connection.execute(
                "SELECT event_type,COUNT(*) AS count FROM events GROUP BY event_type"
            ).fetchall()
            snapshots = connection.execute(
                "SELECT COUNT(*) AS count,MAX(revision) AS revision,MAX(step) AS step "
                "FROM state_snapshots"
            ).fetchone()
        return {
            "model_calls": int(usage["calls"]),
            "prompt_tokens": int(usage["prompt_tokens"]),
            "completion_tokens": int(usage["completion_tokens"]),
            "total_tokens": int(usage["total_tokens"]),
            "inference_seconds": round(float(usage["latency_seconds"]), 3),
            "state_revisions": int(snapshots["count"]),
            "current_revision": int(snapshots["revision"] or 0),
            "current_step": int(snapshots["step"] or 0),
            "events": {str(row["event_type"]): int(row["count"]) for row in events},
        }

    def latest_event(self) -> dict[str, Any] | None:
        with self.connection() as connection:
            row = connection.execute(
                "SELECT step,revision,event_type,payload_json,created_at FROM events "
                "ORDER BY event_id DESC LIMIT 1"
            ).fetchone()
        if row is None:
            return None
        return {
            "step": int(row["step"]),
            "revision": int(row["revision"]),
            "event_type": str(row["event_type"]),
            "payload": json.loads(row["payload_json"]),
            "created_at": str(row["created_at"]),
        }

    def _export(self, revision: int, step: int, state: AgentState) -> None:
        payload = {
            "revision": revision,
            "step": step,
            "state": state.model_dump(mode="json"),
        }
        with tempfile.NamedTemporaryFile(
            mode="w",
            encoding="utf-8",
            delete=False,
            dir=self.root,
            prefix=".current-",
            suffix=".json.tmp",
        ) as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            temporary = Path(handle.name)
        os.replace(temporary, self.export_path)
