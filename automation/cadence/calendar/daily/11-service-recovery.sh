#!/usr/bin/env bash
# 11-service-recovery — allowlisted self-heal for the serving front doors.
#
# CORRECTIVE SLICE (2026-09-04): the fleet's front door is :8888, served
# by unsloth-studio.service — the model chain speaks
# UNSLOTH_URL=http://127.0.0.1:8888 (config.env + lib/model.sh, incl. the
# /api/auth/refresh token flow, an Unsloth-Studio-only route). Port :8080
# is llama-server's default and has been down in every probe; nothing in
# the chain consumes it. Evidence + full analysis: hngh
# docs/research/2026-09-04-unsloth-launch-config-lane.md (the llama-server
# launch-config lane — EnvironmentFile env-var launch, LLAMA_ARG_* — is
# documented there; its re-host future is a separate consumer-migration
# decision, NOT this recovery). The previous :8080/llama-server recovery
# branch targeted a port the chain never touches and is removed;
# llama-server stays in the service-ctl.sh allowlist for manual control.
#
# IF :8888 is down AND unsloth-studio.service is installed-but-inactive:
#   scripts/service-ctl.sh unsloth-studio.service start  (the sanctioned
#   recovery path per operator grant 2026-09-03) -> wait 30s -> re-probe.
#   success = progress row "unsloth serving recovered"; still down =
#   alert row naming the unit state + journal hint. ONE recovery attempt
#   per UTC day max (state file ~/.hngh-automation/.service-recovery-<date>).
# If :8888 is up — including serving-out-of-unit (the 2026-09-04
# divergence: process outside the unit, unit inactive) — do NOTHING.
# Never restart a unit that is already active (restart loops are not
# recovery). Do NOT touch unsloth-studio's launch internals (why the
# operator hand-launched it is "not established" per the research doc)
# and NEVER edit unit files (enable/disable/unit-file edits stay
# critical-class; see scripts/service-ctl.sh and hngh
# docs/design/service-management.md).
#
# usage: cadence/calendar/daily/11-service-recovery.sh   (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
UNIT="unsloth-studio.service"
PORT="${HNGH_SERVICE_PROBE_PORT:-8888}"    # env seam for hermetic tests
SLEEP="${HNGH_SERVICE_RECOVERY_SLEEP:-30}" # env seam for hermetic tests
STAMP="${HNGH_SERVICE_RECOVERY_STAMP:-$HOME/.hngh-automation/.service-recovery-$(date -u +%F)}"
SYSTEMCTL="${HNGH_SERVICE_SYSTEMCTL:-systemctl}" # env seam for tests

# 2026-09-22 widening (operator directive, plan
# 2026-09-22-ram-guardrails-dashboard-controls): the dashboard died in
# the session crash and stayed down (disabled unit, no auto-start).
# Recovery now covers BOTH front doors; each has its OWN per-UTC-day
# stamp so one branch's attempt never consumes the other's. A
# deliberate stop through service-ctl.sh writes an expected-state
# marker (~/.hngh-automation/.operator-stop-<unit>) that recovery
# respects — it never undoes an operator stop; the marker clears on
# the next start through service-ctl.sh.
DASH_UNIT="hngh-dashboard.service"
DASH_PORT="${HNGH_SERVICE_PROBE_DASH_PORT:-8890}" # env seam for tests
DASH_STAMP="${HNGH_SERVICE_RECOVERY_DASH_STAMP:-$HOME/.hngh-automation/.service-recovery-hngh-dashboard.service-$(date -u +%F)}"

port_up() { # short-timeout TCP connect, no curl dependency
 PORT="$1" python3 - <<'PY'
import os, socket
s = socket.socket(); s.settimeout(2)
try:
    s.connect(("127.0.0.1", int(os.environ["PORT"]))); raise SystemExit(0)
except OSError:
    raise SystemExit(1)
finally:
    s.close()
PY
}

report() { # kind text identity
 HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add "$1" "$2" \
  --identity "$3" --window 86400 >/dev/null 2>&1 || true
}

attempt() { # $1=unit $2=port $3=stamp — one recovery attempt per UTC day
 local unit="$1" port="$2" stamp="$3"
 port_up "$port" && return 0 # serving is fine (even out-of-unit): noop
 [ -e "$stamp" ] && return 0 # today's attempt was already spent
 if [ -e "${HNGH_STOP_MARKER_DIR:-$HOME/.hngh-automation}/.operator-stop-$unit" ]; then
  # expected-state: deliberate operator stop — never undo it; spend the
  # attempt so this breadcrumb stays once per day (marker clears on the
  # next service-ctl start, which re-arms recovery).
  mkdir -p "$(dirname "$stamp")"
  : >"$stamp" 2>/dev/null || true
  report progress "expected-state: operator-stop marker present for $unit — recovery skipped (not an alert)" \
   "service-recovery:expected-state:$unit"
  breadcrumb "$JOB_NAME" "service-recovery" \
   "$unit: operator-stop marker present — skipped"
  return 0
 fi
 state="$("$SYSTEMCTL" --user show -p ActiveState,UnitFileState "$unit" 2>/dev/null)"
 case "$state" in
 *ActiveState=active*) return 0 ;;           # never restart an active unit
 *UnitFileState=not-found* | "") return 0 ;; # not an installed user unit —
  # the chain already falls back
 *ActiveState=inactive* | *ActiveState=failed*) ;; # recoverable
 *) return 0 ;;
 esac
 mkdir -p "$(dirname "$stamp")"
 : >"$stamp" 2>/dev/null || true # spend today's single attempt
 if [ "${DRY_RUN:-0}" = "1" ]; then
  rm -f "$stamp" # a dry run does not spend the attempt
  DRY_RUN=1 bash "$AUTOMATION_ROOT/scripts/service-ctl.sh" "$unit" start
  echo "dry-run: recovery would wait ${SLEEP}s, re-probe :$port, then file" \
   "a progress row (recovered) or an alert row (still down)"
  return 0
 fi
 breadcrumb "$JOB_NAME" "service-recovery" \
  ":$port down, $unit installed-but-inactive — starting via service-ctl.sh"
 bash "$AUTOMATION_ROOT/scripts/service-ctl.sh" "$unit" start || true
 sleep "$SLEEP"
 if port_up "$port"; then
  report progress "$unit serving recovered" "service-recovery:recovered:$unit"
  breadcrumb "$JOB_NAME" "service-recovery" ":$port up after start — recovered"
 else
  state2="$("$SYSTEMCTL" --user show -p ActiveState,SubState "$unit" 2>/dev/null |
   tr '\n' ' ')"
  hint="$("$SYSTEMCTL" --user status "$unit" --no-pager -n 3 2>&1 | head -n 3 |
   tr '\n' ' ' | cut -c1-400)"
  report alert "$unit serving still down after starting (state: ${state2:-unknown}) — journal hint: $hint" \
   "service-recovery:still-down:$unit"
  breadcrumb "$JOB_NAME" "service-recovery" ":$port still down after start — alert filed ($state2)"
 fi
 return 0
}

# primary branch: the model chain front door (seam variables above)
attempt "$UNIT" "$PORT" "$STAMP"
# dashboard branch (2026-09-22 widening), own port + own stamp
attempt "$DASH_UNIT" "$DASH_PORT" "$DASH_STAMP"
exit 0
