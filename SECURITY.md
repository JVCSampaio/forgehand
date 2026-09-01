# Security Policy

## Reporting

Please use GitHub Private Vulnerability Reporting. Do not open a public issue
containing credentials, private paths, exploit details, patches from private
repositories, or recovered data.

Include the affected version, smallest safe reproduction, expected and observed
behavior, and whether files, commands, credentials, or network access are involved.

## Trust model

- Only exact user-registered Git roots are accepted.
- Tasks run in detached worktrees.
- Worker file actions are limited to declared repository-relative scope.
- Commands are supervisor-authored argv arrays selected by ID and run without a shell.
- Host commands require explicit risk acknowledgement in the task contract.
- Required validation commands must all exit zero before `success` is accepted.
- Common credential-bearing environment variables and interactive credential prompts
  are removed from approved command environments.
- Approved executables still retain their normal OS permissions and host network stack.
- Forgehand is a capability-restricted executor, not an OS-level process sandbox.
- Worker output is untrusted until the supervisor reviews the patch and validation.
- Local model servers, MCP clients, Git, commands, and Forgehand are separate trust
  boundaries and should be updated independently.

Never commit configuration files containing private repository paths, `.env` files,
task databases, logs, patches, local model credentials, or private source artifacts.
