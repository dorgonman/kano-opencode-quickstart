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


# Start/Ensure tailscale ready
ensure_tailscale_ready

# Isolate Dev Mode configuration from User Mode (release) config
# This prevents loading the published 'oh-my-opencode' plugin when running from source
export OPENCODE_REPO_LOCAL=1
export XDG_CONFIG_HOME="${SCRIPT_DIR}/.opencode/dev/config"
export XDG_DATA_HOME="${SCRIPT_DIR}/.opencode/dev/data"
mkdir -p "$XDG_CONFIG_HOME/opencode" "$XDG_DATA_HOME"

# Define local plugin path (source)
PLUGIN_SRC="${SCRIPT_DIR}/src/oh-my-opencode"
# Add to NODE_PATH so opencode can require("oh-my-opencode") from source/dist
if [[ -d "$PLUGIN_SRC" ]]; then
  export NODE_PATH="${PLUGIN_SRC}${path_sep:-:}${NODE_PATH:-}"
  echo "INFO: Added local plugin source to NODE_PATH: $PLUGIN_SRC" >&2
fi

# Ensure dev config enables the plugin
DEV_CONFIG="${XDG_CONFIG_HOME}/opencode/opencode.json"
if [[ ! -f "$DEV_CONFIG" ]]; then
  echo '{"plugin":["oh-my-opencode"]}' > "$DEV_CONFIG"
  echo "INFO: Created dev config with oh-my-opencode enabled at $DEV_CONFIG" >&2
fi

exec "${SCRIPT_DIR}/scripts/dev-mode/start-tailnet.sh" "$@"
