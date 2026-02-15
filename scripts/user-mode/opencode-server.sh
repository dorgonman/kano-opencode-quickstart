#!/usr/bin/env bash
set -euo pipefail
# set -x # Enable debug tracing to echo all commands


# ------------------------------------------------------------------------------
# oc-kano-backlog-server
# Start/stop an OpenCode server for this repo (optionally exposed via Tailscale Serve).
#
# Quickstarts live under: scripts/
# ------------------------------------------------------------------------------

HOST="127.0.0.1"
PORT="4096"
AUTH_MODE="auto" # auto|basic|none
PASSWORD_ENV="OPENCODE_SERVER_PASSWORD"

WORKSPACE=""

TAILNET="0"
TS_HTTPS_PORT="8443"
BG="0"
SERVICE="0"
STOP="0"
STATUS="0"
KILL_PORT_LISTENERS="1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
SHARED_LIB="${SCRIPT_DIR}/../shared/server-common.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "ERROR: shared server library not found: $SHARED_LIB" >&2
  exit 2
fi

source "$SHARED_LIB"

usage() {
  cat <<EOF
Usage:
  $(basename "$0") [options]
  $(basename "$0") --tailnet [options]
  $(basename "$0") --stop
  $(basename "$0") --status

Options:
  --workspace <dir>  Use this directory as the workspace root (opencode serve CWD).
  --host <ip>         Bind OpenCode to this host (default: 127.0.0.1).
  --port <port>       Bind OpenCode to this port (default: 4096).
  --kill-port-listeners  Kill any process listening on <port> before starting (DANGEROUS).
  --no-kill-port-listeners  Do not kill listeners (fails if <port> in use).
  --auth <mode>       auto|basic|none (default: auto).
  --password-env <E>  Password env var used for basic auth (default: OPENCODE_SERVER_PASSWORD).

  --bg                Run OpenCode in background (pid: .opencode/run/opencode-serve.pid).
  --service           Keep the launcher process alive (for systemd/Windows service usage).
  --tailnet           Expose localhost:<port> via 'tailscale serve' within your tailnet.
                      Implies --bg (except with --service) and requires --host 127.0.0.1/localhost.
  --ts-https <port>   Tailscale HTTPS port (default: 8443).

  --stop              Stop background OpenCode server and reset tailscale serve.
  --status            Show tailscale serve status.

Examples:
  # Local-only (no auth, safe default)
  $(basename "$0")

  # Tailnet-only access (recommended)
  $(basename "$0") --tailnet --port 4096

  # LAN access (requires basic auth)
  $(basename "$0") --host 0.0.0.0 --auth basic --port 4096
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workspace) WORKSPACE="${2:-}"; [[ -n "$WORKSPACE" ]] || { echo "ERROR: --workspace requires a value." >&2; exit 2; }; shift 2;;
    --host) HOST="${2:-}"; [[ -n "$HOST" ]] || { echo "ERROR: --host requires a value." >&2; exit 2; }; shift 2;;
    --port) PORT="${2:-}"; [[ -n "$PORT" ]] || { echo "ERROR: --port requires a value." >&2; exit 2; }; shift 2;;
    --kill-port-listeners|--kill-port|--force-port) KILL_PORT_LISTENERS="1"; shift;;
    --no-kill-port-listeners) KILL_PORT_LISTENERS="0"; shift;;
    --auth) AUTH_MODE="${2:-}"; [[ -n "$AUTH_MODE" ]] || { echo "ERROR: --auth requires a value." >&2; exit 2; }; shift 2;;
    --no-auth) AUTH_MODE="none"; shift;;
    --password-env) PASSWORD_ENV="${2:-}"; [[ -n "$PASSWORD_ENV" ]] || { echo "ERROR: --password-env requires a value." >&2; exit 2; }; shift 2;;
    --bg) BG="1"; shift;;
    --service) SERVICE="1"; shift;;
    --tailnet) TAILNET="1"; shift;;
    --ts-https) TS_HTTPS_PORT="${2:-}"; [[ -n "$TS_HTTPS_PORT" ]] || { echo "ERROR: --ts-https requires a value." >&2; exit 2; }; shift 2;;
    --stop) STOP="1"; shift;;
    --status) STATUS="1"; shift;;
    -h|--help) usage; exit 0;;
    *) echo "ERROR: Unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
done

resolve_repo_root() {
  local script_path="${BASH_SOURCE[0]}"
  if have_cmd realpath; then
    script_path="$(realpath "$script_path")"
  elif have_cmd python3; then
    script_path="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$script_path")"
  fi

  local script_dir
  script_dir="$(cd "$(dirname "$script_path")" && pwd -P)"
  printf "%s\n" "$(cd "$script_dir/../.." && pwd -P)"
}

REPO_ROOT="$(resolve_repo_root)"
if [[ ! -d "$REPO_ROOT/.opencode" ]]; then
  echo "ERROR: Cannot find repo root (.opencode missing): $REPO_ROOT" >&2
  exit 2
fi

# Default: use global OpenCode config/state so models/plugins apply to all repos.
# Opt-in to repo-local isolation by setting OPENCODE_REPO_LOCAL=1 (or by exporting XDG_*/OPENCODE_HOME).
if [[ "${OPENCODE_REPO_LOCAL:-}" == "1" ]]; then
  : "${OPENCODE_HOME:="${REPO_ROOT}/.opencode"}"
  : "${XDG_CONFIG_HOME:="${REPO_ROOT}/.opencode/xdg/config"}"
  : "${XDG_DATA_HOME:="${REPO_ROOT}/.opencode/xdg/data"}"
  : "${XDG_CACHE_HOME:="${REPO_ROOT}/.opencode/xdg/cache"}"
  export OPENCODE_HOME XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME
  mkdir -p "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME"
