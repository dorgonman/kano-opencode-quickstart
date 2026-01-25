# SCRIPTS DIRECTORY

## OVERVIEW
This directory hosts Bash scripts for managing the OpenCode server lifecycle, including core server logic, mode-specific wrappers, port utilities, and dependency installers.

## WHERE TO LOOK

| **Script**            | **Purpose**                                                                 |
|-----------------------|-----------------------------------------------------------------------------|
| `opencode-server.sh`  | Core server logic: handles all server modes and Tailscale Serve integration |
| `start-server-*.sh`   | Convenience wrappers: delegate to `opencode-server.sh` with specific flags  |
| `kill-port.sh`        | Port cleanup utility: frees occupied ports                                 |
| `prerequisite.sh`     | Dependency installer for core OpenCode runtime                             |

### Key Details: `opencode-server.sh`
- **Structure**: 465 lines split into modular functions: `require_*`, `start_opencode`, `configure_tailscale_serve`, `stop_*`, `resolve_*`
- **Tailscale Serve Integration**: Configures HTTPS proxies for Tailnet-hosted OpenCode instances.
- **Cross-Platform Utilities**:
  - `resolve_bun_cmd()`, `resolve_tailscale_cmd()`: Detect paths for Bun and Tailscale.
  - `have_cmd()`, `is_loopback_host()`: Cross-platform checks useful across scripts.
- **PID Tracking**: Stores background server PIDs in `.opencode/run/opencode-serve.pid`.

### Key Details: `start-server-*.sh`
- **Wrapper Pattern**: Delegates to `opencode-server.sh` with flags for mode-specific behavior: `--local`, `--tailnet`, or `--auth`.

## CONVENTIONS

1. **Restart Semantics**
   - Always stop previous server instances before starting a new one.
   - Use `stop_*` functions in `opencode-server.sh`, which gracefully shut down OpenCode and reset Tailscale Serve configuration.

2. **Cross-Platform Adaptations**
   - For Windows port conflicts, `stop_opencode_on_port_if_any()` invokes a PowerShell script to kill `opencode.exe` processes.

## NOTES
- When adding new wrappers, follow the `start-server-*.sh` pattern to ensure consistent invocation of `opencode-server.sh`.
- Avoid hardcoding Bun/Tailscale paths—use the `resolve_*` helper functions provided.
- Do not use Windows service mode details here; see `scripts/windows/AGENTS.md` for specifics.
- Ensure `prerequisite.sh install` is run on first use to avoid missing dependencies.