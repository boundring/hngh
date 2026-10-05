#!/usr/bin/env bash
# 50-research-overflow -- 15-minute overflow research beat (subhour tier;
# acceleration wave 2, 2026-09-07; fail-first promotion 2026-09-07).
# Runs the SAME beat body as cadence/hour/33-research-beat.sh (same
# logic, same lifecycle transitions), always pinned to a non-local leg
# so it NEVER touches the local server. The beat body honors
# OVERFLOW_PIN (skips the hour beat's own failfirst gate and busy
# routing -- this wrapper owns gating) and stamps RESEARCH_STAMP_FILE,
# which this wrapper points at its own stamp so the hour record stays
# the hour's. A shared flock inside the body prevents same-instant
# research-lines.tsv races between the two beats.
#
# Cadence (operator directive: research more often than once per hour):
# the 900s entry stamp paces this to one beat per 15 minutes
# (:00 :15 :30 :45) across the every-minute triggers, with NO in-tick
# sleep. (The 2026-09-24 collapse response had halved the beat to 1800s
# while the sleep still blocked the tick; once the sleep was deleted the
# non-blocking stamp restored the pre-collapse effective 15-minute
# cadence -- quota pacing stays with FAILFIRST_TICK_S.) The former
# `sleep 900` + second beat froze the whole subhour tier for a quarter
# hour per activation, stalling the 60s-tier feeds and filing
# dash-selfreview stale alerts every time the hourly check sampled the
# frozen window (2026-10-04 storm; same collision class as the 2026-09-24
# tier collapse -- a beat must never block the tick). The overflow's own
# tuning state (failfirst-research-overflow, FAILFIRST_TICK_S=900) still
# paces it down below its observed ceiling when the quota/deck legs
# degrade, and promotes it back after consecutive oks.
#
# Gates:
#   a) failfirst_gate research-overflow (lib/failfirst.sh): own state
#      file, 15-minute tick;
#   b) pin selection: deck first when armed AND responsive (deck_up
#      probe -- the deck is a capacity signal, not a fallback), else
#      the kimi quota leg on the shared run counter; an unarmed or
#      pace-blocked pin falls
#      through inside model_call -- research never blocks;
#   c) no load gate and no stagger guard: the pin means no local model
#      use, and the body's flock replaces the old 30-minute stagger
#      (the hour beat is always "recent" at a 15-minute cadence).
# usage: cadence/subhour/50-research-overflow.sh   (via cadence-tick.sh TIER=subhour)
set -u
# self-gate (31-heartbeat stamp pattern): one real run per 900s (the
# pre-collapse effective 15m cadence; the collapse guard pins allowed
# windows and carries g900 for this job). The stamp is the
# ONLY pacer -- never an in-tick sleep; a blocked tick starves the minute
# tier (2026-09-24 collapse, 2026-10-04 freeze recurrence).
STAMP="/tmp/.hngh-cadence-50-research-overflow-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 900 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/params.sh"
. "$AUTOMATION_ROOT/lib/failfirst.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

STAMP="${RESEARCH_OVERFLOW_STAMP_FILE:-/tmp/.hngh-research-overflow-last}"
COUNT="${RESEARCH_OVERFLOW_COUNT_FILE:-/tmp/.hngh-research-overflow-count}"
export JOB_NAME="50-research-overflow.sh"
export FAILFIRST_OP="research-overflow"
export FAILFIRST_TICK_S="900" # 15-minute tier: standard 30m, cautious 60m

overflow_once() { # one gated, pinned research transition
 local verdict n pin
 verdict="$(failfirst_gate research-overflow)"
 if [ "$verdict" != "GO" ]; then
  breadcrumb "$JOB_NAME" "research-overflow-throttled" \
   "failfirst: $verdict - overflow paced below its observed ceiling"
  return 1
 fi
 # pin selection: deck first when responsive; else the kimi quota leg.
 # The beat body increments the
 # same counter, sharing it with the review interleave.
 if deck_up; then
  pin=deck
 else
  n="$(cat "$COUNT" 2>/dev/null || printf '0')"
  n="${n//[!0-9]/}"
  n="${n:-0}"
  pin=kimi
 fi
 export OVERFLOW_PIN="$pin"
 export RESEARCH_STAMP_FILE="$STAMP"
 export RESEARCH_BEAT_COUNT_FILE="$COUNT"
 bash "$AUTOMATION_ROOT/cadence/hour/33-research-beat.sh"
}

overflow_once || true
exit 0
