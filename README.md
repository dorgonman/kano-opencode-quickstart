# kano-opencode-quickstart

Standalone, copy-pasteable OpenCode server launcher + quickstart scripts.

## What’s inside

- `quickstart.sh`: auto-picks tailnet vs local.
- `scripts/opencode-server.sh`: start/stop OpenCode, optional Tailscale Serve exposure.
- `scripts/`: convenience wrappers (local, tailnet, basic-auth) + port utilities.
- `scripts/windows/`: Windows helpers (PowerShell + CMD), including a Tailscale Serve Windows Service wrapper.
- `.opencode/`: repo-local runtime folders (logs/pids) and optional repo-local OpenCode state.

## Modes

This repository supports two modes of operation:

### User Mode (Default)

For general users who want to use the official OpenCode release.

- Uses the `opencode` CLI installed on your system
- No source code required
- Automatic dependency management
- Recommended for most users

**Quick start:**
```bash
./quickstart.sh
```

### Developer Mode

For contributors who want to run OpenCode from source code.

- Runs OpenCode directly from `src/opencode` submodule
- Supports upstream synchronization
- Useful for testing changes and contributing
- Requires `bun` and git submodules

**Quick start:**
```bash
# First time: initialize submodules
git submodule update --init --recursive

# Run from source
./scripts/dev-mode/quickstart-dev.sh

# Update submodules and run
./scripts/dev-mode/quickstart-dev.sh -U

# Skip submodule sync
./scripts/dev-mode/quickstart-dev.sh -S

# Show help
./scripts/dev-mode/quickstart-dev.sh -h
```

**Developer Mode Options:**
- `-U, --update`: Fetch latest from upstream/origin and rebase current branch
- `-S, --skip-sync`: Skip syncing OpenCode/oh-my-opencode submodules
- `-h, --help`: Show help message

## Prereqs

### User Mode
- `opencode` CLI installed and on PATH
- `bun` installed and on PATH (OpenCode runtime)
- Optional: `tailscale` installed + signed in (only for tailnet mode)
- Windows Service mode:
  - Git for Windows (for `bash.exe`)
  - Optional: `nssm` (preferred), otherwise falls back to `sc.exe`

### Developer Mode (Additional)
- Git submodules initialized: `git submodule update --init --recursive`
- `bun` for running OpenCode from source


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

Runs tailnet mode if `tailscale` exists, otherwise runs local-only.

**First-time setup**: The script automatically detects if dependencies are not installed and runs `opencode-deps-install.sh` for you.

```bash
./quickstart.sh
```

**Subsequent runs**: Dependencies are already installed, server starts immediately. To update dependencies, run:

```bash
./scripts/opencode-deps-update.sh
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
- The agent will do: copy `quickstart.sh` + `scripts/`, and ensure `\.opencode/logs/` + `\.opencode/run/` + `\.opencode/node_modules/` are gitignored.
- Expected output: `<path>/quickstart.sh` and `<path>/scripts/opencode-server.sh` (plus updated `<path>/.gitignore`).
- Note: On first run, `quickstart.sh` automatically installs dependencies via `opencode-deps-install.sh`.

- Say this to your agent: “On Windows, set up the tailnet service for port 4096 and show me how to check logs.”
- The agent will do: run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\\windows\\tailnet-service.ps1 -Action bootstrap` and verify `tailscale serve status`.
- Expected output: a running Windows service (`opencode-tailnet`) and log files under `.opencode\\logs\\`.







