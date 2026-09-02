# Architecture

Forgehand is a state-centric executor between a frontier supervisor and one local
worker model.

```text
Codex
  │ immutable task contract
  ▼
Forgehand task runner
  │ detached Git worktree
  ▼
Context projector
  ├─ immutable worker skill
  ├─ task contract
  ├─ bounded semantic state
  ├─ deterministic runtime facts
  └─ latest bounded observation
  │
  ▼
One stateless model call → one typed action → validation → transaction
  │
  └─ repeat until complete or the budget is exhausted
```

## State is not history

The worker maintains only semantic state needed for the next decision: phase,
goal, hypotheses, decisions, blockers, artifact references, and next intent. Git
status, command exits, and changed files are recomputed by the runtime.

Each valid action produces an immutable artifact. SQLite/WAL stores usage, events,
and state snapshots. Old events are available for audit but are never automatically
inserted into the next prompt.

## One worker

An installation has one endpoint and model ID. Forgehand has no model router or
fallback provider. This keeps GPU use, behavior, and accounting predictable.

## Trust boundary

The worker proposes actions; Forgehand validates and executes them. A model claim
is never evidence. Git, filesystem checks, command exit codes, diffs, and tests are
the evidence returned for supervisor review.

Natural-language acceptance criteria guide the worker and reviewer. Deterministic
acceptance gates are expressed as `required_command_ids`: every named command must
have run, exited zero, and validated the current Git-visible repository state before
Forgehand permits a `success` completion. Compact hashes make later tracked or
untracked changes stale without sending diffs back through the model context. This
gate does not replace final supervisor review.

File capabilities are enforced inside the detached worktree. Process execution is a
separate trust boundary: approved commands use `shell=False` and a scrubbed environment,
but retain host OS permissions and network access. Forgehand does not claim an OS sandbox.
