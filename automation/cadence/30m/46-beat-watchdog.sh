#!/usr/bin/env bash
# cadence/30m — orchestrator stall detector tick (jobs/beat-watchdog.py).
# Pure-function detector over STATE.md breadcrumbs + agent-handoffs.md:
# launch-plane failures, same-cause plan deaths, beat silence. One alert +
# one blocker-ledger row per detection; the detector crash never breaks
# the tick (fail-first inside the job). No daemon, no new state beyond
# state/beat-blockers.tsv.
root="$(cd "$(dirname "$0")/../.." && pwd)"
python3 "$root/jobs/beat-watchdog.py"
exit 0
