#!/usr/bin/env bash
# cadence-tick — one cadence-continuum tick for a single tier.
# Single-tick + per-tier flock keeps each tier serial and prevents
# overlapping ticks compounding across the 1m/5m/10m rapid tiers (the
# cadence-continuum "timer sprawl" risk). Fail-closed: exits 0.
#
# Mounted work: drop-ins at cadence/<tier>/*.sh are run in lexical order;
# an empty/absent tier dir does nothing (breadcrumb only). Anything mounted
# is a plain bash script sourced via `bash $f` with the same common.sh env.
#
# usage: TIER=<month|week|day|hour|30m|10m|5m|1m> jobs/cadence-tick.sh
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

TIER="${TIER:-}"
case "$TIER" in
month | week | day | hour | 30m | 10m | 5m | 1m) ;;
*)
  echo "cadence-tick: TIER must be one of month|week|day|hour|30m|10m|5m|1m (got '${TIER}')" >&2
  exit 2
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
for f in "$AUTOMATION_ROOT/cadence/$TIER"/*.sh; do
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

if [ "$ran" = "0" ]; then
  breadcrumb "$JOB_NAME" "nothing-mounted" "tier $TIER has no mounted work"
else
  breadcrumb "$JOB_NAME" "tick-done" "tier $TIER ran $ran drop-in(s)"
fi
exit 0
