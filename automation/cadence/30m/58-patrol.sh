#!/usr/bin/env bash
# 58-patrol -- 30m-tier standing patrol (the formal rounds, 2026-09-12,
# docs/records/2026-09-12-patrol-system.md): every 30m tick walks the quick
# surfaces (dashboard feeds, blocker ledger, handoff accumulation, gate
# crumbs, overnight stall) as deterministic checks over existing ledgers --
# routine rounds without a director session. FAILs file report-queue alerts
# (identity patrol:<id>) and append to automation/digest/PATROL-<date>.md;
# a patrol+cause repeating on two consecutive runs auto-queues a
# research-subjects entry. Fail-closed: exits 0 in every expected path.
#
# usage: cadence/30m/58-patrol.sh   (via cadence-tick.sh TIER=30m)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
out="$(HNGH_REPORT_ROOT="$report_root" python3 \
  "$AUTOMATION_ROOT/jobs/patrol.py" --tier 30m 2>&1)"
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
