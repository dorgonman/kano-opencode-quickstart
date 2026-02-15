#!/usr/bin/env bash

log_info() {
  if declare -F gith_log >/dev/null 2>&1; then
    gith_log "INFO" "$1"
  else
    echo "INFO: $1" >&2
  fi
}

log_warn() {
  if declare -F gith_log >/dev/null 2>&1; then
    gith_log "WARN" "$1"
  else
    echo "WARN: $1" >&2
  fi
}

log_error() {
  if declare -F gith_log >/dev/null 2>&1; then
    gith_log "ERROR" "$1"
  else
    echo "ERROR: $1" >&2
  fi
}

have_cmd() { command -v "$1" >/dev/null 2>&1; }

is_loopback_host() {
  case "$1" in
    127.0.0.1|localhost|::1) return 0 ;;
    *) return 1 ;;
  esac
}

resolve_bun_cmd() {
  if have_cmd bun; then
    printf "%s\n" "bun"
    return 0
  fi

  if [[ -n "${BUN_INSTALL:-}" ]]; then
    for p in "${BUN_INSTALL}/bin/bun" "${BUN_INSTALL}/bin/bun.exe"; do
      [[ -x "$p" ]] && { printf "%s\n" "$p"; return 0; }
    done
  fi

  if [[ -n "${USERPROFILE:-}" ]] && have_cmd cygpath; then
    local bun_u=""
    bun_u="$(cygpath -u "${USERPROFILE}\\.bun\\bin\\bun.exe" 2>/dev/null || true)"
    [[ -n "$bun_u" ]] && [[ -x "$bun_u" ]] && { printf "%s\n" "$bun_u"; return 0; }
  fi

  if [[ -n "${USERNAME:-}" ]]; then
    for p in "/c/Users/${USERNAME}/.bun/bin/bun.exe" "/c/Users/${USERNAME}/.bun/bin/bun"; do
      [[ -x "$p" ]] && { printf "%s\n" "$p"; return 0; }
    done
  fi

  return 1
}

resolve_tailscale_cmd() {
  if have_cmd tailscale; then
    printf "%s\n" "tailscale"
    return 0
  fi

  for p in "/c/Program Files/Tailscale/tailscale.exe" "/c/Program Files (x86)/Tailscale/tailscale.exe"; do
    [[ -x "$p" ]] && { printf "%s\n" "$p"; return 0; }
  done

  return 1
}

require_bun_for_ui() {
  if resolve_bun_cmd >/dev/null 2>&1; then
    return 0
  fi

  log_error "'bun' not found; OpenCode UI may fail to load (BunInstallFailedError)."
  log_error "Hint : Install Bun (bun.sh) and ensure bun.exe is on PATH for the service/user."
  log_error "Hint : Repo helper scripts:"
  log_error "       - bash scripts/prerequisite.sh install"
  log_error "       - powershell -ExecutionPolicy Bypass -File scripts\\prerequisite.ps1 install"
  return 2
}

ensure_basic_auth_password() {
  if [[ -n "${!PASSWORD_ENV:-}" ]]; then
    return 0
  fi

  if [[ ! -t 0 ]]; then
    log_error "${PASSWORD_ENV} is not set and stdin is not a TTY."
    log_error "Set it like: ${PASSWORD_ENV}=xxx $(basename "$0") --auth basic ..."
    exit 2
  fi

  log_warn "${PASSWORD_ENV} is not set; prompting for a password."

  local pw=""
  if have_cmd stty; then
    printf "Enter server password (input hidden): " >&2
    stty -echo
    read -r pw
    stty echo
    printf "\n" >&2
  else
    read -r -p "Enter server password: " pw >&2
  fi

  if [[ -z "$pw" ]]; then
    log_error "Empty password is not allowed."
    exit 2
  fi

  export "${PASSWORD_ENV}=$pw"
  unset pw
}

stop_server_by_pidfile() {
  local pid_file="$1"
  local label="${2:-server}"

  if [[ -f "$pid_file" ]]; then
    local pid=""
    pid="$(cat "$pid_file" 2>/dev/null || true)"
    if [[ -n "$pid" ]] && kill -0 "$pid" >/dev/null 2>&1; then
      kill "$pid" || true
      log_info "Stopped ${label} (pid=$pid)"
    fi
    rm -f "$pid_file"
  fi
}

port_listener_pids() {
  if have_cmd lsof; then
    lsof -nP -t -iTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true
    return 0
  fi
  return 0
}

