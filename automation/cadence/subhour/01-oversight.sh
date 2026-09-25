#!/usr/bin/env bash
# cadence/subhour — oversight tick (procedural every fire; agentic gated inside).
# self-gate (31-heartbeat stamp pattern): one real run per 300s - the
# former 5m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-01-oversight-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 300 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/oversight-tick.sh"
