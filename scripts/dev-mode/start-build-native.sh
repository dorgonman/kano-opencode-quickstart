#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd -P)"

SHARED_LIB="${REPO_ROOT}/scripts/shared/server-common.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "ERROR: shared server library not found: $SHARED_LIB" >&2
  exit 1
fi

source "$SHARED_LIB"

# Source git-helpers.sh from kano-git-master-skill
GIT_HELPERS="${REPO_ROOT}/skills/kano-git-master-skill/scripts/lib/git-helpers.sh"
if [[ ! -f "$GIT_HELPERS" ]]; then
  echo "ERROR: git-helpers.sh not found at: $GIT_HELPERS" >&2
  echo "       Please ensure kano-git-master-skill submodule is initialized" >&2
  exit 1
fi

source "$GIT_HELPERS"

# --- Flags ---

UPDATE_SUBMODULES=false
REBASE_SUBMODULES=false
SKIP_SYNC=false
SHOW_HELP=false

# Server mode flags
MODE="tui"               # tui | serve
HOST="127.0.0.1"
PORT="4096"
BG="0"
TAILNET="0"
TS_HTTPS_PORT="8443"
STOP="0"
STATUS="0"
SERVICE="0"
AUTH_MODE="auto"          # auto|basic|none
PASSWORD_ENV="OPENCODE_SERVER_PASSWORD"
WORKSPACE=""
KILL_PORT_LISTENERS="1"

show_help() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS] [WORKSPACE_PATH]

Developer Mode - Run OpenCode from source code

Modes (default: TUI):
  --serve              Run as headless server (like 'opencode serve')
  --tailnet            Expose via Tailscale Serve (implies --serve --bg)
  --bg                 Run server in background
  --host <ip>          Bind address (default: 127.0.0.1)
  --port <port>        Bind port (default: 4096)
  --ts-https <port>    Tailscale HTTPS port (default: 8443)
  --auth <mode>        auto|basic|none (default: auto)
  --no-auth            Shortcut for --auth none
  --password-env <E>   Password env var for basic auth (default: OPENCODE_SERVER_PASSWORD)
  --workspace <dir>    Workspace root for opencode serve (default: cwd)
  --kill-port-listeners     Kill any process listening on <port> before starting (dangerous)
  --no-kill-port-listeners  Do not kill listeners (fails if <port> in use)
  --service            Keep launcher alive (service manager usage)
  --stop               Stop background dev server + reset tailscale serve
  --status             Show tailscale serve status

Submodule sync:
  -U, --update         Fetch and merge latest from upstream
  -R, --rebase         Fetch and rebase onto upstream
  -S, --skip-sync      Skip syncing submodules

General:
  -h, --help           Show this help

Examples:
  # TUI mode (default)
  ./start-build-native.sh

  # Server mode (local)
  ./start-build-native.sh --serve

  # Server mode + tailnet
  ./start-build-native.sh --tailnet

  # Server background + custom port
  ./start-build-native.sh --serve --bg --port 5096

  # LAN access (basic auth)
  OPENCODE_SERVER_PASSWORD='change-me' ./start-build-native.sh --serve --host 0.0.0.0 --auth basic

  # Stop background server
  ./start-build-native.sh --stop

  # Sync submodules then start TUI
  ./start-build-native.sh -U

  # Specify workspace path
  ./start-build-native.sh /path/to/workspace
EOF
}

POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --serve)        MODE="serve"; shift ;;
    --tailnet)      TAILNET="1"; MODE="serve"; shift ;;
    --bg)           BG="1"; shift ;;
    --host)         HOST="${2:-}"; [[ -n "$HOST" ]] || { echo "ERROR: --host requires a value" >&2; exit 2; }; shift 2 ;;
    --port)         PORT="${2:-}"; [[ -n "$PORT" ]] || { echo "ERROR: --port requires a value" >&2; exit 2; }; shift 2 ;;
    --ts-https)     TS_HTTPS_PORT="${2:-}"; [[ -n "$TS_HTTPS_PORT" ]] || { echo "ERROR: --ts-https requires a value" >&2; exit 2; }; shift 2 ;;
    --auth)         AUTH_MODE="${2:-}"; [[ -n "$AUTH_MODE" ]] || { echo "ERROR: --auth requires a value" >&2; exit 2; }; shift 2 ;;
    --no-auth)      AUTH_MODE="none"; shift ;;
    --password-env) PASSWORD_ENV="${2:-}"; [[ -n "$PASSWORD_ENV" ]] || { echo "ERROR: --password-env requires a value" >&2; exit 2; }; shift 2 ;;
    --workspace)    WORKSPACE="${2:-}"; [[ -n "$WORKSPACE" ]] || { echo "ERROR: --workspace requires a value" >&2; exit 2; }; shift 2 ;;
    --kill-port-listeners|--kill-port|--force-port) KILL_PORT_LISTENERS="1"; shift ;;
    --no-kill-port-listeners) KILL_PORT_LISTENERS="0"; shift ;;
    --service)      SERVICE="1"; shift ;;
    --stop)         STOP="1"; shift ;;
    --status)       STATUS="1"; shift ;;
    -U|--update)    UPDATE_SUBMODULES=true; REBASE_SUBMODULES=false; shift ;;
    -R|--rebase)    REBASE_SUBMODULES=true; UPDATE_SUBMODULES=false; shift ;;
    -S|--skip-sync) SKIP_SYNC=true; shift ;;
    -h|--help)      SHOW_HELP=true; shift ;;
    *)              POSITIONAL_ARGS+=("$1"); shift ;;
  esac
