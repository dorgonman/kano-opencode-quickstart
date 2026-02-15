#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

SHARED_LIB="${SCRIPT_DIR}/scripts/shared/server-common.sh"
if [[ ! -f "$SHARED_LIB" ]]; then
  echo "ERROR: shared server library not found: $SHARED_LIB" >&2
  exit 1
fi

source "$SHARED_LIB"

install_tailscale() {
  if [[ "${OS:-}" == "Windows_NT" ]] && command -v powershell.exe >/dev/null 2>&1; then
    powershell.exe -NoProfile -Command "winget install -e --id Tailscale.Tailscale --accept-source-agreements --accept-package-agreements" || return 1
    return 0
  fi

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL https://tailscale.com/install.sh | sh || return 1
    return 0
  fi

  return 1
}

ensure_tailscale_ready() {
  local ts_cmd=""
  ts_cmd="$(resolve_tailscale_cmd || true)"
  if [[ -z "$ts_cmd" ]]; then
    echo "INFO: tailscale not found; installing..." >&2
    if ! install_tailscale; then
      echo "ERROR: failed to install tailscale. Please install it manually." >&2
      exit 2
    fi
    ts_cmd="$(resolve_tailscale_cmd || true)"
  fi

  if [[ -z "$ts_cmd" ]]; then
    echo "ERROR: tailscale CLI still not found after install." >&2
    exit 2
  fi

  if ! "$ts_cmd" status >/dev/null 2>&1; then
    echo "ERROR: Tailscale is not ready (daemon not running or not logged in)." >&2
    echo "Hint : Run 'tailscale up' or open the Tailscale app and sign in, then retry." >&2
    exit 2
  fi
}

# Check if dependencies are installed (first-time setup)
check_and_install_deps() {
  local opencode_dir="${SCRIPT_DIR}/.opencode"
  
  # Check if node_modules exists
  if [[ ! -d "${opencode_dir}/node_modules" ]]; then
    echo "========================================" >&2
    echo "INFO: First-time setup detected!" >&2
    echo "      Installing OpenCode dependencies..." >&2
    echo "========================================" >&2
    if [[ -x "${SCRIPT_DIR}/scripts/deps/opencode-deps-install.sh" ]]; then
      "${SCRIPT_DIR}/scripts/deps/opencode-deps-install.sh"
      echo "" >&2
      echo "✓ Dependencies installed successfully!" >&2
      echo "" >&2
    else
      echo "WARN: opencode-deps-install.sh not found, skipping dependency installation" >&2
    fi
  else
    # Dependencies exist, just show a quick tip
    echo "INFO: Dependencies installed. Running './scripts/deps/opencode-deps-update.sh' to update..." >&2
    if [[ -x "${SCRIPT_DIR}/scripts/deps/opencode-deps-update.sh" ]]; then
      "${SCRIPT_DIR}/scripts/deps/opencode-deps-update.sh"
    else
      echo "WARN: opencode-deps-update.sh not found, skipping dependency update" >&2
    fi
  fi
}

# Run dependency check
check_and_install_deps

WORKSPACE_PATH="${PWD}"
if [[ $# -gt 0 ]] && [[ "${1}" != -* ]]; then
  WORKSPACE_PATH="$1"
  shift
fi

if [[ ! -d "$WORKSPACE_PATH" ]]; then
  echo "ERROR: workspace path is not a directory: $WORKSPACE_PATH" >&2
  exit 2
fi
WORKSPACE_PATH="$(cd "$WORKSPACE_PATH" && pwd -P)"

ATTACH_PORT="4096"
ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
  if [[ "${ARGS[$i]}" == "--port" ]]; then
    if [[ $((i+1)) -lt ${#ARGS[@]} ]] && [[ -n "${ARGS[$((i+1))]}" ]]; then
      ATTACH_PORT="${ARGS[$((i+1))]}"
    fi
  elif [[ "${ARGS[$i]}" == --port=* ]]; then
    ATTACH_PORT="${ARGS[$i]#--port=}"
  fi
done

echo "INFO: Workspace: ${WORKSPACE_PATH}" >&2
echo "INFO: Attach (CLI root = workspace):" >&2

# Resolve opencode command for display
OPENCODE_BIN="opencode"
if command -v opencode >/dev/null 2>&1; then
  OPENCODE_BIN="$(command -v opencode)"
elif [[ "${OS:-}" == "Windows_NT" ]] && [[ -f "${USERPROFILE}/.bun/bin/opencode" ]]; then
  OPENCODE_BIN="${USERPROFILE}/.bun/bin/opencode"
elif [[ -f "${HOME}/.bun/bin/opencode" ]]; then
  OPENCODE_BIN="${HOME}/.bun/bin/opencode"
else
  # Fallback to using bun x if installed but not in path
  OPENCODE_BIN="bun x opencode-ai"
fi

printf '      cd "%s" && "%s" attach localhost:%s\n' "$WORKSPACE_PATH" "$OPENCODE_BIN" "$ATTACH_PORT" >&2


# Auto-configure NODE_PATH for global Bun modules (for plugins like oh-my-opencode)
# This ensures opencode can find plugins installed via 'bun install -g'
setup_node_path() {
  local bun_global_dir=""
  local path_sep=":"
  
  if [[ "${OS:-}" == "Windows_NT" ]]; then
    path_sep=";"
    # Windows: %USERPROFILE%\.bun\install\global\node_modules
    if [[ -d "${USERPROFILE}/.bun/install/global/node_modules" ]]; then
      bun_global_dir="${USERPROFILE}/.bun/install/global/node_modules"
    fi
  else
    # Linux/Mac: ~/.bun/install/global/node_modules
    if [[ -d "${HOME}/.bun/install/global/node_modules" ]]; then
      bun_global_dir="${HOME}/.bun/install/global/node_modules"
    fi
  fi
  
  if [[ -n "$bun_global_dir" ]]; then
    if [[ -z "${NODE_PATH:-}" ]]; then
      export NODE_PATH="$bun_global_dir"
    else
      export NODE_PATH="$bun_global_dir${path_sep}${NODE_PATH}"
    fi
    echo "INFO: Added bun global modules to NODE_PATH: $bun_global_dir" >&2
  fi
  
  # Also add repo-local .opencode/node_modules if it exists (Highest Priority)
  local local_modules="${SCRIPT_DIR}/.opencode/node_modules"
  if [[ -d "$local_modules" ]]; then
      if [[ -z "${NODE_PATH:-}" ]]; then
      export NODE_PATH="$local_modules"
    else
      export NODE_PATH="$local_modules${path_sep}${NODE_PATH}"
    fi
    echo "INFO: Added local repo modules to NODE_PATH: $local_modules" >&2
  fi
}

setup_node_path

ensure_tailscale_ready
exec "${SCRIPT_DIR}/scripts/user-mode/start-tailnet.sh" --workspace "$WORKSPACE_PATH" "$@"