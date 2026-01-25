# WINDOWS SCRIPTS

## OVERVIEW
Windows-specific service wrapper for deploying OpenCode with Tailscale Serve via NSSM or sc.exe (experimental).

## WHERE TO LOOK

| File | Purpose |
|------|---------|
| `tailnet-service.ps1` | Service lifecycle: bootstrap, start, stop, restart, logs, diagnose |
| `kill-port.ps1` | Port cleanup: frees occupied ports |
| `tailnet-service-register.cmd` | Elevated wrapper: registers service |
| `tailnet-service-unregister.cmd` | Elevated wrapper: unregisters service |

## ANTI-PATTERNS (Windows-specific)

**DO NOT:**
- Use `sc.exe` if NSSM available (sc.exe doesn't cleanup child processes)
- Rely on default ports without explicit `-Port`/`-TsHttpsPort` (unstable, may revert to 4096/8443)
- Run in production (experimental: buggy stop behavior)

**NEVER:**
- Skip elevated prompt for service operations (bootstrap/register/unregister require admin)
- Ignore orphaned processes after service stop (known bug: opencode.exe/bun remain running)

## NOTES

**Known bugs (2026-01-25):**
- Service stop leaves orphaned `opencode.exe`/`bun` processes
- Port defaults sometimes revert from 5096/9443 to 4096/8443

**NSSM vs sc.exe:**
- NSSM: `AppKillProcessTree=1` (kills child processes on stop)
- sc.exe fallback: no process tree cleanup

**Service defaults:**
- Port: 5096 (not 4096 due to legacy conflicts)
- TsHttpsPort: 9443 (not 8443)
- Logs: `.opencode/logs/`

**CMD wrappers:**
- Auto-elevate when run from non-admin context
- Invoke `tailnet-service.ps1` with appropriate action
