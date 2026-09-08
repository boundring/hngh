#!/usr/bin/env bash
# 50-research-overflow -- staggered overflow research beat (30m tier;
# acceleration wave 2, 2026-09-07). Runs the SAME beat body as
# cadence/hour/33-research-beat.sh, pinned to a quota leg (odd runs pin
# kimi, even runs lobehub, alternating on its own counter) so it NEVER
# touches the local server and cannot contend with the desktop for the
# model. The hour beat honors OVERFLOW_PIN (skips its own rotation and
# its stamp/load gates -- the caller owns gating) and stamps
# RESEARCH_STAMP_FILE, which this wrapper points at the overflow stamp;
# hour-tier stamp semantics are unchanged.
# Gates:
#   a) >= research-overflow-hours (Inventory; env RESEARCH_OVERFLOW_HOURS
#      overrides) since its own stamp /tmp/.hngh-research-overflow-last
#      (seam: RESEARCH_OVERFLOW_STAMP_FILE);
#   b) >= 30 minutes since the HOUR beat's stamp -- the 30m tier fires at
#      :00 and :30, so an hour beat that ran within 30 minutes defers
#      this run silently (no same-instant research-lines.tsv races);
#   c) no load gate: the pin means no local model use, so machine load
#      cannot starve the overflow beat (ceiling 1 of acceleration wave 2).
# usage: cadence/30m/50-research-overflow.sh   (via cadence-tick.sh TIER=30m)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

STAMP="${RESEARCH_OVERFLOW_STAMP_FILE:-/tmp/.hngh-research-overflow-last}"
HOUR_STAMP="${RESEARCH_BEAT_STAMP_FILE:-/tmp/.hngh-research-beat-last}"
COUNT="${RESEARCH_OVERFLOW_COUNT_FILE:-/tmp/.hngh-research-overflow-count}"
now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"
last="${last//[!0-9]/}"
last="${last:-0}"
hours="${RESEARCH_OVERFLOW_HOURS:-$(get_param research-overflow-hours 2)}"
case "$hours" in '' | *[!0-9]*) hours=2 ;; esac
[ $((now - last)) -ge $((hours * 3600)) ] || exit 0
hlast="$(cat "$HOUR_STAMP" 2>/dev/null || printf '0')"
hlast="${hlast//[!0-9]/}"
hlast="${hlast:-0}"
[ $((now - hlast)) -ge 1800 ] || exit 0 # hour beat ran within 30 min

# pin alternation: the NEXT counter value drives parity (odd -> kimi,
# even -> lobehub). The beat body increments this same counter, sharing
# it with the review interleave -- no double increment here.
n="$(cat "$COUNT" 2>/dev/null || printf '0')"
n="${n//[!0-9]/}"
n="${n:-0}"
n=$((n + 1))
pin=kimi
[ $((n % 2)) -eq 0 ] && pin=lobehub
export OVERFLOW_PIN="$pin"
export RESEARCH_STAMP_FILE="$STAMP"
export RESEARCH_BEAT_COUNT_FILE="$COUNT"
export JOB_NAME="50-research-overflow.sh"
exec bash "$AUTOMATION_ROOT/cadence/hour/33-research-beat.sh"
