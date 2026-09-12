#!/usr/bin/env bash
# 40-gdelt-news -- GDELT 2.0 ranked world events into the daily digest.
# The lane's own script is fail-closed (always exit 0: unreachable GDELT
# leaves a breadcrumb and the paper publishes without it); the drop-in
# wrapper just mounts it on the hour tier so Deck A gains a ranked
# world-events block after the ping-hourly news blocks.
#
# usage: cadence/hour/40-gdelt-news.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
mkdir -p "$AUTOMATION_ROOT/logs"
python3 "$AUTOMATION_ROOT/jobs/gdelt-news.py" "$(date -u +%F)" \
  2>>"$AUTOMATION_ROOT/logs/gdelt-news.err" || true
exit 0
