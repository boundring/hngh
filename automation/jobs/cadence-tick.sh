#!/usr/bin/env bash
# cadence-tick — one cadence-continuum tick for a single tier.
# Single-tick + per-tier flock keeps each tier serial and prevents
# overlapping ticks compounding across the subhour tier (the
# cadence-continuum "timer sprawl" risk). Fail-closed: exits 0.
#
# Mounted work: drop-ins at cadence/<tier>/*.sh are run in lexical order
# (calendar runs cadence/calendar/<sub>/*.sh per the firing instant);
# an empty/absent tier dir does nothing (breadcrumb only). Anything mounted
# is a plain bash script sourced via `bash $f` with the same common.sh env.
#
# usage: TIER=<calendar|hour|subhour> jobs/cadence-tick.sh
set -u

# calendar subdir pick (2026-09-24 tier collapse, B3): the 05:00 firing
# runs daily; a 06:00 firing runs weekly on Mondays and monthly on the
# 1st (both when the 1st is a Monday). Hour-aware so the one calendar
# timer preserves every old day/week/month firing instant exactly.
# CADENCE_PICK_ECHO=1 prints the pick for `date -u` and exits — the pin
# seam (automation/tests/test-cadence-collapse.sh).
calendar_pick() { # hh dow dom -> subdir names, one per line
  if [ "$1" = "05" ]; then
    echo daily
    return 0
  fi
  if [ "$1" = "06" ]; then
    [ "$2" = "1" ] && echo weekly
    [ "$3" = "01" ] && echo monthly
  fi
  return 0
}
if [ "${CADENCE_PICK_ECHO:-0}" = "1" ]; then
  read -r _hh _dow _dom <<<"$(date -u '+%H %u %d')"
  calendar_pick "$_hh" "$_dow" "$_dom"
  exit 0
fi

. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

# Bailiff (plan 2026-09-22-federal-branches-occupancy step 1): every tier
# halts while the watch audit has findings. Fail closed on findings, fail
# open on fault (inside bailiff_check). Tick stays exit 0 — the halt is a
# skip-with-crumb, same contract as tick-skip.
. "$AUTOMATION_ROOT/lib/bailiff.sh"
bailiff_check || exit 0

TIER="${TIER:-}"
case "$TIER" in
subhour | hour | calendar) ;;
*)
  echo "cadence-tick: TIER must be one of calendar|hour|subhour (got '${TIER}')" >&2
  exit 2
  ;;
esac

# RAM belt (plan 2026-09-22-ram-guardrails-dashboard-controls step 2):
# rapid tier only — calendar/hour drop-ins are cheap reporting
# that never spawn sessions, so gating them would be pure overhead.
# Below the floor the tick is skipped whole: fail-closed, exit 0.
case "$TIER" in
subhour)
  . "$AUTOMATION_ROOT/lib/memory-gate.sh"
  memory_gate || exit 0
  ;;
esac

# per-tier serialization: one tick at a time, drop the run if one is live
LOCK="/tmp/hngh-cadence-${TIER}.lock"
exec 9>"$LOCK"
flock -n 9 || {
  breadcrumb "$JOB_NAME" "tick-skip" "tier $TIER already ticking (flock held)"
  exit 0
}

# --- mounted work for this tier (drop-ins; absent tier does nothing) ---
shopt -s nullglob
ran=0
TIMING_LOG="$AUTOMATION_ROOT/logs/drop-in-timing.log"
mkdir -p "$AUTOMATION_ROOT/logs"
DIRS="$TIER"
if [ "$TIER" = "calendar" ]; then
  read -r _hh _dow _dom <<<"$(date -u '+%H %u %d')"
  DIRS=""
  for _sub in $(calendar_pick "$_hh" "$_dow" "$_dom"); do
    DIRS="$DIRS calendar/$_sub"
  done
fi
for _d in $DIRS; do
  for f in "$AUTOMATION_ROOT/cadence/$_d"/*.sh; do
    breadcrumb "$JOB_NAME" "mounted" "tier $TIER launching $f"
    t0=$(date +%s.%N)
    bash "$f" || breadcrumb "$JOB_NAME" "dropin-fail" "$f rc=$?"
    t1=$(date +%s.%N)
    # actual wall per drop-in run — the time ledger's dropin:<name> source
    wall=$(awk "BEGIN{printf \"%.3f\", $t1 - $t0}")
    printf '%s|%s|%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
      "$(basename "$f")" "$wall" >>"$TIMING_LOG"
    ran=$((ran + 1))
  done
done

if [ "$ran" = "0" ]; then
  breadcrumb "$JOB_NAME" "nothing-mounted" "tier $TIER has no mounted work"
else
  breadcrumb "$JOB_NAME" "tick-done" "tier $TIER ran $ran drop-in(s)"
fi
exit 0
