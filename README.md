# kano-opencode-quickstart

Standalone, copy-pasteable OpenCode server launcher + quickstart scripts.

## What’s inside

- `scripts/opencode-server.sh`: start/stop OpenCode, optional Tailscale Serve exposure.
- `scripts/`: convenience wrappers (local, tailnet, basic-auth) + port utilities.
- `scripts/windows/`: Windows helpers (PowerShell + CMD), including a Tailscale Serve Windows Service wrapper.

## Prereqs

- `opencode` CLI installed and on PATH
- `bun` installed and on PATH (OpenCode runtime)
- Optional: `tailscale` installed + signed in (only for `--tailnet` mode)
- Windows Service mode:
  - Git for Windows (for `bash.exe`)
  - Optional: `nssm` (preferred), otherwise falls back to `sc.exe`

## Quick start

### Local only (no auth)

Run in Git Bash / WSL:

```bash
./scripts/start-server-local.sh
```

Then connect your client:

```bash
opencode attach localhost:4096
```

### Tailnet only (recommended)

Run in Git Bash / WSL:

```bash
./scripts/start-server-tailnet.sh
```

Check the URL:

```bash
tailscale serve status
```

### LAN (basic auth)

```bash
export OPENCODE_SERVER_PASSWORD='change-me'
./scripts/start-server-auth.sh --port 4096
```

## Windows: run as a service (tailnet)

From an elevated terminal (or double-click the CMD which self-elevates):

```bat
scripts\\windows\\tailnet-service.cmd bootstrap
```

## Use this repo in another repo

- Copy the `scripts/` folder into the target repo root.
- Or add this repo as a submodule and symlink/copy `scripts/` as needed.

## “Say this to your agent”

- “Copy `scripts/` from `kano-opencode-quickstart` into my repo `<path>` and make sure `.opencode/logs/` and `.opencode/run/` are gitignored.”
- “On Windows, set up the tailnet service for port 4096 and show me how to check logs.”