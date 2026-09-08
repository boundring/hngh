#!/usr/bin/env bash
# 07-budget-digest — day-tier budget drop-in (cadence-continuum).
# Files one progress row per day summarizing the spend picture: overnight
# session-runs from logs/budget.md plus remote model calls/cost from
# dashboard/telemetry.db, against the operator target of $10-20/day.
# Fail-closed: a missing/locked db or a failed report write is a
# breadcrumb, never a crash — exits 0 in every expected path.
#
# usage: cadence/day/07-budget-digest.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

day_of() { # YYYY-MM-DD date from HNGH_TICK_TS (tests) or today UTC
  printf '%s' "${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"
}
day="$(day_of)"

# overnight session-runs logged today + distinct lane names (field 2)
rows="$(grep "^$day" "$AUTOMATION_ROOT/logs/budget.md" 2>/dev/null \
  | grep "session-run[[:space:]]*$")"
n="$(printf '%s\n' "$rows" | grep -c .)"
[ "$n" -ge 1 ] 2>/dev/null || n=0
lanes=""
[ "$n" -gt 0 ] && lanes=" ($(printf '%s\n' "$rows" \
  | sed 's/^[^|]*|[[:space:]]*//; s/[[:space:]]*|[[:space:]]*session-run[[:space:]]*$//; s/|/,/g' \
  | sort -u | paste -sd, -))"

# remote model calls/cost today; missing/locked db reads as 0/0
stats="$(sqlite3 "$AUTOMATION_ROOT/dashboard/telemetry.db" \
  "select count(*), ifnull(round(sum(cost_usd),2),0) from events \
where kind='model' and source='remote' and ts like '$day%'" 2>/dev/null)"
calls="${stats%%|*}"; [ -n "$calls" ] || calls=0
cost="${stats##*|}";  [ -n "$cost" ]  || cost=0

if HNGH_REPORT_ROOT="$report_root" $REPORT --add progress \
  "daily budget digest $day: overnight sessions=$n$lanes remote_model_calls=$calls remote_cost_usd=$cost [vs operator target \$10-20/day]" \
  --identity "budget-digest-$day" --window 86400 >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "budget-digest" "sessions=$n lanes=$lanes calls=$calls cost=$cost"
else
  breadcrumb "$JOB_NAME" "report-fail" "could not file budget digest $day"
fi
exit 0
