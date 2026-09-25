#!/usr/bin/env bash
# cadence/subhour — orchestrator stall detector tick (jobs/beat-watchdog.py).
# Pure-function detector over STATE.md breadcrumbs + agent-handoffs.md:
# launch-plane failures, same-cause plan deaths, beat silence. One alert +
# one blocker-ledger row per detection; the detector crash never breaks
# the tick (fail-first inside the job). No daemon, no new state beyond
# state/beat-blockers.tsv.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-46-beat-watchdog-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$root/jobs/beat-watchdog.py"
exit 0
