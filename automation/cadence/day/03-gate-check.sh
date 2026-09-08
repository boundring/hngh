#!/usr/bin/env bash
# 03-gate-check — day-tier self-improvement drop-in: run BOTH gates once a
# day — the hngh kernel `make test` and the hngh-automation `make test` —
# and file the honest signal for each: a progress row when green, an alert
# row (identity per repo) with the last ~10 error lines when red. A red
# gate in either repo must never sit unnoticed again. Fail-closed: exits 0
# in every expected path.
#
# usage: cadence/day/03-gate-check.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

file_report() {
  local kind="$1" text="$2" ident="${3:-}" win="${4:-86400}"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
    ${ident:+--identity "$ident"} --window "$win" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$text"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
  fi
}

# gate <label> <dir> <alert-identity> — run `make test` in <dir>, file the
# honest signal. Green: progress row + gate-green crumb. Red: alert row
# (last ~10 lines, dedup window 24h) + gate-red crumb.
gate() {
  local label="$1" dir="$2" ident="$3" out rc why checks
  out="$(cd "$dir" && timeout 600 make test 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    checks="$(printf '%s' "$out" | grep -Eo '[0-9]+ checks passed' | tail -n 1)"
    file_report progress "gate: $label make test green (${checks:-ok})"
    breadcrumb "$JOB_NAME" "gate-green" "$label: ${checks:-make test ok}"
  else
    why="rc=$rc"
    [ "$rc" = "124" ] && why="timed out after 600s"
    file_report alert "gate: $label make test FAILED ($why)
$(printf '%s' "$out" | tail -n 10)" "$ident" 86400
    breadcrumb "$JOB_NAME" "gate-red" "$label: make test $why"
  fi
}

gate hngh "$KERNEL" gate-check:hngh
gate hngh-automation "$AUTOMATION_ROOT" gate-check:automation
exit 0