done

if [[ "$SHOW_HELP" == "true" ]]; then
  show_help
  exit 0
fi

set -- "${POSITIONAL_ARGS[@]}"

gith_log "INFO" "========================================="
gith_log "INFO" "OpenCode Developer Mode"
gith_log "INFO" "========================================="

if [[ "$SKIP_SYNC" == "false" ]]; then
  # Ensure submodules are initialized
  gith_log "INFO" "Ensuring submodules are initialized..."
  
  cd "${REPO_ROOT}"
  
  if [[ ! -d "src/opencode/.git" ]] || [[ ! -d "src/oh-my-opencode/.git" ]]; then
    gith_log "INFO" "Initializing submodules..."
    git submodule update --init --recursive src/opencode src/oh-my-opencode || {
      gith_error "Failed to initialize submodules"
      exit 1
    }
    gith_log "INFO" "✓ Submodules initialized"
  fi
  
  # Setup upstream remotes if not already configured
  if ! gith_has_remote "upstream" "src/opencode" || ! gith_has_remote "upstream" "src/oh-my-opencode"; then
    gith_log "INFO" "Setting up upstream remotes..."
    "${REPO_ROOT}/scripts/git/setup-upstream.sh" || {
      gith_error "Failed to setup upstream remotes"
      exit 1
    }
  fi
  
  # Update or rebase submodules
  if [[ "$UPDATE_SUBMODULES" == "true" ]]; then
    gith_log "INFO" "Syncing submodules with upstream (merge)..."
    "${REPO_ROOT}/scripts/git/sync-submodules.sh" || {
      gith_error "Failed to sync submodules"
      gith_error "You may need to resolve conflicts manually"
      exit 1
    }
    gith_log "INFO" "✓ Submodules synced successfully"
  elif [[ "$REBASE_SUBMODULES" == "true" ]]; then
    gith_log "INFO" "Rebasing submodules onto upstream..."
    "${REPO_ROOT}/scripts/git/rebase-submodules.sh" || {
      gith_error "Failed to rebase submodules"
      gith_error "You may need to resolve conflicts manually"
      exit 1
    }
    gith_log "INFO" "✓ Submodules rebased successfully"
  else
    gith_log "INFO" "Submodules ready (no sync requested)"
  fi
else
  gith_log "INFO" "Skipping submodule sync (--skip-sync)"
fi

# --- Resolve bun (cross-platform) ---
install_bun() {
  gith_log "INFO" "Installing Bun..."
  if [[ "${OS:-}" == "Windows_NT" ]] && have_cmd powershell.exe; then
    powershell.exe -NoProfile -Command "irm bun.sh/install.ps1 | iex" || {
      gith_error "Failed to install Bun via PowerShell"
      return 1
    }
  elif have_cmd curl; then
    curl -fsSL https://bun.sh/install | bash || {
      gith_error "Failed to install Bun via curl"
      return 1
    }
  else
    gith_error "Cannot auto-install Bun: no curl or powershell found"
    gith_error "Please install manually: https://bun.sh"
    return 1
  fi
  # Re-source profile so bun is on PATH for this session
  for rc in "${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.profile"; do
    [[ -f "$rc" ]] && source "$rc" 2>/dev/null || true
  done
}

BUN_CMD=""
BUN_CMD="$(resolve_bun_cmd || true)"
if [[ -z "$BUN_CMD" ]]; then
  install_bun
  BUN_CMD="$(resolve_bun_cmd || true)"
  if [[ -z "$BUN_CMD" ]]; then
    gith_error "bun is still not available after install attempt"
    gith_error "Please install manually: https://bun.sh"
    exit 1
  fi
