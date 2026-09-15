#!/usr/bin/env bash
# 50-hygiene -- day-tier self-maintenance hygiene scan (2026-09-15):
# jcode zombie session metadata and dead pidfiles, stray repo-root files,
# aged empty .agent-scratch / .scratch dirs. Report-only by default
# (hygiene.py --fix would remove dead pidfiles only; the cadence beat
# stays report-only). Files report-queue progress rows (identity
# hygiene:sessions / hygiene:pidfiles / hygiene:repo) only when something
# is found; appends one ambient-memory line to agent-handoffs.md. JSON
# log under automation/logs/. Fail-soft: exits 0 in every expected path.
#
# usage: cadence/day/50-hygiene.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"

LOG_DIR="$AUTOMATION_ROOT/logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/hygiene-$(date -u +%Y%m%d).log"
out="$(python3 "$AUTOMATION_ROOT/jobs/hygiene.py" --json 2>&1)"
rc=$?
printf '%s rc=%s %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$rc" "$out" >> "$LOG"
exit 0
