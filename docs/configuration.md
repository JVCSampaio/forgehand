# Configuration

`forgehand init` creates the platform-appropriate user configuration:

- Windows: `%APPDATA%\Forgehand\config.yaml`
- Linux/macOS: `${XDG_CONFIG_HOME:-~/.config}/forgehand/config.yaml`

Set `FORGEHAND_CONFIG` to use another file.

```yaml
worker:
  name: Ornith 1.5 9B
  model: ornith-ai/Ornith-1.5-9B
  base_url: http://127.0.0.1:1234/v1
  api_key_env: FORGEHAND_API_KEY

repo_tasks:
  roots:
    - /absolute/path/to/repository
  worktree_root: /absolute/path/to/forgehand/tasks
  max_steps: 50
  max_file_chars: 120000
  max_changed_files: 80
  max_command_output_chars: 20000
  retain_worktrees: true

forgehand:
  enabled: true
  max_steps: 50
  max_state_chars: 12288
  max_observation_chars: 12000
  max_context_chars: 32000
  max_output_tokens: 1400
  reasoning_effort: none
  inference_timeout_seconds: 240
  invalid_output_retries: 2
```

Environment overrides:

| Variable | Meaning |
| --- | --- |
| `FORGEHAND_CONFIG` | configuration path |
| `FORGEHAND_WORKER_NAME` | display name |
| `FORGEHAND_MODEL` | endpoint model ID |
| `FORGEHAND_BASE_URL` | OpenAI-compatible `/v1` base URL |
| `FORGEHAND_API_KEY_ENV` | name of the variable containing the secret |

Loopback endpoints may run without a key. Remote endpoints require the configured
secret environment variable and should use HTTPS.