fi
gith_log "INFO" "Using bun: ${BUN_CMD} ($(${BUN_CMD} --version 2>/dev/null || echo unknown))"

# --- Ensure submodule sources exist ---

OPENCODE_SRC="${REPO_ROOT}/src/opencode"
OH_MY_SRC="${REPO_ROOT}/src/oh-my-opencode"

if [[ ! -d "${OPENCODE_SRC}/.git" ]] || [[ ! -d "${OH_MY_SRC}/.git" ]]; then
  gith_log "INFO" "Initializing source submodules..."
  (cd "${REPO_ROOT}" && git submodule update --init --recursive src/opencode src/oh-my-opencode) || {
    gith_error "Failed to initialize submodules"
    exit 1
  }
  gith_log "INFO" "✓ Source submodules initialized"
fi

# --- Install & build dependencies ---

if [[ ! -d "${OPENCODE_SRC}/node_modules" ]]; then
  gith_log "INFO" "Installing OpenCode dependencies..."
  (cd "${OPENCODE_SRC}" && "${BUN_CMD}" install) || {
    gith_error "Failed to install OpenCode dependencies"
    exit 1
  }
  gith_log "INFO" "✓ OpenCode dependencies installed"
fi

if [[ ! -d "${OH_MY_SRC}/node_modules" ]]; then
  gith_log "INFO" "Installing oh-my-opencode dependencies..."
  (cd "${OH_MY_SRC}" && "${BUN_CMD}" install) || {
    gith_error "Failed to install oh-my-opencode dependencies"
    exit 1
  }
  gith_log "INFO" "✓ oh-my-opencode dependencies installed"
fi

if [[ ! -d "${OH_MY_SRC}/dist" ]]; then
  gith_log "INFO" "Building oh-my-opencode from source..."
  (cd "${OH_MY_SRC}" && "${BUN_CMD}" run build) || {
    gith_error "Failed to build oh-my-opencode"
    exit 1
  }
  gith_log "INFO" "✓ oh-my-opencode built successfully"
fi

# Install repo-local plugin deps (.opencode/package.json)
if [[ -f "${REPO_ROOT}/.opencode/package.json" ]] && [[ ! -d "${REPO_ROOT}/.opencode/node_modules" ]]; then
  gith_log "INFO" "Installing repo-local plugin dependencies..."
  (cd "${REPO_ROOT}/.opencode" && "${BUN_CMD}" install) || {
    gith_error "Failed to install plugin dependencies"
    exit 1
  }
  gith_log "INFO" "✓ Plugin dependencies installed"
fi

# --- PID / log directories ---

RUN_DIR="${REPO_ROOT}/.opencode/run"
LOG_DIR="${REPO_ROOT}/.opencode/logs"
OPENCODE_PID_FILE="${RUN_DIR}/opencode-dev-serve.pid"
mkdir -p "$RUN_DIR" "$LOG_DIR"

# --- Server helper functions ---

stop_dev_server() {
  stop_server_by_pidfile "$OPENCODE_PID_FILE" "dev server"
}

# --- Handle --stop / --status early ---

if [[ "$STATUS" == "1" ]]; then
  show_status
  if [[ -f "$OPENCODE_PID_FILE" ]]; then
    pid="$(cat "$OPENCODE_PID_FILE" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      gith_log "INFO" "Dev server running (pid=$pid)"
    else
      gith_log "INFO" "Dev server not running (stale pid file)"
    fi
  else
    gith_log "INFO" "Dev server not running"
  fi
  exit 0
fi

if [[ "$STOP" == "1" ]]; then
  stop_dev_server
  reset_tailscale_serve
  exit 0
fi

# --- Tailnet validation ---

if [[ "$TAILNET" == "1" ]]; then
  if ! is_loopback_host "$HOST"; then
    gith_error "--tailnet requires --host 127.0.0.1/localhost (got: $HOST)"
    exit 2
  fi
  if [[ "$BG" != "1" ]]; then
    BG="1"
    gith_log "INFO" "--tailnet implies --bg"
  fi
fi

if [[ "$MODE" == "serve" ]]; then
  case "$AUTH_MODE" in
    auto|basic|none) ;;
    *) gith_error "--auth must be auto|basic|none (got: $AUTH_MODE)"; exit 2 ;;
  esac

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
fi

# --- Resolve workspace ---