show_port_listeners() {
  if have_cmd lsof; then
    lsof -nP -iTCP:"${PORT}" -sTCP:LISTEN 2>/dev/null || true
  fi
}

ensure_port_available() {
  if [[ "${OS:-}" == "Windows_NT" ]]; then
    return 0
  fi

  local pids=""
  pids="$(port_listener_pids)"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  log_error "port ${PORT} is already in use."
  show_port_listeners >&2 || true
  log_error "Hint : Choose another port: --port 4097"
  log_error "Hint : Or force-kill listeners: --kill-port-listeners"
  exit 2
}

kill_port_listeners() {
  if [[ "${OS:-}" == "Windows_NT" ]]; then
    return 0
  fi

  local pids=""
  pids="$(port_listener_pids)"
  if [[ -z "$pids" ]]; then
    return 0
  fi

  log_warn "killing process(es) listening on port ${PORT}: ${pids}"
  show_port_listeners >&2 || true

  for pid in $pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done

  sleep 0.3

  local still=""
  still="$(port_listener_pids)"
  if [[ -n "$still" ]]; then
    for pid in $still; do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
  fi
}

stop_opencode_on_port_if_any() {
  if [[ "${OS:-}" != "Windows_NT" ]]; then
    return 0
  fi

  if ! have_cmd powershell.exe; then
    return 0
  fi

  local pid=""
  pid="$(
    powershell.exe -NoProfile -Command "\
      \$p=${PORT}; \
      \$c=Get-NetTCPConnection -LocalPort \$p -State Listen -ErrorAction SilentlyContinue \
        | Select-Object -First 1 -ExpandProperty OwningProcess; \
      if(\$c){Write-Output \$c}" 2>/dev/null | tr -d '\r' || true
  )"
  [[ -n "$pid" ]] || return 0

  local pname=""
  pname="$(
    powershell.exe -NoProfile -Command "\
      try { (Get-Process -Id $pid -ErrorAction Stop).ProcessName } catch { '' }" 2>/dev/null \
      | tr -d '\r' || true
  )"
  local cmdline=""
  cmdline="$(
    powershell.exe -NoProfile -Command "\
      try { (Get-CimInstance Win32_Process -Filter \"ProcessId=$pid\").CommandLine } catch { '' }" 2>/dev/null \
      | tr -d '\r' || true
  )"

  if [[ "$pname" =~ [Oo][Pp][Ee][Nn][Cc][Oo][Dd][Ee] ]] || [[ "$cmdline" =~ [Oo][Pp][Ee][Nn][Cc][Oo][Dd][Ee] ]]; then
    powershell.exe -NoProfile -Command "\
      try { Stop-Process -Id $pid -Force -ErrorAction Stop; \
        'OK: stopped opencode listener on port ${PORT} (pid=$pid)' } \
      catch { 'WARN: failed to stop pid='+$pid+': '+$_.Exception.Message }" 2>/dev/null \
      | tr -d '\r' >&2 || true
  fi
}

reset_tailscale_serve() {
  local ts_cmd=""
  ts_cmd="$(resolve_tailscale_cmd || true)"
  if [[ -z "$ts_cmd" ]]; then
    return 0
  fi
  "$ts_cmd" serve reset >/dev/null 2>&1 || true
  log_info "Tailscale serve reset"
}

configure_tailscale_serve() {
  local ts_cmd=""
  ts_cmd="$(resolve_tailscale_cmd || true)"
  if [[ -z "$ts_cmd" ]]; then
    log_error "'tailscale' CLI not found; cannot use --tailnet."
    log_error "Hint : Ensure tailscale.exe is installed and available in PATH."
    return 2
  fi

  log_info "Checking Tailscale daemon/login..."
  if ! "$ts_cmd" status >/dev/null 2>&1; then
    log_error "Tailscale is not ready (daemon not running or not logged in)."
    log_error "Hint : Run 'tailscale up' (or open the Tailscale app and sign in), then retry."
    return 2
  fi

  log_info "Configuring: tailscale serve --bg --https=${TS_HTTPS_PORT} localhost:${PORT}"
  "$ts_cmd" serve --bg --https="${TS_HTTPS_PORT}" "localhost:${PORT}"
  log_info "Tailscale serve configured"
  "$ts_cmd" serve status || true
}

show_status() {
  local ts_cmd=""
  ts_cmd="$(resolve_tailscale_cmd || true)"
  if [[ -z "$ts_cmd" ]]; then
    log_info "Tailscale CLI not found"
    return 0
  fi
  "$ts_cmd" serve status || true
}
