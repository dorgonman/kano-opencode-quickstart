#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if command -v tailscale >/dev/null 2>&1; then
  exec "${SCRIPT_DIR}/scripts/start-server-tailnet.sh" "$@"
fi

exec "${SCRIPT_DIR}/scripts/start-server-local.sh" "$@"