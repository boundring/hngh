#!/usr/bin/env bash
# test-failfirst.sh -- contract proofs for the fail-first self-tuning
# engine (lib/failfirst.sh), 2026-09-07:
#   a) state machine: fresh state -> GO at full; degraded -> demote one
#      level + pace; 3 consecutive oks at standard -> promote to full;
#      failed -> drop to cautious + alert row; observed ceiling recorded
#      at first degradation only; FAILFIRST_PROMOTE_THRESHOLD override;
#      cautious pacing is 4 ticks; per-operation state isolation.
#   b) saturation feed: the state files the day instrument reads carry
#      the outcome counts it reports.
# Hermetic: sandbox state dir only, no model chain, no real repos.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/ff"

ok() { echo "ok: $1"; }
need() { "$@" || {
 echo "FAIL: $*"
 exit 1
}; } # every case fatal

ff() { # run one failfirst command in a clean shell with the sandbox state
 local expr="$1"
 FAILFIRST_STATE_DIR="$sb/ff" bash -c "
  . '$root/lib/params.sh'
  . '$root/lib/failfirst.sh'
  file_report() { # alert capture: kind text identity window
   printf '%s|%s|%s\n' \"\$1\" \"\$2\" \"\$3\" >>'$sb/alerts'
  }
  $expr
 "
}

ff_env() { # run one failfirst command with extra env (AUTOMATION_ROOT etc)
 local expr="$1"
 shift
 env "$@" FAILFIRST_STATE_DIR="$sb/ff" bash -c "
  . '$root/lib/params.sh'
  . '$root/lib/failfirst.sh'
  breadcrumb() { :; } # failed-outcome alert fallback: silent in this test
  $expr
 "
}

state() { # op key -> value from the state file
 sed -n "s/^$2=//p" "$sb/ff/failfirst-$1"
}

# --- a) state machine ----------------------------------------------------

# a1: fresh state -> GO at full speed; gate stamps lastrun
v="$(ff 'failfirst_gate research')"
need test "$v" = "GO"
need test "$(state research speed)" = "1"
need test "$(state research last)" = "none"
ok "fresh state: GO at full speed"

# a2: full speed always GOes -- no pacing at level 1
v="$(ff 'failfirst_gate research')"
need test "$v" = "GO"
ok "full speed: runs every tick"

# a3: degraded -> demote to standard, ceiling recorded at first hit
ff 'record_outcome research 1 degraded'
need test "$(state research speed)" = "2"
need test "$(state research ceiling)" = "1"
need test "$(state research last)" = "degraded"
v="$(ff 'failfirst_gate research')"
need test "$v" = "THROTTLE:speed-2"
ok "degraded: demote to standard, next tick throttles"

# a4: standard pacing releases after 2 ticks (FAILFIRST_TICK_S=3600)
ff 'record_outcome research 2 ok' # a paced run records its outcome
sed -i "s/^lastrun=.*/lastrun=$(($(date +%s) - 1800))/" "$sb/ff/failfirst-research"
v="$(ff 'failfirst_gate research')"
need test "$v" = "THROTTLE:speed-2"
sed -i "s/^lastrun=.*/lastrun=$(($(date +%s) - 7201))/" "$sb/ff/failfirst-research"
v="$(ff 'failfirst_gate research')"
need test "$v" = "GO"
ok "standard: paces to every 2nd tick, then releases"

# a5: 3 consecutive oks at standard -> promote to full (additive increase)
ff 'record_outcome research 2 ok' # oks=2 (a4 recorded the first)
need test "$(state research speed)" = "2"
ff 'record_outcome research 2 ok' # oks=3 -> promote
need test "$(state research speed)" = "1"
v="$(ff 'failfirst_gate research')"
need test "$v" = "GO"
ok "3 oks at standard: promote to full"

# a6: second degradation -> cautious; ceiling stays at the FIRST hit
ff 'record_outcome research 1 degraded; record_outcome research 2 degraded'
need test "$(state research speed)" = "3"
need test "$(state research ceiling)" = "1"
ok "second degradation: cautious; ceiling pinned at first"

# a7: cautious pacing is 4 ticks
ff 'record_outcome research 3 ok' # the a7 paced run records its outcome (oks=1)
v="$(ff 'failfirst_gate research')"
need test "$v" = "THROTTLE:speed-3"
sed -i "s/^lastrun=.*/lastrun=$(($(date +%s) - 14401))/" "$sb/ff/failfirst-research"
v="$(ff 'failfirst_gate research')"
need test "$v" = "GO"
ok "cautious: paces to every 4th tick"

