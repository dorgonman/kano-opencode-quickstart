#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
exec "${SCRIPT_DIR}/quickstart-dev.sh" --serve "$@" --host 127.0.0.1 --auth none
