# PROJECT KNOWLEDGE BASE - Scripts Directory

**Last Updated:** 2026-02-12  
**Structure Version:** 2.0 (Reorganized)

## OVERVIEW
Shell-based OpenCode server launcher with Tailscale support. Bash + PowerShell scripts for local/tailnet/LAN deployment, now organized by functionality.

## STRUCTURE
```
kano-opencode-quickstart/
├── start-native.sh            # Entry: auto-detects tailnet vs local
├── scripts/                   # Organized by functionality
│   ├── git/                   # Git workflow scripts (submodule management)
│   │   ├── setup-upstream.sh  # Configure upstream remotes
│   │   ├── sync-submodules.sh # Sync with upstream (merge)
│   │   └── rebase-submodules.sh # Rebase onto upstream
│   ├── user-mode/             # OpenCode server lifecycle
│   │   ├── opencode-server.sh # Core: start/stop/status + Tailscale Serve
│   │   ├── start-local.sh     # Localhost mode
│   │   ├── start-tailnet.sh   # Tailscale mode
│   │   ├── start-auth.sh      # LAN with basic auth
│   │   ├── stop.sh            # Stop server
│   │   └── status.sh          # Check status
│   ├── deps/                  # Dependency management
│   │   ├── prerequisite.sh    # Install dependencies (Bash)
│   │   └── prerequisite.ps1   # Install dependencies (PowerShell)
│   ├── utils/                 # Utility scripts
│   │   ├── kill-port.sh       # Free occupied ports
│   │   └── update-opencode.sh # Update OpenCode
│   ├── dev-mode/              # Development mode (run from source)
│   │   └── start-build-native.sh  # Run OpenCode from source
│   ├── windows/               # Windows-specific (service + PowerShell utils)
│   │   └── tailnet-service.ps1 # Windows service management
│   └── docs/                  # Documentation files
│       └── AGENTS.md          # This file
└── .opencode/                 # Runtime: logs/pids/node_modules (gitignored)
    ├── package.json           # Repo-local OpenCode plugin deps
    ├── logs/                  # Server stdout/stderr
    └── run/                   # PID files
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Start server (auto) | `start-native.sh` | Tailscale if available, else localhost |
| Start server (manual) | `scripts/user-mode/start-*.sh` | Local/tailnet/auth modes |
| Core server logic | `scripts/user-mode/opencode-server.sh` | 465 lines, handles all modes + Tailscale Serve |
| Git workflows | `scripts/git/*.sh` | Submodule sync/rebase with upstream |
| Setup dependencies | `scripts/deps/prerequisite.{sh,ps1}` | First-run: install .opencode/node_modules |
| Development mode | `scripts/dev-mode/start-build-native.sh` | Run OpenCode from source |
| Port conflicts (Unix) | `scripts/utils/kill-port.sh` | Unix port cleanup |
| Port conflicts (Windows) | `scripts/windows/kill-port.ps1` | PowerShell port cleanup |
| Windows service | `scripts/windows/tailnet-service.ps1` | NSSM/sc.exe wrapper (experimental) |
| Logs | `.opencode/logs/opencode-{stdout,stderr}.log` | Server output (created at runtime) |

## CONVENTIONS

**Bash scripts:**
- `set -euo pipefail` (strict mode)
- `SCRIPT_DIR` via `$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)`
- Helper functions: `have_cmd()`, `is_loopback_host()`, `resolve_*_cmd()` (cross-platform path resolution)

**PowerShell scripts:**
- Run with: `powershell -NoProfile -ExecutionPolicy Bypass -File <script>.ps1`
- Elevated prompt required for service operations

**Repo-local isolation:**
- Set `OPENCODE_REPO_LOCAL=1` to use `.opencode/` for config/state (default: global config)
- When enabled, sets `OPENCODE_HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_CACHE_HOME`

**PID tracking:**
- `.opencode/run/opencode-serve.pid` stores background server PID
- Restart semantics: always stop previous instance before starting

## ANTI-PATTERNS (THIS PROJECT)

**DO NOT:**
- Commit `.opencode/logs/`, `.opencode/run/`, `.opencode/node_modules/` (gitignored for runtime)
- Run Windows service mode in production (experimental: buggy stop behavior)
- Bind to `0.0.0.0` without basic auth (scripts enforce `AUTH_MODE=basic` for non-loopback hosts)
- Use `--service` flag outside systemd/Windows Service context (keeps launcher alive to trap signals)

**NEVER:**
- Skip `./scripts/deps/prerequisite.sh install` on first run (missing node_modules breaks OpenCode UI)
- Hardcode Bun/Tailscale paths (use `resolve_bun_cmd()`, `resolve_tailscale_cmd()`)

## UNIQUE STYLES

**Cross-platform path resolution:**
- `resolve_bun_cmd()` checks: `$PATH` → `$BUN_INSTALL` → `$USERPROFILE\.bun\bin\bun.exe` → `/c/Users/$USERNAME/.bun/bin/bun.exe`
- `resolve_tailscale_cmd()` checks: `$PATH` → `/c/Program Files/Tailscale/tailscale.exe`
- Git Bash (`cygpath -u`) conversion for Windows paths

**Tailscale Serve integration:**
- `tailscale serve --bg --https=$TS_HTTPS_PORT localhost:$PORT` (defaults: 8443)
- Always reset before reconfigure: `tailscale serve reset`
- Diagnostics: `tailscale serve status`

**Windows-specific quirks:**
- Service defaults: `Port=5096`, `TsHttpsPort=9443` (not 4096/8443 due to legacy conflicts)
- NSSM installs with `AppKillProcessTree=1` (kills child `opencode.exe` on service stop)
- Fallback: `sc.exe` if NSSM missing (no process tree cleanup)

## COMMANDS

```bash
# First run (install dependencies)
./scripts/deps/prerequisite.sh install

# Auto mode (recommended)
./start-native.sh

# Local only (no auth, localhost:4096)
./scripts/user-mode/start-local.sh
opencode attach localhost:4096

# Tailnet only (Tailscale required)
./scripts/user-mode/start-tailnet.sh
tailscale serve status

# LAN with basic auth
export OPENCODE_SERVER_PASSWORD='change-me'
./scripts/user-mode/start-auth.sh --port 4096

# Stop server + reset Tailscale Serve
./scripts/user-mode/stop.sh

# Check status
./scripts/user-mode/status.sh

# Git workflows (submodule management)
./scripts/git/setup-upstream.sh      # Setup upstream remotes (once)
./scripts/git/sync-submodules.sh     # Sync with upstream (merge)
./scripts/git/rebase-submodules.sh   # Rebase onto upstream

# Development mode (run from source)
./scripts/dev-mode/start-build-native.sh -U  # Sync and run
./scripts/dev-mode/start-build-native.sh -R  # Rebase and run
```

**Windows PowerShell:**
```powershell
# First run (install dependencies)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\deps\prerequisite.ps1 -Action install

# Service mode (elevated prompt, experimental)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\tailnet-service.ps1 -Action bootstrap

# Check service
sc.exe query opencode-tailnet
tailscale serve status

# Logs
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\tailnet-service.ps1 -Action logs

# Diagnose Tailscale Serve issues
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\windows\tailnet-service.ps1 -Action diagnose
```

## NOTES

**Known issues:**
- Windows service stop leaves orphaned `opencode.exe`/`bun` processes (2026-01-25)
- Service port defaults (5096/9443) sometimes revert to 4096/8443 (under investigation)

**Bun requirement:**
- OpenCode UI plugins need Bun for asset installation
- Missing Bun → browser shows `BunInstallFailedError`

**Port conflicts:**
- Windows: `stop_opencode_on_port_if_any()` auto-kills `opencode.exe` on restart
- Unix: manual cleanup via `scripts/utils/kill-port.sh`

**Auth enforcement:**
- `--host 0.0.0.0` → forces `AUTH_MODE=basic` (requires `$OPENCODE_SERVER_PASSWORD`)
- `--host 127.0.0.1` → defaults to `AUTH_MODE=none`
- `--tailnet` → requires loopback host, implies `--bg`

## DIRECTORY REORGANIZATION (v2.0)

The scripts directory was reorganized on 2026-02-12 for better maintainability:

**Old paths → New paths:**
- `scripts/git-*.sh` → `scripts/git/*.sh`
- `scripts/start-server-*.sh` → `scripts/user-mode/start-*.sh`
- `scripts/prerequisite.*` → `scripts/deps/prerequisite.*`
- `scripts/kill-port.sh` → `scripts/utils/kill-port.sh`
- `scripts/*.md` → `scripts/docs/*.md`

See [MIGRATION-PATHS.md](../MIGRATION-PATHS.md) for complete migration guide.

## SEE ALSO

- [scripts/README.md](../README.md) - Main scripts documentation
- [scripts/STRUCTURE.md](../STRUCTURE.md) - Detailed directory structure
- [scripts/git/README.md](../git/README.md) - Git workflows guide
- [scripts/MIGRATION-PATHS.md](../MIGRATION-PATHS.md) - Path migration guide
