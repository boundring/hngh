#!/usr/bin/env bash
# cadence/subhour — agent-supervision tick. Advisory subagent-stall checks run in
# this tier alongside oversight; drop-in order note: cadence-tick runs these
# lexically, and 01-oversight.sh reads the report queue independently, so
# this fires fresh stall rows on the same tick either way. Advisory only:
# never kills/restarts/mutates a session. Always exits 0.
# self-gate (31-heartbeat stamp pattern): one real run per 300s - the
# former 5m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-02-agent-supervision-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 300 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/agent-supervision.py"
