# service-mgmt.sh — registry-driven companion-service management for the
# hngh-services.tsv registry. Sourced by install.sh (services phase) and
# runnable directly:
#
#   service-mgmt.sh status|start|stop|install SERVICE
#
# Fail-closed rules: unknown service -> exit 2; start on an already-healthy
# service -> no-op; stop only kills a pid hngh itself started (the transient
# child of a previous svc_start) — operator-run processes are refused.
# Installs are NEVER run silently: svc_install prints the operator step for
# the row's install-method and exits 1 (nothing installed). No privilege
# escalation of any kind, no daemonization, no systemd units — the persistent
# option is a per-service
# systemd --user unit, each still operator-granted (see the record file).
set -u
_SVCMGMT="${BASH_SOURCE[0]}"
SVC_TSV="${SVC_TSV:-$(cd "$(dirname "$_SVCMGMT")/.." && pwd)/config/hngh-services.tsv}"
SVC_STATE="${SVC_STATE:-${HOME:-${TMPDIR:-/tmp}}/.hngh-automation/services}"

# svc_health URL -> 0 iff URL answers with any HTTP response (bounded 2s).
# Empty URL -> not addressable -> 1.
svc_health() { # URL
  local url="$1"
  [ -n "$url" ] || return 1
  curl -fsS -m 2 "$url" >/dev/null 2>&1
}

# svc_rows -> prints "service<TAB>disposition<TAB>install-path<TAB>start-
# command<TAB>health-url<TAB>managed-by" per registry row (role/install-method
# are documentation columns; install-method is read by svc_install itself).
svc_rows() {
  # tab-safe row reader: drop comments/blank lines and the header; emit
  # service<TAB>disposition<TAB>install-path<TAB>start-command<TAB>
  # health-url<TAB>managed-by<TAB>install-method
  awk -F'\t' '!/^#/ && NF >= 8 && $1 != "service" {
    print $1 "\t" $8 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $3
  }' "$SVC_TSV"
}

# svc_lookup SERVICE -> sets SVC_DISP/SVC_PATH/SVC_START/SVC_URL;
# rc 2 if unknown.
svc_lookup() { # SERVICE
  local want="$1" row
  row="$(svc_rows | awk -F'\t' -v s="$want" '$1 == s {print; exit}')"
  if [ -z "$row" ]; then
    echo "service-mgmt: unknown service '$want' (registry: $SVC_TSV)" >&2
    return 2
  fi
  SVC_DISP="$(printf '%s' "$row" | cut -f2)"
  SVC_PATH="$(printf '%s' "$row" | cut -f3)"
  SVC_START="$(printf '%s' "$row" | cut -f4)"
  SVC_URL="$(printf '%s' "$row" | cut -f5)"
  return 0
}

# svc_status SERVICE -> prints "SERVICE: up|down"; exit 0 up, 1 down,
# 2 unknown. A row with no health-url is "down" unless its install-path
# binary exists (then "down (binary present)").
svc_status() { # SERVICE
  svc_lookup "$1" || return $?
  if svc_health "$SVC_URL"; then
    echo "$1: up"
    return 0
  fi
  if [ -n "$SVC_PATH" ] && [ -x "$SVC_PATH" ]; then
    echo "$1: down (binary present)"
  else
    echo "$1: down"
  fi
  return 1
}

# svc_start SERVICE -> transient child via the row's start-command (the
# ComfyUI pattern: no daemonization, no units). Already-healthy -> no-op.
# The child runs in its own session (setsid) so one kill takes the tree;
# the pgid is recorded under $SVC_STATE for svc_stop. Empty start-command
# (operator-run rows) -> fail-closed exit 1.
svc_start() { # SERVICE
  svc_lookup "$1" || return $?
  if svc_health "$SVC_URL"; then
    echo "$1: already up (no-op)"
    return 0
  fi
  if [ -z "$SVC_START" ]; then
    echo "service-mgmt: $1 has no start-command (disposition $SVC_DISP; operator-run surface)" >&2
    return 1
  fi
  mkdir -p "$SVC_STATE"
  local log="$SVC_STATE/$1.log"
  setsid bash -c "$SVC_START" >>"$log" 2>&1 &
  local pgid=$!
  echo "$pgid" >"$SVC_STATE/$1.pid"
  local i
  for i in $(seq 1 60); do
    if svc_health "$SVC_URL"; then
      echo "$1: up (pgid $pgid, log $log)"
      return 0
    fi
    sleep 0.5
  done
  echo "service-mgmt: $1 did not report healthy within 30s (log $log)" >&2
  return 1
}

