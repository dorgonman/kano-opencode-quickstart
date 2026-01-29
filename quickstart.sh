#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

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
printf '      cd "%s" && opencode attach localhost:%s\n' "$WORKSPACE_PATH" "$ATTACH_PORT" >&2

if command -v tailscale >/dev/null 2>&1; then
  exec "${SCRIPT_DIR}/scripts/start-server-tailnet.sh" --workspace "$WORKSPACE_PATH" "$@"
fi

exec "${SCRIPT_DIR}/scripts/start-server-local.sh" --workspace "$WORKSPACE_PATH" "$@"