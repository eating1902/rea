# Codex Cloud setup for eating1902/rea

This explicitly requested environment setup installs only missing prerequisites
outside the checkout. It does not change REA source, manifests or lockfiles.
It targets Linux x86_64, REA 6.7.0, Node 24.18.0, npm 11.16.0,
Temurin JDK 21.0.12.1+1 and Ghidra 12.1.4. Downloads use HTTPS and pinned SHA-256
checksums; archives are temporary and are never committed. Existing installations
with matching provenance markers are reused and checked with REA doctor.

Run from the existing isolated checkout; do not create a Git worktree unless
explicitly requested:

```bash
bash /workspace/rea/scripts/cloud/setup.sh
```

To validate without installing anything:

```bash
bash /workspace/rea/scripts/cloud/setup.sh --check
```

The check performs real version, dependency and Ghidra readiness checks. It does
not download archives or install dependencies. A missing or incompatible
prerequisite makes it fail. Do not use an archive marker alone as a health check;
it records the originally verified download, not a checksum of the installed tree.

## Cloud configuration

Select a repository ref containing this script. Set the cloud installation script
to the following, which preserves the setup exit status and retains its output
outside the repository:

```bash
#!/usr/bin/env bash
set -euo pipefail
mkdir -p /workspace/rea-tools
bash /workspace/rea/scripts/cloud/setup.sh 2>&1 | tee -a /workspace/rea-tools/setup.log
```

Saving that configuration does not execute it. Execute and validate setup on the
preparation machine before publishing its filesystem snapshot. New tasks can
restore that snapshot without running installation again. Only a fresh-task
check establishes restoration; configuration revision and a running phase alone
do not prove installation succeeded. The log contains UTC start/end timestamps;
a missing success line or nonzero setup result needs investigation.

For new task shells and MCP subprocesses, load:

```bash
source /workspace/rea-tools/env.sh
cd /workspace/rea
```

This sets `JAVA_HOME=/workspace/rea-tools/jdk-21.0.12.1+1`,
`GHIDRA_INSTALL_DIR=/workspace/rea-tools/ghidra_12.1.4_PUBLIC`, the pinned Node/JDK
PATH, npm cache and `HUSKY=0`. Exports in the installation process do not persist
into future processes. Never silently skip a missing activation file.

REA's MCP server is stdio-based and must be launched by its client:

```bash
source /workspace/rea-tools/env.sh
cd /workspace/rea
exec node scripts/rea.mjs mcp
```

Start instructions alone do not register an MCP server. Configure the host MCP
client separately; do not assume a managed Codex runtime honors a user config or
preserves its registration. Validate initialize and tools/list from the client.
Do not start a detached background stdio server during installation.

## Validation scope

The pinned downloads and checksums, Java/javac, REA Ghidra doctor and a real
Ghidra analysis of `/usr/bin/true` were validated in the preparation session.
The committed script is checked against the existing installation without
reinstallation. A fresh installation by this script and restoration into a new
cloud task must be verified separately. Other native providers are not installed.
