#!/usr/bin/env bash
# cadence/subhour — bounded watchdog respawn executor tick (jobs/agent-respawn.sh).
# All four guards (steer-don't-kill, loop-break, budget, authority) live in
# the job; this wrapper only mounts it. Refusals and respawns each append
# exactly one disposition row per dead row to agent-handoffs.md.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-45-agent-respawn-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$root/jobs/agent-respawn.sh"
exit 0
