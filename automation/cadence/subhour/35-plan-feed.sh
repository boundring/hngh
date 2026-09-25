#!/usr/bin/env bash
# cadence/subhour — plan feed refresh (hngh docs/project/plans ledger ->
# dashboard/plans.json for the dashboard). Read-only probe, fail-closed.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-35-plan-feed-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/plan-feed.py"