# svc_stop SERVICE -> only the transient child svc_start recorded. Absent or
# stale pidfile -> already down (no-op). Operator-run processes are NEVER
# killed (fail-closed: hngh refuses what it did not start).
svc_stop() { # SERVICE
  svc_lookup "$1" || return $?
  local pf="$SVC_STATE/$1.pid"
  if [ ! -f "$pf" ]; then
    echo "$1: no hngh-managed pid (operator-run or never started by hngh); refusing"
    return 0
  fi
  local pgid
  pgid="$(cat "$pf")"
  if ! kill -0 "$pgid" 2>/dev/null; then
    rm -f "$pf"
    echo "$1: already down (stale pidfile removed)"
    return 0
  fi
  kill -TERM -- -"$pgid" 2>/dev/null || kill -TERM "$pgid" 2>/dev/null
  rm -f "$pf"
  echo "$1: stopped (pgid $pgid)"
  return 0
}

# svc_install SERVICE -> NOTHING is installed. The row's install-method is
# translated into the printed operator step (house rule: anything hngh could
# be authorized for is documented; anything needing privilege or a first
# install stays an operator action). exit 1 = not installed by hngh here.
svc_install() { # SERVICE
  svc_lookup "$1" || return $?
  local method
  method="$(awk -F'\t' -v s="$1" '!/^#/ && NF >= 8 && $1 == s {print $3}' "$SVC_TSV")"
  echo "operator step for $1 (install-method: $method; hngh installed nothing):"
  case "$method" in
  user-space-venv)
    echo "  git clone the upstream into $SVC_PATH, build a uv/python venv, install deps"
    echo "  (see docs/records/2026-09-11-comfyui-repair.md for the audited recipe)"
    ;;
  unsloth-studio)
    echo "  launch unsloth studio as the operator; its llama-server serves 127.0.0.1:8888"
    ;;
  official-install-script)
    echo "  run the upstream official install path as the operator (review it first;"
    echo "  never pipe a third-party script into a shell)"
    ;;
  system-package)
    echo "  install via the system package manager (pacman -S / apt-get install ...)"
    ;;
  *)
    echo "  no documented operator step for method '$method'; add one to the registry row"
    ;;
  esac
  return 1
}

# svc_ask_manage SERVICE -> echoes the operator's verb
# (install|configure|skip|register-only). Seam: HNGH_SERVICE_ANSWERS (a
# whitespace-split queue, env overrides win, one answer consumed per poll);
# a TTY reads the poll; otherwise the default (register-only: record the
# choice, install nothing).
_SVC_ANSW_IDX="${_SVC_ANSW_IDX:-0}"
svc_ask_manage() { # SERVICE
  local svc="$1" ans=""
  set -- ${HNGH_SERVICE_ANSWERS:-}
  if [ "$#" -gt "$_SVC_ANSW_IDX" ]; then
    eval "ans=\"\${$((_SVC_ANSW_IDX + 1))}\""
    _SVC_ANSW_IDX=$((_SVC_ANSW_IDX + 1))
    echo "$ans"
    return 0
  fi
  if [ -t 0 ]; then
    read -r -p "manage $svc? [install/configure/skip] (register-only): " ans </dev/tty || ans=""
  fi
  echo "${ans:-register-only}"
}

# CLI: service-mgmt.sh VERB SERVICE
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  [ $# -eq 2 ] || {
    echo "usage: service-mgmt.sh {status|start|stop|install} SERVICE" >&2
    exit 2
  }
  case "$1" in
  status) svc_status "$2" ;;
  start) svc_start "$2" ;;
  stop) svc_stop "$2" ;;
  install) svc_install "$2" ;;
  *)
    echo "service-mgmt: unknown verb '$1'" >&2
    exit 2
    ;;
  esac
fi
