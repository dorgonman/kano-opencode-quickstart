#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# opencode-portability.sh
# Backup/restore OpenCode server-side data (projects + sessions).
#
# Subcommands:
#   list-projects                        List all projects in storage
#   backup-server   --output <path>      Create tar.gz of entire storage/
#   restore-server  --input <path>       Restore from tar.gz (safe by default)
#   export-projects-json --output <file> Delegate to bun TS script
#   import-projects-json <file> [--merge] Delegate to bun TS script
# ------------------------------------------------------------------------------

# ── Helpers (mirrored from opencode-server.sh) ───────────────────────────────

have_cmd() { command -v "$1" >/dev/null 2>&1; }

resolve_repo_root() {
  local script_path="${BASH_SOURCE[0]}"
  if have_cmd realpath; then
    script_path="$(realpath "$script_path")"
  elif have_cmd python3; then
    script_path="$(python3 -c 'import os,sys;print(os.path.realpath(sys.argv[1]))' "$script_path")"
  fi

  local script_dir
  script_dir="$(cd "$(dirname "$script_path")" && pwd -P)"
  printf "%s\n" "$(cd "$script_dir/.." && pwd -P)"
}

resolve_bun_cmd() {
  if have_cmd bun; then
    printf "%s\n" "bun"
    return 0
  fi

  if [[ -n "${BUN_INSTALL:-}" ]]; then
    if [[ -x "${BUN_INSTALL}/bin/bun" ]]; then
      printf "%s\n" "${BUN_INSTALL}/bin/bun"
      return 0
    fi
    if [[ -x "${BUN_INSTALL}/bin/bun.exe" ]]; then
      printf "%s\n" "${BUN_INSTALL}/bin/bun.exe"
      return 0
    fi
  fi

  if [[ -n "${USERPROFILE:-}" ]]; then
    local bun_win="${USERPROFILE}\\.bun\\bin\\bun.exe"
    if [[ -f "$bun_win" ]] && have_cmd cygpath; then
      local bun_u=""
      bun_u="$(cygpath -u "$bun_win" 2>/dev/null || true)"
      if [[ -n "$bun_u" ]] && [[ -x "$bun_u" ]]; then
        printf "%s\n" "$bun_u"
        return 0
      fi
    fi
  fi

  if [[ -n "${USERNAME:-}" ]]; then
    local bun_gb="/c/Users/${USERNAME}/.bun/bin/bun.exe"
    if [[ -x "$bun_gb" ]]; then
      printf "%s\n" "$bun_gb"
      return 0
    fi
    local bun_gb2="/c/Users/${USERNAME}/.bun/bin/bun"
    if [[ -x "$bun_gb2" ]]; then
      printf "%s\n" "$bun_gb2"
      return 0
    fi
  fi

  return 1
}

# ── Repo root ─────────────────────────────────────────────────────────────────

REPO_ROOT="$(resolve_repo_root)"

# ── Storage path resolution (mirrors OpenCode Global.Path.data logic) ─────────
#
# Priority:
#   1. OPENCODE_REPO_LOCAL=1 → <repo>/.opencode/xdg/data/opencode/storage
#   2. XDG_DATA_HOME (if set) → $XDG_DATA_HOME/opencode/storage
#   3. Fallback → $HOME/.local/share/opencode/storage
#
# Override: set OPENCODE_STORAGE_DIR to skip all resolution.

resolve_storage_dir() {
  if [[ -n "${OPENCODE_STORAGE_DIR:-}" ]]; then
    printf "%s\n" "$OPENCODE_STORAGE_DIR"
    return 0
  fi

  if [[ "${OPENCODE_REPO_LOCAL:-}" == "1" ]]; then
    printf "%s\n" "${REPO_ROOT}/.opencode/xdg/data/opencode/storage"
    return 0
  fi

  local data_home="${XDG_DATA_HOME:-${HOME}/.local/share}"
  printf "%s\n" "${data_home}/opencode/storage"
}

STORAGE_DIR="$(resolve_storage_dir)"

# ── PID file for server-running check ─────────────────────────────────────────

