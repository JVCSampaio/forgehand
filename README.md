<div align="center">
  <img src="docs/assets/forgehand.svg" alt="Forgehand" width="112" height="112">
  <h1>Forgehand</h1>
  <p><strong>Offload the work. Not the history.</strong></p>
  <p>Let Codex plan and review while one local model implements inside a bounded Git worktree.</p>

  [![CI](https://github.com/JVCSampaio/forgehand/actions/workflows/ci.yml/badge.svg)](https://github.com/JVCSampaio/forgehand/actions/workflows/ci.yml)
  [![Python](https://img.shields.io/badge/Python-3.11%2B-3776AB?logo=python&logoColor=white)](https://www.python.org/)
  [![MCP](https://img.shields.io/badge/MCP-stdio-6F42C1)](https://modelcontextprotocol.io/)
  [![License](https://img.shields.io/badge/License-MIT-2EA44F.svg)](LICENSE)
</div>

Forgehand is a small, model-agnostic MCP server for delegating complete coding
tasks to an OpenAI-compatible local model. Each step receives bounded current
state, deterministic repository facts, and only the latest observation — never
the accumulated chat transcript.

## Why

Cloud coding agents are excellent architects and reviewers. They are also an
expensive place to repeat file reads, compiler runs, failed tests, and mechanical
edits. Forgehand moves that inner loop to your machine and returns a compact
receipt with the patch, tests, token usage, and uncertainties.

```text
You → Codex → one task contract → Forgehand → one local model
          ↑                         │
          └──── compact receipt ────┘
```

## Quick start

Requirements: Python 3.11+, Git, Codex, and one local server exposing an
OpenAI-compatible `/v1/chat/completions` endpoint with structured JSON output.

```bash
python -m pip install "forgehand-local @ git+https://github.com/JVCSampaio/forgehand.git"
forgehand init
forgehand repo add /path/to/your/repository
forgehand doctor
codex mcp add forgehand -- forgehand mcp
```

The default example is Ornith 1.5 9B at `http://127.0.0.1:1234/v1`. Choose any
compatible local model during setup:

```bash
forgehand init --model your-model-id --worker-name "My local worker" --force
```

Then ask Codex:

> Use Forgehand to update the parser. Only modify `src/parser` and `tests/parser`.
> Run the approved parser tests, inspect the final diff, and review the result.

Codex can call four MCP tools: `forgehand_health`, `forgehand_delegate`,
`forgehand_tasks`, and `forgehand_result`.

Open the private, read-only dashboard at any time:

```bash
forgehand dashboard
```

It binds only to `127.0.0.1`, hides full repository paths, and reports measured
local-worker usage. It never presents those numbers as estimated Codex savings.

## What stays bounded

- exact Git roots must be registered by the user;
- every task runs in a detached worktree;
- the worker can access only declared repository-relative paths;
- commands are supervisor-provided `argv` arrays selected by ID, without a shell;
- token-like environment variables are removed from approved command processes;
- state, observation, output, steps, changed files, and retries have hard limits;
- full logs and diffs stay local; compact receipts return to the supervisor;
- Codex review is always required before integration.

Approved commands still inherit the host network stack and OS permissions. Only
approve commands you trust.

## Token evidence

In one same-contract microbenchmark, the original conversational worker loop used
25,826 local-worker tokens. Forgehand used 10,708 — **58.54% fewer** — while
producing the same one-file change. Forgehand was 5.52% slower in that run because
the worker needed several structured-output retries.

This is preliminary local-worker evidence, not a promise of 58.54% Codex, API,
credit, cost, or latency savings. See [Token accounting](docs/token-accounting.md).

## Design

Forgehand is inspired by the bounded-state execution described in
[SKILL.state](https://arxiv.org/abs/2608.26263). It adds coding-specific controls:
transactional SQLite revisions, typed state operations, deterministic Git facts,
scoped tools, worktree isolation, durable artifacts, and per-attempt usage.

History is archived, not attended.

- [Architecture](docs/architecture.md)
- [Configuration](docs/configuration.md)
- [Codex and MCP setup](docs/codex.md)
- [Security model](SECURITY.md)
- [Contributing](CONTRIBUTING.md)

Forgehand deliberately ships without self-evolving skills, multi-model routing,
an unrestricted shell, or automatic cloud fallback. Experimental learning belongs
in a separate optional project until it demonstrates net savings.

## Status

Forgehand is alpha software. Use it on repositories with version control, inspect
every patch, and rerun critical validation yourself.

## License and attribution

MIT licensed. Forgehand evolved from ideas and MIT-licensed work in
[RANJIANG23/codex-hermes-worker](https://github.com/RANJIANG23/codex-hermes-worker).
See [NOTICE](NOTICE) for attribution.
