#!/usr/bin/env bash
# cadence/5m — agent-supervision tick. Advisory subagent-stall checks run in
# this tier alongside oversight; drop-in order note: cadence-tick runs these
# lexically, and 01-oversight.sh reads the report queue independently, so
# this fires fresh stall rows on the same tick either way. Advisory only:
# never kills/restarts/mutates a session. Always exits 0.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/agent-supervision.py"