OPENCODE_PID_FILE="${REPO_ROOT}/.opencode/run/opencode-serve.pid"

# ── Usage ─────────────────────────────────────────────────────────────────────

usage() {
  cat <<EOF
Usage: $(basename "$0") <command> [options]

Commands:
  list-projects                         List all projects in storage
  backup-server   --output <path>       Create tar.gz of entire storage/ directory
  restore-server  --input <path>        Restore storage/ from tar.gz
                  [--force]             Overwrite existing storage (creates safety backup first)
  export-projects-json --output <file>  Export projects to JSON (requires bun)
  import-projects-json <file> [--merge] Import projects from JSON (requires bun)

Options:
  -h, --help                            Show this help message

Storage Path Resolution:
  Resolved storage dir: ${STORAGE_DIR}

  The storage directory is resolved in this order:
    1. OPENCODE_STORAGE_DIR env var (explicit override)
    2. OPENCODE_REPO_LOCAL=1 → <repo>/.opencode/xdg/data/opencode/storage
    3. \${XDG_DATA_HOME:-\$HOME/.local/share}/opencode/storage

What Is Backed Up:
  The entire storage/ directory including:
    project/, session/, message/, part/, session_diff/, session_share/,
    todo/, rules-injector/, directory-agents/, directory-readme/,
    agent-usage-reminder/, migration, and any other server-side data.

What Is NOT Backed Up:
  - Browser localStorage (UI state, per-origin)
  - worktree/ directories (workspace sandboxes)
  - cache/, log/, bin/

Examples:
  $(basename "$0") list-projects
  $(basename "$0") backup-server --output ~/opencode-backup.tar.gz
  $(basename "$0") restore-server --input ~/opencode-backup.tar.gz --force
  $(basename "$0") export-projects-json --output projects.json
  $(basename "$0") import-projects-json projects.json --merge
EOF
}

# ── Pre-flight: warn if server is running ─────────────────────────────────────

check_server_running() {
  if [[ ! -f "$OPENCODE_PID_FILE" ]]; then
    return 0
  fi

  local pid=""
  pid="$(cat "$OPENCODE_PID_FILE" 2>/dev/null || true)"
  if [[ -z "$pid" ]]; then
    return 0
  fi

  if kill -0 "$pid" >/dev/null 2>&1; then
    echo "WARNING: OpenCode server appears to be running (pid=$pid)." >&2
    echo "         Backing up or restoring while the server is active may cause" >&2
    echo "         inconsistent data. Consider stopping the server first:" >&2
    echo "           ./scripts/opencode-server.sh --stop" >&2
    echo "" >&2
    return 1
  fi

  return 0
}

# ── list-projects ─────────────────────────────────────────────────────────────

