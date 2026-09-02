from __future__ import annotations

import sqlite3
import subprocess
from pathlib import Path
from typing import Any


class RepositoryMemory:
    """Small, optional Git-revision-aware memory for personal Forgehand installs."""

    def __init__(self, path: Path):
        self.path = path
        self.path.parent.mkdir(parents=True, exist_ok=True)
        with sqlite3.connect(self.path) as db:
            db.execute(
                """CREATE TABLE IF NOT EXISTS facts (
                    id INTEGER PRIMARY KEY,
                    repository TEXT NOT NULL,
                    fact TEXT NOT NULL,
                    evidence_path TEXT NOT NULL,
                    source_revision TEXT NOT NULL,
                    confidence REAL NOT NULL,
                    invalidated_revision TEXT,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                )"""
            )

    @staticmethod
    def _is_ancestor(repository: Path, source: str, current: str) -> bool:
        if source == current:
            return True
        return (
            subprocess.run(
                ["git", "-C", str(repository), "merge-base", "--is-ancestor", source, current],
                stdin=subprocess.DEVNULL,
                capture_output=True,
                check=False,
            ).returncode
            == 0
        )

    def retrieve(
        self, repository: Path, revision: str, query: str, max_chars: int = 2400
    ) -> list[dict[str, Any]]:
        terms = [term.lower() for term in query.split() if len(term) >= 4][:8]
        with sqlite3.connect(self.path) as db:
            rows = db.execute(
                "SELECT fact,evidence_path,source_revision,confidence FROM facts "
                "WHERE repository=? AND invalidated_revision IS NULL ORDER BY confidence DESC",
                (str(repository.resolve()),),
            ).fetchall()
        result: list[dict[str, Any]] = []
        used = 0
        for fact, evidence, source, confidence in rows:
            if terms and not any(term in fact.lower() for term in terms):
                continue
            if not self._is_ancestor(repository, source, revision):
                continue
            item = {
                "fact": fact,
                "evidence": evidence,
                "source_revision": source,
                "confidence": confidence,
            }
            cost = len(str(item))
            if used + cost > max_chars:
                break
            result.append(item)
            used += cost
        return result

    def record(
        self,
        repository: Path,
        revision: str,
        fact: str,
        evidence_path: str,
        confidence: float,
    ) -> None:
        with sqlite3.connect(self.path) as db:
            db.execute(
                "INSERT INTO facts(repository,fact,evidence_path,source_revision,confidence) "
                "VALUES(?,?,?,?,?)",
                (str(repository.resolve()), fact, evidence_path, revision, confidence),
            )