# a8: failed -> drop to cautious + alert row through file_report
rm -f "$sb/alerts"
ff 'record_outcome research 2 failed'
need test "$(state research speed)" = "3"
need test "$(state research last)" = "failed"
need grep -q '^alert|failfirst research: script error at speed 2 - dropped to cautious|failfirst-research:script-error$' \
 "$sb/alerts"
ok "failed: cautious + alert row"

# a9: FAILFIRST_PROMOTE_THRESHOLD override (1 ok promotes immediately)
ff 'FAILFIRST_PROMOTE_THRESHOLD=1 record_outcome research 1 degraded'
need test "$(state research speed)" = "2"
ff 'FAILFIRST_PROMOTE_THRESHOLD=1 record_outcome research 2 ok'
need test "$(state research speed)" = "1"
ok "threshold override 1: one ok promotes"

# a10: operations are isolated -- overflow state untouched by research
ff 'record_outcome research 1 degraded'
need test ! -e "$sb/ff/failfirst-research-overflow"
ff 'record_outcome research-overflow 1 ok'
need test "$(state research-overflow speed)" = "1"
need test "$(state research speed)" = "2"
ok "per-operation state isolation"

# --- b) saturation feed ---------------------------------------------------

# b1: outcome counters accumulate for the day instrument
ff 'record_outcome research-overflow 2 ok; record_outcome research-overflow 2 degraded'
need test "$(state research-overflow n_ok)" = "2"
need test "$(state research-overflow n_deg)" = "1"
need test "$(state research-overflow n_fail)" = "0"
ok "outcome counters accumulate"

# --- c) development tier: speeds map to CONCURRENCY -----------------------
# delegated sessions cost real money, so the same TCP state machine tunes
# how many sessions run per beat, inside the hard sessions-day-max ceiling.

# c1: fresh development state -> GO at full, 3 concurrent slots
v="$(ff 'failfirst_gate development')"
need test "$v" = "GO"
v="$(ff 'failfirst_concurrency development')"
need test "$v" = "3"
ok "development fresh: GO at full, 3 concurrent slots"

# c2: degraded -> demote to standard, 2 slots
ff 'record_outcome development 1 degraded'
need test "$(state development speed)" = "2"
v="$(ff 'failfirst_concurrency development')"
need test "$v" = "2"
ok "development degraded: standard, 2 slots"

# c3: 3 consecutive oks at standard -> promote to full, 3 slots
ff 'record_outcome development 2 ok; record_outcome development 2 ok; record_outcome development 2 ok'
need test "$(state development speed)" = "1"
v="$(ff 'failfirst_concurrency development')"
need test "$v" = "3"
ok "development 3 oks at standard: full, 3 slots"

# c4: failed (launch-plane crash) -> cautious, 1 slot + alert row
rm -f "$sb/alerts"
ff 'record_outcome development 2 failed'
need test "$(state development speed)" = "3"
need test "$(state development last)" = "failed"
v="$(ff 'failfirst_concurrency development')"
need test "$v" = "1"
need grep -q '^alert|failfirst development: script error at speed 2 - dropped to cautious|failfirst-development:script-error$' \
 "$sb/alerts"
ok "development failed: cautious, 1 slot + alert"

# c5: development state is isolated from research state
ff 'record_outcome research 1 ok'
need test "$(state development speed)" = "3"
need test "$(state research speed)" = "1"
ok "development and research state isolated"

# c6: Inventory rows drive the mapping (sandbox Inventory)
rm -f "$sb/ff/failfirst-development"
mkdir -p "$sb/inv"
printf '# Inventory\nfailfirst-dev-concurrent-full\t7\ttest\ttest row\nfailfirst-dev-concurrent-standard\t5\ttest\ttest row\nfailfirst-dev-concurrent-cautious\t2\ttest\ttest row\n' \
 >"$sb/inv/cadence-params.tsv"
v="$(ff_env 'failfirst_gate development; failfirst_concurrency development' \
 AUTOMATION_ROOT="$sb/inv" | tail -n1)"
need test "$v" = "7"
v="$(ff_env 'record_outcome development 1 degraded; failfirst_concurrency development' \
 AUTOMATION_ROOT="$sb/inv")"
need test "$v" = "5"
v="$(ff_env 'record_outcome development 2 failed; failfirst_concurrency development' \
 AUTOMATION_ROOT="$sb/inv")"
need test "$v" = "2"
ok "Inventory rows failfirst-dev-concurrent-* drive the mapping"

echo "failfirst engine contract: all cases passed"