cmd_list_projects() {
  local project_dir="${STORAGE_DIR}/project"

  if [[ ! -d "$project_dir" ]]; then
    echo "No projects found (directory does not exist: $project_dir)" >&2
    exit 0
  fi

  local count=0
  for f in "$project_dir"/*.json; do
    [[ -f "$f" ]] || continue
    count=$((count + 1))

    local basename_f
    basename_f="$(basename "$f" .json)"

    if have_cmd jq; then
      local name="" worktree=""
      name="$(jq -r '.name // "?"' "$f" 2>/dev/null || echo "?")"
      worktree="$(jq -r '.worktree // .path // "?"' "$f" 2>/dev/null || echo "?")"
      printf "%-40s  name=%-30s  worktree=%s\n" "$basename_f" "$name" "$worktree"
    else
      echo "$basename_f  ($f)"
    fi
  done

  if [[ "$count" -eq 0 ]]; then
    echo "No projects found in $project_dir" >&2
  else
    echo "" >&2
    echo "Total: $count project(s)" >&2
  fi
}

# ── backup-server ─────────────────────────────────────────────────────────────

cmd_backup_server() {
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output="${2:-}"; [[ -n "$output" ]] || { echo "ERROR: --output requires a value." >&2; exit 2; }; shift 2;;
      *) echo "ERROR: Unknown option for backup-server: $1" >&2; exit 2;;
    esac
  done

  if [[ -z "$output" ]]; then
    echo "ERROR: --output <path> is required for backup-server." >&2
    echo "Usage: $(basename "$0") backup-server --output <path.tar.gz>" >&2
    exit 2
  fi

  if [[ ! -d "$STORAGE_DIR" ]]; then
    echo "ERROR: Storage directory does not exist: $STORAGE_DIR" >&2
    echo "Hint:  Is OpenCode installed and has been run at least once?" >&2
    exit 2
  fi

  check_server_running || true

  echo "INFO: Storage dir : $STORAGE_DIR" >&2
  echo "INFO: Output      : $output" >&2

  local output_dir
  output_dir="$(dirname "$output")"
  if [[ ! -d "$output_dir" ]]; then
    mkdir -p "$output_dir"
  fi

  (cd "$STORAGE_DIR" && items=(*) && tar -czf "$output" "${items[@]}")

  echo "OK: Backup created: $output" >&2

  if have_cmd du; then
    local size=""
    size="$(du -h "$output" 2>/dev/null | cut -f1 || echo "?")"
    echo "INFO: Size: $size" >&2
  fi
}

# ── restore-server ────────────────────────────────────────────────────────────

cmd_restore_server() {
  local input=""
  local force="0"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --input) input="${2:-}"; [[ -n "$input" ]] || { echo "ERROR: --input requires a value." >&2; exit 2; }; shift 2;;
      --force) force="1"; shift;;
      *) echo "ERROR: Unknown option for restore-server: $1" >&2; exit 2;;
    esac
  done

  if [[ -z "$input" ]]; then
    echo "ERROR: --input <path> is required for restore-server." >&2
    echo "Usage: $(basename "$0") restore-server --input <path.tar.gz> [--force]" >&2
    exit 2
  fi

  if [[ ! -f "$input" ]]; then
    echo "ERROR: Input file does not exist: $input" >&2
    exit 2
  fi

  if ! check_server_running; then
    echo "ERROR: Server is running. Stop the server before restoring." >&2
    echo "       ./scripts/opencode-server.sh --stop" >&2
    exit 2
  fi

  if [[ -d "$STORAGE_DIR" ]] && [[ -n "$(ls -A "$STORAGE_DIR" 2>/dev/null)" ]]; then
    if [[ "$force" != "1" ]]; then
      echo "ERROR: Storage directory is not empty: $STORAGE_DIR" >&2
      echo "       Use --force to overwrite (a safety backup will be created first)." >&2
      exit 2
    fi

    local safety_backup
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M%S)"
    local storage_parent
    storage_parent="$(dirname "$STORAGE_DIR")"
    safety_backup="${storage_parent}/storage.pre-restore.${timestamp}.tar.gz"

    echo "INFO: Creating pre-restore safety backup: $safety_backup" >&2
    (cd "$STORAGE_DIR" && items=(*) && tar -czf "$safety_backup" "${items[@]}")
    echo "OK: Safety backup created: $safety_backup" >&2
  fi

  mkdir -p "$STORAGE_DIR"

  local backup_migration="" current_migration=""
  backup_migration="$(tar -xzf "$input" -O migration 2>/dev/null || true)"
  if [[ -f "${STORAGE_DIR}/migration" ]]; then
    current_migration="$(cat "${STORAGE_DIR}/migration" 2>/dev/null || true)"
  fi
  if [[ -n "$backup_migration" ]] && [[ -n "$current_migration" ]] && [[ "$backup_migration" != "$current_migration" ]]; then
    echo "WARNING: Migration version mismatch!" >&2
    echo "         Backup : $backup_migration" >&2
    echo "         Current: $current_migration" >&2
    echo "         Proceeding anyway — OpenCode may run migrations on next start." >&2
  fi

  echo "INFO: Storage dir : $STORAGE_DIR" >&2
  echo "INFO: Input       : $input" >&2
  echo "INFO: Restoring..." >&2

  tar -xzf "$input" -C "$STORAGE_DIR"

  echo "OK: Restore complete." >&2

  echo "INFO: Restored contents:" >&2
  ls -1 "$STORAGE_DIR" | while read -r entry; do
    if [[ -d "${STORAGE_DIR}/${entry}" ]]; then
      local count=""
      count="$(find "${STORAGE_DIR}/${entry}" -type f 2>/dev/null | wc -l | tr -d ' ')"
      echo "  ${entry}/ ($count files)" >&2
    else
      echo "  ${entry}" >&2
    fi
  done
}

# ── export-projects-json (bun delegate) ───────────────────────────────────────

cmd_export_projects_json() {
  local output=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --output) output="${2:-}"; [[ -n "$output" ]] || { echo "ERROR: --output requires a value." >&2; exit 2; }; shift 2;;
      *) echo "ERROR: Unknown option for export-projects-json: $1" >&2; exit 2;;
    esac
  done

  if [[ -z "$output" ]]; then
    echo "ERROR: --output <file> is required for export-projects-json." >&2
    echo "Usage: $(basename "$0") export-projects-json --output <file.json>" >&2
    exit 2
  fi

  local bun_cmd=""
  bun_cmd="$(resolve_bun_cmd || true)"
  if [[ -z "$bun_cmd" ]]; then
    echo "ERROR: 'bun' is not installed or not found in PATH." >&2
    echo "Hint:  Install Bun (https://bun.sh) or run: ./scripts/prerequisite.sh install" >&2
    exit 2
  fi

  local ts_script="${REPO_ROOT}/opencode-export-projects.ts"
  if [[ ! -f "$ts_script" ]]; then
    echo "ERROR: Export script not found: $ts_script" >&2
    exit 2
  fi

  echo "INFO: Running: $bun_cmd run $ts_script --output $output" >&2
  "$bun_cmd" run "$ts_script" --output "$output"
}

# ── import-projects-json (bun delegate) ───────────────────────────────────────

cmd_import_projects_json() {
  local input_file=""
  local merge_flag=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --merge) merge_flag="--merge"; shift;;
      -*) echo "ERROR: Unknown option for import-projects-json: $1" >&2; exit 2;;
      *)
        if [[ -z "$input_file" ]]; then
          input_file="$1"
        else
          echo "ERROR: Unexpected argument: $1" >&2
          exit 2
        fi
        shift
        ;;
    esac
  done

  if [[ -z "$input_file" ]]; then
    echo "ERROR: <file> argument is required for import-projects-json." >&2
    echo "Usage: $(basename "$0") import-projects-json <file.json> [--merge]" >&2
    exit 2
  fi

  if [[ ! -f "$input_file" ]]; then
    echo "ERROR: Input file does not exist: $input_file" >&2
    exit 2
  fi

  local bun_cmd=""
  bun_cmd="$(resolve_bun_cmd || true)"
  if [[ -z "$bun_cmd" ]]; then
    echo "ERROR: 'bun' is not installed or not found in PATH." >&2
    echo "Hint:  Install Bun (https://bun.sh) or run: ./scripts/prerequisite.sh install" >&2
    exit 2
  fi

  local ts_script="${REPO_ROOT}/opencode-import-projects.ts"
  if [[ ! -f "$ts_script" ]]; then
    echo "ERROR: Import script not found: $ts_script" >&2
    exit 2
  fi

  echo "INFO: Running: $bun_cmd run $ts_script $input_file $merge_flag" >&2
  "$bun_cmd" run "$ts_script" "$input_file" ${merge_flag}
}

# ── Main dispatch ─────────────────────────────────────────────────────────────

if [[ $# -eq 0 ]]; then
  usage
  exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
  list-projects)
    cmd_list_projects "$@"
    ;;
  backup-server)
    cmd_backup_server "$@"
    ;;
  restore-server)
    cmd_restore_server "$@"
    ;;
  export-projects-json)
    cmd_export_projects_json "$@"
    ;;
  import-projects-json)
    cmd_import_projects_json "$@"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    echo "ERROR: Unknown command: $COMMAND" >&2
    echo "" >&2
    usage >&2
    exit 2
    ;;
esac
