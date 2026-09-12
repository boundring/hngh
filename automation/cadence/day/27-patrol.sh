#!/usr/bin/env bash
# 27-patrol -- day-tier standing patrol (the formal rounds, 2026-09-12,
# docs/records/2026-09-12-patrol-system.md): the heavier surfaces the
# night-watch director walked once a day -- loop-history guard rc, research
# line flow, paper-edition QA, companion-service health, disk, session
# budget. The artifact review has its own day slot (26-publication-review.sh)
# and is deliberately NOT duplicated here; both day beats feed the same
# findings convention. FAILs file report-queue alerts (identity
# patrol:<id>) and append to automation/digest/PATROL-<date>.md; a
# patrol+cause repeating on two consecutive runs auto-queues a
# research-subjects entry. Fail-closed: exits 0 in every expected path.
#
# usage: cadence/day/27-patrol.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
out="$(HNGH_REPORT_ROOT="$report_root" python3 \
  "$AUTOMATION_ROOT/jobs/patrol.py" --tier day 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  HNGH_REPORT_ROOT="$report_root" $REPORT --add alert \
    "patrol beat failed (rc=$rc): $(printf '%s' "$out" | tail -n 3)" \
    --identity patrol:runner --window 86400 >/dev/null 2>&1
  breadcrumb "$JOB_NAME" "patrol-error" "rc=$rc"
  exit 0
fi
breadcrumb "$JOB_NAME" "patrol-done" "$(printf '%s' "$out" | grep -c '^FAIL') red"
exit 0
