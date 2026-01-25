#!/usr/bin/env bash
set -euo pipefail

ACTION="${1:-install}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd -P)"

have() { command -v "$1" >/dev/null 2>&1; }

print_status() {
  echo "RepoRoot  : ${REPO_ROOT}" >&2
  echo "opencode  : $(have opencode && echo OK || echo MISSING)" >&2
  echo "bun       : $(have bun && echo OK || echo MISSING)" >&2
  echo "tailscale : $(have tailscale && echo OK || echo MISSING)" >&2
}

install_opencode_plugin_deps() {
  mkdir -p "${REPO_ROOT}/.opencode"

  if [[ ! -f "${REPO_ROOT}/.opencode/package.json" ]]; then
    echo "ERROR: Missing ${REPO_ROOT}/.opencode/package.json" >&2
    echo "Hint : This repo expects plugin deps to be declared there." >&2
    return 2
  fi

  if ! have bun; then
    echo "ERROR: bun not found in PATH." >&2
    echo "Hint : Install Bun, then re-run: $(basename "$0") install" >&2
    return 2
  fi

  echo "INFO: Installing .opencode plugin dependencies via bun..." >&2
  (cd "${REPO_ROOT}/.opencode" && bun install)
  echo "OK: bun install completed." >&2
}

case "${ACTION}" in
  status|check)
    print_status
    ;;
  install)
    print_status
    install_opencode_plugin_deps
    ;;
  *)
    echo "Usage: $(basename "$0") [install|check|status]" >&2
    exit 2
    ;;
esac