#!/usr/bin/env bash
# 08-doc-suite-check — day-tier drop-in: run the deterministic doc-suite
# verifier (jobs/doc-suite-update.sh) over the 20260830 suite once a day
# and file the honest signal: progress row + crumb when green, alert row
# with the failing list when red. Fail-closed: exits 0 in every expected
# path (the check's nonzero rc becomes an alert, never a dropped signal).
#
# usage: cadence/day/08-doc-suite-check.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

out="$(timeout -k 10 300 bash "$AUTOMATION_ROOT/jobs/doc-suite-update.sh" 2>&1)"
rc=$?
if [ "$rc" -eq 0 ]; then
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add progress \
    "doc-suite: $(printf '%s' "$out" | tail -n 1)" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "doc-suite-green" "$(printf '%s' "$out" | tail -n 1)"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file progress: doc-suite green"
  fi
else
  why="rc=$rc"
  [ "$rc" = "124" ] && why="timed out after 300s"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add alert "doc-suite check FAILED ($why)
$(printf '%s' "$out" | tail -n 10)" --identity doc-suite-check --window 86400 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "doc-suite-red" "$why"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file alert: doc-suite $why"
  fi
fi
exit 0
