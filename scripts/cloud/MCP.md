# REA STDIO MCP configuration for the prepared cloud filesystem

This configuration uses the already installed REA 6.7.0, Java JDK 21 and Ghidra
12.1.4. It installs nothing and changes no REA source or tool installation.

The repository's `.codex/config.toml` defines server `rea`. Its shell command
loads `/workspace/rea-tools/env.sh` for every MCP process, then replaces the shell
with the existing Node/REA MCP server. A missing activation file fails startup.
The paths require the existing prepared filesystem at `/workspace/rea` and
`/workspace/rea-tools`; cloning this repository alone does not install the tools.

## Supported clients

Codex CLI and other clients that honor Codex configuration can read the
project configuration in a trusted checkout. In a client with writable user
configuration, the equivalent registration is:

```bash
codex mcp add rea -- /bin/bash -c 'source /workspace/rea-tools/env.sh && exec node /workspace/rea/scripts/rea.mjs mcp'
```

Preserve existing entries when editing user configuration. Project config needs
a trusted project and a client restart/reload. Confirm both registration and an
actual tool call; `codex mcp list` by itself only confirms configuration discovery.

## Observations from the hosted session, 2026-10-21

- Normal `codex mcp list --json` returned `[]`, including from this checkout
  after the project configuration was added.
- `codex mcp add` could not persist the global registration because
  `/run/codex-environment/codex-home` is a read-only filesystem.
- An explicit command-line config override was accepted by the installed
  Codex CLI and listed enabled STDIO server `rea`. This validates config syntax,
  not access by the hosted chat.
- A separate STDIO protocol client using the exact launch command completed
  initialize (server `rea`, version `6.7.0`), listed 213 tools, and successfully
  called `binary_session`. No analysis target was opened.
- The installed REA `mcp doctor --json` and the bundled JavaScript SDK client
  failed with `Connection closed`. The raw STDIO test succeeded; SDK/client
  compatibility remains unverified. No dependencies or source were changed.
- The hosted chat did not acquire direct REA tools. This file and project config
  do not establish a working cloud integration or persistence in new sessions.

The hosted web runtime does not read local Codex config to add tools to the
conversation. It requires a supported host/plugin integration; there is no
custom STDIO registration/reload tool exposed in this session. Do not bypass
the read-only runtime configuration or report this checked-in config as a
successful hosted connection.

Official reference: https://developers.openai.com/codex/mcp
