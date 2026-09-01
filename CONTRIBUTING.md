# Contributing

Thank you for helping make local coding agents safer and more efficient.

## Before opening a change

- Use an issue for features that change the protocol, trust boundary, or public API.
- Keep one pull request focused on one problem.
- Do not include private repositories, prompts, logs, credentials, or model traces.
- Add deterministic tests for behavior changes.
- Do not add automatic cloud fallbacks, unrestricted shell access, or self-evolving
  production skills without prior design discussion and benchmark evidence.

## Development

```bash
python -m venv .venv
python -m pip install -e ".[dev]"
ruff check .
ruff format --check .
pytest -q
python -m build
```

Live worker tests must be opt-in and must never run in the default CI suite.

By contributing, you agree that your contribution is licensed under MIT.
