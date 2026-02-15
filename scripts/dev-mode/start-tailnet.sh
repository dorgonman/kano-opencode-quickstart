#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

CMD=("${SCRIPT_DIR}/start-build-native.sh" --serve --port 4096 --ts-https 8443 "$@" --tailnet --host 127.0.0.1 --auth none)
exec "${CMD[@]}"
