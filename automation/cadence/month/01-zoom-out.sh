#!/usr/bin/env bash
# 01-zoom-out — month-tier activity drop-in (cadence-continuum).
# Thin wrapper around the existing zoom-out-loop lane (queue.md
# "## Zoom-out pass log" + timeline.md evidence): appends a dated entry
# to the zoom-out pass log on the real queue ledger and files a report
# row, exactly as the pass log convention records ("record each pass
# here, dated"). Fail-closed: exits 0; a failed ledger append is a
# breadcrumb, never a crash.
#
# The queue-ledger append is the one governed-file write this drop-in
# makes and it is append-only, dated, and non-authoritative — matching
# the documented pass-log protocol (an operator may rotate it). All
# other hngh state stays read-only.
#
# usage: cadence/month/01-zoom-out.sh   (via cadence-tick.sh TIER=month)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
QUEUE="$KERNEL/docs/project/queue.md"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

file_report() {
  local kind="$1" text="$2"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$text"
    return 0
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
    return 1
  fi
}

today="${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"

# bounded market/opportunity signal from the latest digest (thin read)
signal="$(ls -t "$AUTOMATION_ROOT"/digest/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md 2>/dev/null | head -1)"
if [ -z "$signal" ]; then
  signal="no digest available"
else
  signal="digest $(basename "$signal")"
fi

# append a dated entry to the zoom-out pass log (the documented protocol)
if [ -f "$QUEUE" ]; then
  entry="zoom-out pass via activity cadence: $signal; candidate intake to queue ledger"
  if grep -q "## Zoom-out pass log" "$QUEUE"; then
    if grep -q "\*\*$today\*\*" "$QUEUE"; then
      breadcrumb "$JOB_NAME" "zoom-out-log" "today $today already logged; not re-appending"
    else
      # insert under the pass log heading, preserving the ledger
      sed -i "/^## Zoom-out pass log$/a\\
\\
- **$today** — $entry" "$QUEUE" && breadcrumb "$JOB_NAME" "zoom-out-log" "$entry"
    fi
  else
    breadcrumb "$JOB_NAME" "no-pass-log" "queue.md has no '## Zoom-out pass log' section; report only"
  fi
else
  breadcrumb "$JOB_NAME" "no-queue" "queue.md missing; report only"
fi

file_report "optimization" "zoom-out-loop: $today $signal fed to queue ledger"

breadcrumb "$JOB_NAME" "zoom-out-done" "month $today zoom-out pass performed-or-filed"
exit 0