WORKSPACE_PATH="${WORKSPACE:-${PWD}}"
if [[ -z "$WORKSPACE" ]] && [[ $# -gt 0 ]] && [[ "${1}" != -* ]]; then
  WORKSPACE_PATH="$1"
  shift
fi

if [[ ! -d "$WORKSPACE_PATH" ]]; then
  echo "ERROR: workspace path is not a directory: $WORKSPACE_PATH" >&2
  exit 2
fi
WORKSPACE_PATH="$(cd "$WORKSPACE_PATH" && pwd -P)"

# --- Launch ---

# Helper: bun command to invoke opencode from source
OPENCODE_DEV=("${BUN_CMD}" run --cwd "${OPENCODE_SRC}/packages/opencode" --conditions=browser src/index.ts)

echo "" >&2
gith_log "INFO" "OpenCode Dev — mode=${MODE}"
gith_log "INFO" "  Bun:       ${BUN_CMD}"
gith_log "INFO" "  Source:    ${OPENCODE_SRC}"
gith_log "INFO" "  Plugin:    ${OH_MY_SRC}"
gith_log "INFO" "  Workspace: ${WORKSPACE_PATH}"

if [[ "$MODE" == "serve" ]]; then
  gith_log "INFO" "  Bind:      http://${HOST}:${PORT}"
  if [[ "$AUTH_MODE" == "basic" ]]; then
    gith_log "INFO" "  Auth:      basic (${PASSWORD_ENV})"
  else
    gith_log "INFO" "  Auth:      none"
  fi
  [[ "$TAILNET" == "1" ]] && gith_log "INFO" "  Tailnet:   https port ${TS_HTTPS_PORT}"
  echo "" >&2

  # Stop any previous dev server
  stop_dev_server

  if [[ "$KILL_PORT_LISTENERS" == "1" ]]; then
    kill_port_listeners
  fi
  stop_opencode_on_port_if_any
  ensure_port_available

  if [[ "$SERVICE" == "1" ]]; then
    cd "${WORKSPACE_PATH}"
    "${OPENCODE_DEV[@]}" serve --hostname "$HOST" --port "$PORT" \
      > "${LOG_DIR}/opencode-dev-stdout.log" \
      2> "${LOG_DIR}/opencode-dev-stderr.log" &
    echo $! > "$OPENCODE_PID_FILE"
    gith_log "INFO" "✓ Dev server started for service (pid=$(cat "$OPENCODE_PID_FILE"))"
  elif [[ "$BG" == "1" ]]; then
    cd "${WORKSPACE_PATH}"
    nohup "${OPENCODE_DEV[@]}" serve --hostname "$HOST" --port "$PORT" \
      > "${LOG_DIR}/opencode-dev-stdout.log" \
      2> "${LOG_DIR}/opencode-dev-stderr.log" &
    echo $! > "$OPENCODE_PID_FILE"
    gith_log "INFO" "✓ Dev server started in background (pid=$(cat "$OPENCODE_PID_FILE"))"
    gith_log "INFO" "  Logs: ${LOG_DIR}/opencode-dev-*.log"
    gith_log "INFO" "  Attach: cd \"${WORKSPACE_PATH}\" && opencode attach localhost:${PORT}"
    gith_log "INFO" "  Stop:   $(basename "$0") --stop"
  else
    cd "${WORKSPACE_PATH}"
    gith_log "INFO" "  Attach: opencode attach localhost:${PORT}"
    echo "" >&2
    exec "${OPENCODE_DEV[@]}" serve --hostname "$HOST" --port "$PORT"
  fi

  if [[ "$TAILNET" == "1" ]]; then
    reset_tailscale_serve
    configure_tailscale_serve
  fi

  if [[ "$SERVICE" == "1" ]]; then
    if [[ ! -f "$OPENCODE_PID_FILE" ]]; then
      gith_error "expected pid file not found: $OPENCODE_PID_FILE"
      exit 2
    fi

    SERVICE_PID="$(cat "$OPENCODE_PID_FILE" 2>/dev/null || true)"
    if [[ -z "$SERVICE_PID" ]]; then
      gith_error "empty pid file: $OPENCODE_PID_FILE"
      exit 2
    fi

    cleanup() {
      stop_dev_server
      reset_tailscale_serve
    }
    trap cleanup INT TERM

    gith_log "INFO" "service mode enabled; waiting on opencode pid=$SERVICE_PID"
    while kill -0 "$SERVICE_PID" >/dev/null 2>&1; do
      sleep 2
    done

    gith_log "INFO" "opencode process exited; stopping tailscale serve"
    cleanup
  fi
else
  echo "" >&2
  cd "${WORKSPACE_PATH}"
  exec "${OPENCODE_DEV[@]}" "$@"
fi
