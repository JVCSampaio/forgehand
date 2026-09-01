# Codex and MCP

Install Forgehand, initialize it, register at least one exact Git root, and verify
the worker before adding the stdio server:

```bash
forgehand init --model your-local-model-id
forgehand repo add /path/to/repository
forgehand doctor
codex mcp add forgehand -- forgehand mcp
codex mcp get forgehand
```

The equivalent Codex configuration is:

```toml
[mcp_servers.forgehand]
command = "forgehand"
args = ["mcp"]
```

Restart or open a new Codex session if the already-running client does not refresh
its MCP inventory.

## Delegation policy

Ask Codex to send a complete task rather than individual file operations. Every
contract should include exact mutable scope, constraints, acceptance criteria,
approved validation commands, and a step budget.

After completion, Codex should inspect the patch, review architecture-sensitive
changes, and rerun critical tests. A worker `success` field is not approval.

Official OpenAI documentation describes MCP as a supported tool integration for
model workflows: <https://developers.openai.com/>.
