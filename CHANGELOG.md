# Changelog

All notable changes will be documented here. Forgehand follows
[Semantic Versioning](https://semver.org/).

## 0.3.7 - 2026-09-02

- Added deterministic Recovery Mode after consecutive rejected actions.
- Recovery requires a bounded reread before allowing one constrained repair.
- Added failure classification and compact recovery capsules to worker context.

## 0.3.6 - 2026-09-02

- Added an explicit `repair` workflow phase after failed validation.
- Compressed failed-command output into a bounded failure delta for worker context.
- Included compact failure evidence in receipts and preserved deterministic tree validation.

## 0.2.3 - 2026-09-01

- Accepted the common `complete` completion-status alias from small local models,
  preventing repeated invalid retries after a valid task result.

## 0.2.2 - 2026-09-01

- Bound required-command evidence to a compact fingerprint of the exact Git-visible
  repository state validated by each command.
- Reject stale successful validation after tracked, staged, deleted, renamed, or
  untracked non-ignored changes; ignored outputs remain excluded.
- Surface stale command IDs in compact receipts and distinguish stale gates in the
  local dashboard.

## 0.2.1 - 2026-09-01

- Made deterministic gate enforcement explicit in runtime facts and receipts so small
  workers do not confuse an empty per-task requirement list with an absent capability.

## 0.2.0 - 2026-09-01

- Added deterministic required-command gates: `success` is impossible until every
  required command has run and exited zero.
- Required explicit acknowledgement that approved commands inherit host permissions
  and network access.
- Added compact command evidence and gate state to task receipts.
- Added bounded multi-file reads to reduce repeated contract and inference overhead.
- Expanded command-environment credential scrubbing and disabled interactive Git prompts.
- Corrected MCP open-world and security metadata to state that no OS sandbox exists.

## 0.1.1 - 2026-09-01

- Reduced repeated observation actions for smaller local workers.
- Normalized safe numeric and completion argument variants from structured output.
- Added bounded sampling controls with coding-oriented defaults.
- Raised the default bounded task budget from 8 to 10 iterations.

## 0.1.0 - 2026-09-01

- Initial public alpha.
- Bounded state-centric worker loop with transactional SQLite state.
- Git worktree isolation, exact path scope, and approved argv commands.
- OpenAI-compatible local worker configuration.
- Codex-compatible stdio MCP server and compact task receipts.
- Per-attempt token accounting and preliminary paired benchmark evidence.
