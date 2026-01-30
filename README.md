# kano-opencode-quickstart

Standalone, copy-pasteable OpenCode server launcher + quickstart scripts.

## What’s inside

- `quickstart.sh`: auto-picks tailnet vs local.
- `scripts/opencode-server.sh`: start/stop OpenCode, optional Tailscale Serve exposure.
- `scripts/`: convenience wrappers (local, tailnet, basic-auth) + port utilities.
- `scripts/windows/`: Windows helpers (PowerShell + CMD), including a Tailscale Serve Windows Service wrapper.
- `.opencode/`: repo-local runtime folders (logs/pids) and optional repo-local OpenCode state.

## Prereqs

- `opencode` CLI installed and on PATH
- `bun` installed and on PATH (OpenCode runtime)
- Optional: `tailscale` installed + signed in (only for tailnet mode)
- Windows Service mode:
  - Git for Windows (for `bash.exe`)
  - Optional: `nssm` (preferred), otherwise falls back to `sc.exe`


## Dependency Management

### First-time setup (install)

Installs repo-local OpenCode plugin dependencies from `.opencode/package.json` at specified versions.

```bash
# Using wrapper script (recommended)
./scripts/opencode-deps-install.sh

# Or using manager directly
./scripts/opencode-deps-manager.sh install
```

Windows PowerShell:

```powershell
# Using wrapper script (recommended)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-install.ps1

# Or using manager directly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action install
```

### Update to latest versions

Updates OpenCode CLI, oh-my-opencode, and all repo-local plugin dependencies to their latest versions.

```bash
# Using wrapper script (recommended)
./scripts/opencode-deps-update.sh

# Or using manager directly
./scripts/opencode-deps-manager.sh update

# Dry-run (preview what would be updated)
./scripts/opencode-deps-update.sh --dry-run
```

Windows PowerShell:

```powershell
# Using wrapper script (recommended)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-update.ps1

# Or using manager directly
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action update

# Dry-run
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-update.ps1 -DryRun
```

### Check status

View current environment and dependency versions.

```bash
./scripts/opencode-deps-manager.sh status
```

Windows PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\opencode-deps-manager.ps1 -Action status
```
## Quick start

### Recommended (auto)

Runs tailnet mode if `tailscale` exists, otherwise runs local-only:

```bash
./quickstart.sh
```

### Local only (no auth)

```bash
./scripts/start-server-local.sh
opencode attach localhost:4096
```

### Tailnet only (recommended when available)

```bash
./scripts/start-server-tailnet.sh
tailscale serve status
```

### LAN (basic auth)

```bash
export OPENCODE_SERVER_PASSWORD='change-me'
./scripts/start-server-auth.sh --port 4096
```

## Windows: run as a service (tailnet)

> Known issues (2026-01-25):
> - Windows service mode is still buggy: stopping the service may leave `opencode.exe`/`bun` running in the background.
> - The service defaults should be `Port=5096` and `TsHttpsPort=9443`, but some installs still end up using `4096/8443`.
> - Root cause is still under investigation; treat service mode as experimental.
>
> Recommendation: use `./quickstart.sh` (interactive) for now.
Defaults: `Port=5096`, `TsHttpsPort=9443` (override with `-Port` / `-TsHttpsPort`).\nNote: When installed via `nssm`, the service is configured with `AppKillProcessTree=1` so stopping the service also stops the `opencode` child process (no lingering background server).

From an elevated PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\tailnet-service.ps1 -Action bootstrap
```

Check status:

```powershell
tailscale serve status
sc.exe query opencode-tailnet
```

Logs:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\tailnet-service.ps1 -Action logs
```

If Tailscale Serve looks stuck:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\tailnet-service.ps1 -Action diagnose
```\n## Use this repo in another repo

- Copy `quickstart.sh` and `scripts/` into the target repo root.
- Also copy `.opencode/` if you want repo-local logs/pids.

## “Say this to your agent”

- Say this to your agent: “Install `kano-opencode-quickstart` into my repo at `<path>`; I want `./quickstart.sh` at repo root and the `scripts/` folder.”
- The agent will do: copy `quickstart.sh` + `scripts/`, run `./scripts/opencode-deps-install.sh` once, and ensure `\.opencode/logs/` + `\.opencode/run/` + `\.opencode/node_modules/` are gitignored.
- Expected output: `<path>/quickstart.sh` and `<path>/scripts/opencode-server.sh` (plus updated `<path>/.gitignore`).

- Say this to your agent: “On Windows, set up the tailnet service for port 4096 and show me how to check logs.”
- The agent will do: run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\windows\\tailnet-service.ps1 -Action bootstrap` and verify `tailscale serve status`.
- Expected output: a running Windows service (`opencode-tailnet`) and log files under `.opencode\\logs\\`.