fi

RUN_DIR="${REPO_ROOT}/.opencode/run"
LOG_DIR="${REPO_ROOT}/.opencode/logs"
OPENCODE_PID_FILE="${RUN_DIR}/opencode-serve.pid"
echo "DEBUG: Creating directories: $RUN_DIR and $LOG_DIR"
mkdir -p "$RUN_DIR"
mkdir -p "$LOG_DIR"

require_opencode() {
  if ! have_cmd opencode; then
    echo "ERROR: 'opencode' not found in PATH." >&2
    echo "Hint: Install opencode on this machine, or adjust PATH." >&2
    exit 2
  fi
}

start_opencode() {
  require_opencode
  require_bun_for_ui

  # Restart semantics: stop any previous --bg instance started by this script.
  stop_opencode_only
  if [[ "$KILL_PORT_LISTENERS" == "1" ]]; then
    kill_port_listeners
  fi
  stop_opencode_on_port_if_any
  ensure_port_available

  echo "INFO: RepoRoot : $REPO_ROOT" >&2
  echo "INFO: Bind     : http://${HOST}:${PORT}" >&2
  if [[ "$AUTH_MODE" == "basic" ]]; then
    echo "INFO: Auth     : basic (${PASSWORD_ENV})" >&2
  else
    echo "INFO: Auth     : none" >&2
  fi

  if [[ -n "${WORKSPACE:-}" ]]; then
    if [[ ! -d "$WORKSPACE" ]]; then
      echo "ERROR: workspace path is not a directory: $WORKSPACE" >&2
      exit 2
    fi
    cd "$WORKSPACE"
  else
    cd "$REPO_ROOT"
  fi

  if [[ "$SERVICE" == "1" ]]; then
    # Service mode: start opencode as a normal child process (no nohup) so the service stop can kill it.
    opencode serve --hostname "$HOST" --port "$PORT" \
      > "${LOG_DIR}/opencode-stdout.log" \
      2> "${LOG_DIR}/opencode-stderr.log" &
    echo $! > "$OPENCODE_PID_FILE"
    echo "OK: opencode server started for service (pid=$(cat "$OPENCODE_PID_FILE"))" >&2
    return 0
  fi

  if [[ "$BG" == "1" ]]; then
    nohup opencode serve --hostname "$HOST" --port "$PORT" \
      > "${LOG_DIR}/opencode-stdout.log" \
      2> "${LOG_DIR}/opencode-stderr.log" &
    echo $! > "$OPENCODE_PID_FILE"
    echo "OK: opencode server started in background (pid=$(cat "$OPENCODE_PID_FILE"))" >&2
  else
    exec opencode serve --hostname "$HOST" --port "$PORT"
  fi
}

stop_all() {
  stop_opencode_only
  reset_tailscale_serve
}

stop_opencode_only() {
  if [[ -f "$OPENCODE_PID_FILE" ]]; then
    local pid=""
    pid="$(cat "$OPENCODE_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" || true
      echo "OK: stopped opencode server (pid=$pid)" >&2
    fi
    rm -f "$OPENCODE_PID_FILE"
  else
    return 0
  fi
}

if [[ "$STATUS" == "1" ]]; then
  show_status
  exit 0
fi

if [[ "$STOP" == "1" ]]; then
  stop_all
  exit 0
fi

case "$AUTH_MODE" in
  auto|basic|none) ;;
  *) echo "ERROR: --auth must be auto|basic|none (got: $AUTH_MODE)" >&2; exit 2;;
esac

if [[ "$TAILNET" == "1" ]]; then
  if ! is_loopback_host "$HOST"; then
    echo "ERROR: --tailnet requires --host 127.0.0.1/localhost (got: $HOST)" >&2
    exit 2
  fi
  if [[ "$SERVICE" != "1" ]] && [[ "$BG" != "1" ]]; then
    BG="1"
    echo "INFO: --tailnet implies --bg (running server in background)." >&2
  fi
fi

if [[ "$AUTH_MODE" == "auto" ]]; then
  if is_loopback_host "$HOST"; then
    AUTH_MODE="none"
  else
    AUTH_MODE="basic"
  fi
fi

if [[ "$AUTH_MODE" == "none" ]]; then
  unset "${PASSWORD_ENV}" || true
else
  ensure_basic_auth_password
fi

start_opencode
if [[ "$TAILNET" == "1" ]]; then
  # Ensure routing is refreshed on restart.
  reset_tailscale_serve
  configure_tailscale_serve
fi

if [[ "$SERVICE" == "1" ]]; then
  if [[ ! -f "$OPENCODE_PID_FILE" ]]; then
    echo "ERROR: expected pid file not found: $OPENCODE_PID_FILE" >&2
    exit 2
  fi

  SERVICE_PID="$(cat "$OPENCODE_PID_FILE" 2>/dev/null || true)"
  if [[ -z "$SERVICE_PID" ]]; then
    echo "ERROR: empty pid file: $OPENCODE_PID_FILE" >&2
    exit 2
  fi

  cleanup() {
    stop_all
  }
  trap cleanup INT TERM

  echo "INFO: service mode enabled; waiting on opencode pid=$SERVICE_PID" >&2
  while kill -0 "$SERVICE_PID" >/dev/null 2>&1; do
    sleep 2
  done

  echo "INFO: RepoRoot : $REPO_ROOT" >&2
  echo "INFO: Bind     : http://${HOST}:${PORT}" >&2

  echo "INFO: opencode process exited; stopping tailscale serve." >&2
  cleanup
fi
