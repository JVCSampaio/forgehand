# Task contracts and deterministic gates

Forgehand separates human-readable acceptance criteria from checks the runtime can
prove. Use `required_command_ids` for validation that must pass before the worker may
return `success`.

```json
{
  "repository_root": "/absolute/path/to/repository",
  "objective": "Fix the parser regression and add coverage.",
  "scope": ["src/parser", "tests/parser"],
  "constraints": ["Do not change the public API."],
  "acceptance_criteria": [
    "The regression is covered by a test.",
    "The parser test suite passes."
  ],
  "commands": [
    {
      "command_id": "parser-tests",
      "argv": ["python", "-m", "pytest", "tests/parser", "-q"],
      "cwd": ".",
      "timeout_seconds": 300
    }
  ],
  "required_command_ids": ["parser-tests"],
  "acknowledge_host_command_risk": true,
  "max_iterations": 12,
  "keep_worktree": true
}
```

The runtime rejects `success` when a required command is missing or its most recent
exit code is nonzero. `partial`, `needs_review`, and `blocked` remain available so a
worker can stop honestly without fabricating success.

## Host command boundary

`acknowledge_host_command_risk` is required whenever `commands` is non-empty. It is
an explicit consent gate, not a sandbox switch. Commands:

- are selected from supervisor-authored `argv` arrays and use `shell=False`;
- run in the detached worktree with interactive stdin disabled;
- receive a scrubbed environment with common credential channels removed;
- still inherit the user's OS permissions and host network stack.

Only approve deterministic build, lint, and test commands you already trust. Codex
must still inspect the patch and rerun critical checks before integration.
