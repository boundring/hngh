#!/usr/bin/env bash
# cadence/30m — bounded watchdog respawn executor tick (jobs/agent-respawn.sh).
# All four guards (steer-don't-kill, loop-break, budget, authority) live in
# the job; this wrapper only mounts it. Refusals and respawns each append
# exactly one disposition row per dead row to agent-handoffs.md.
root="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$root/jobs/agent-respawn.sh"
exit 0
