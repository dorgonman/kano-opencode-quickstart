# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-26 00:14:01 +08:00
**Commit:** 2b60810
**Branch:** main

## OVERVIEW
Shell-based OpenCode server launcher with Tailscale support. Bash + PowerShell scripts for local/tailnet/LAN deployment.

## STRUCTURE
```
kano-opencode-quickstart/
├── start-native.sh            # Entry: auto-detects tailnet vs local
├── scripts/                   # Server lifecycle + port utils
│   ├── opencode-server.sh     # Core: start/stop/status OpenCode + Tailscale Serve
│   ├── start-server-*.sh      # Wrappers: local/tailnet/auth modes
│   ├── prerequisite.{sh,ps1}  # Setup: install .opencode/package.json deps
│   ├── kill-port.sh           # Util: free occupied ports
│   └── windows/               # Windows-specific (service + PowerShell utils)
└── .opencode/                 # Runtime: logs/pids/node_modules (gitignored)
    ├── package.json           # Repo-local OpenCode plugin deps
    ├── logs/                  # Server stdout/stderr
    └── run/                   # PID files
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Start server (auto) | `start-native.sh` | Tailscale if available, else localhost |
| Start server (manual) | `scripts/start-server-*.sh` | Local/tailnet/auth modes |
| Core server logic | `scripts/opencode-server.sh` | 465 lines, handles all modes + Tailscale Serve |
| Windows service | `scripts/windows/tailnet-service.ps1` | NSSM/sc.exe wrapper (experimental) |
| Port conflicts | `scripts/kill-port.sh` | Unix port cleanup |
| Windows port conflicts | `scripts/windows/kill-port.ps1` | PowerShell port cleanup |
| Setup dependencies | `scripts/prerequisite.{sh,ps1}` | First-run: install .opencode/node_modules |
| Logs | `.opencode/logs/opencode-{stdout,stderr}.log` | Server output (created at runtime) |

## CONVENTIONS

**Bash scripts:**
- `set -euo pipefail` (strict mode)
- `SCRIPT_DIR` via `$(cd "$(dirname "${BASH_SOURCE[0]}") && pwd -P)`
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
- Run Windows service mode in production (experimental: buggy stop behavior, see README line 69-73)
- Bind to `0.0.0.0` without basic auth (scripts enforce `AUTH_MODE=basic` for non-loopback hosts)
- Use `--service` flag outside systemd/Windows Service context (keeps launcher alive to trap signals)

**NEVER:**
- Skip `./scripts/prerequisite.sh install` on first run (missing node_modules breaks OpenCode UI)
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
./scripts/prerequisite.sh install

# Auto mode (recommended)
./start-native.sh

# Local only (no auth, localhost:4096)
./scripts/start-server-local.sh
opencode attach localhost:4096

# Tailnet only (Tailscale required)
./scripts/start-server-tailnet.sh
tailscale serve status

# LAN with basic auth
export OPENCODE_SERVER_PASSWORD='change-me'
./scripts/start-server-auth.sh --port 4096

# Stop server + reset Tailscale Serve
./scripts/stop.sh

# Check status
./scripts/status.sh
```

**Windows PowerShell:**
```powershell
# First run (install dependencies)
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\prerequisite.ps1 -Action install

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
- Windows service stop leaves orphaned `opencode.exe`/`bun` processes (2026-01-25, line 70)
- Service port defaults (5096/9443) sometimes revert to 4096/8443 (under investigation)

**Bun requirement:**
- OpenCode UI plugins need Bun for asset installation
- Missing Bun → browser shows `BunInstallFailedError`

**Port conflicts:**
- Windows: `stop_opencode_on_port_if_any()` auto-kills `opencode.exe` on restart
- Unix: manual cleanup via `scripts/kill-port.sh`

**Auth enforcement:**
- `--host 0.0.0.0` → forces `AUTH_MODE=basic` (requires `$OPENCODE_SERVER_PASSWORD`)
- `--host 127.0.0.1` → defaults to `AUTH_MODE=none`
- `--tailnet` → requires loopback host, implies `--bg`
