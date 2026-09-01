# Changelog

All notable changes will be documented here. Forgehand follows
[Semantic Versioning](https://semver.org/).

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
