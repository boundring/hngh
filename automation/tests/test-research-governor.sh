#!/usr/bin/env bash
# test-research-governor.sh -- contract proofs for the fail-first research
# gate (2026-09-07; replaces the stamp-gate matrix):
#   1. cadence/hour/33-research-beat.sh fail-first + routing matrix: a
#      beat with fresh state runs at FULL speed (no stamp gate); a
#      degraded operation paces the next tick; busy local never defers --
#      it routes (deck when responsive, quota leg when not); the shared
#      flock skips a beat that arrives mid-run.
#   2. cadence/day/20-model-saturation.sh: empty telemetry -> one
#      "no data yet" row (identity-deduped on rerun); estimated and
#      measured busy-second fixtures produce the right peak/daily
#      utilization and headroom verdicts; the failfirst tuning state
#      summary appears in the row.
# Hermetic: sandbox dirs only, no model chain, no live telemetry, no
# STATE.md, no report queue in any real repo.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT

ok() { echo "ok: $1"; }
need() { "$@" || {
 echo "FAIL: $*"
 exit 1
}; } # every case fatal

# sandbox copy: the beat derives common.sh (and thus config.env, which
# arms the live deck leg) from its own path -- run the copy from $sb so
# the routing cases stay hermetic (no live DECK_URL/DECK_MODEL).
mkdir -p "$sb/lib" "$sb/cadence/hour" "$sb/ff" "$sb/ff-empty"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/cadence/hour/33-research-beat.sh" "$sb/cadence/hour/"

# ff_seed SPEED: write a failfirst state file directly (the documented
# key=value format the instrument reads too).
ff_seed() { # speed lastrun_age_s
 local speed="$1" age="${2:-0}"
 local now
 now="$(date +%s)"
 printf 'speed=%s\noks=0\nlast=degraded\nceiling=1\nlastrun=%s\nn_ok=0\nn_deg=1\nn_fail=0\n' \
  "$speed" "$((now - age))" >"$sb/ff/failfirst-research"
}

run_beat() { # loadavg_line [extra env as KEY=VAL...]
 local load="$1"
 shift
 rm -rf "$sb/beat"
 mkdir -p "$sb/beat"
 : >"$sb/beat/STATE.md"
 rm -f "$sb/beat/stamp"
 printf '%s\n' "$load" >"$sb/beat/loadavg"
 env -i PATH="$PATH" HOME="$HOME" \
  STATE_FILE="$sb/beat/STATE.md" \
  RESEARCH_STAMP_FILE="$sb/beat/stamp" \
  RESEARCH_LOADAVG_FILE="$sb/beat/loadavg" \
  FAILFIRST_STATE_DIR="$sb/ff" \
  RESEARCH_LOCK_FILE="${RESEARCH_LOCK_FILE_OVERRIDE:-$sb/beat/lock}" \
  RESEARCH_BEAT_GATE_ONLY=1 \
  "$@" \
  bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
}

idle="0.50 0.20 0.10 1/900 1234"
busy="12.00 3.00 1.00 5/900 1234"

# case 1: fresh failfirst state (full speed) + idle -> beat runs; no
# stamp gate: a fresh state GOes every tick, stamp written by the trap
rm -f "$sb/ff/failfirst-research"
run_beat "$idle"
need test -s "$sb/beat/stamp"
ok "fresh state + idle: full speed runs, no stamp gate"

# case 2: full speed + busy + no armed deck -> ROUTES to a quota leg,
# never defers; the run still happens (stamp written)
run_beat "$busy"
need grep -q 'research-route-quota' "$sb/beat/STATE.md"
grep -q 'research-deferred' "$sb/beat/STATE.md" && {
 echo "FAIL: busy machine deferred a beat (fail-first routes, never defers)"
 exit 1
}
need test -s "$sb/beat/stamp"
ok "fresh state + busy: routed to quota leg, no defer"

# case 3: busy + UNREACHABLE deck URL -> deck probe fails, falls through
# to the quota route (any HTTP answer counts as responsive; transport
# failure does not)
run_beat "$busy" DECK_URL=http://127.0.0.1:1 DECK_PROBE_TIMEOUT=1
need grep -q 'research-route-quota' "$sb/beat/STATE.md"
grep -q 'routed to deck' "$sb/beat/STATE.md" && {
 echo "FAIL: unreachable deck was treated as responsive"
 exit 1
}
ok "busy + unreachable deck: quota route fall-through"

# case 4: degraded operation (standard speed, lastrun fresh) -> the next
# tick THROTTLES: no run, no stamp
ff_seed 2 0
run_beat "$idle"
need test ! -s "$sb/beat/stamp"
need grep -q 'research-throttled' "$sb/beat/STATE.md"
ok "degraded state: next tick throttles"

# case 5: standard speed aged past 2 ticks (FAILFIRST_TICK_S=3600) -> GO
ff_seed 2 7201
run_beat "$idle"
need test -s "$sb/beat/stamp"
ok "standard speed after 2 ticks: gate releases"

# case 6: RESEARCH_LOAD_CEILING env override tightens the routing
# threshold (0.01 * nproc)
rm -f "$sb/ff/failfirst-research"
limit="$(awk -v n="$(nproc)" 'BEGIN{printf "%.2f", 0.01 * n}')"
run_beat "0.50 0.20 0.10 1/900 1234" RESEARCH_LOAD_CEILING=0.01
need grep -q "load 0.50 >= ceiling $limit" "$sb/beat/STATE.md"
ok "RESEARCH_LOAD_CEILING env override + per-cpu math"

# case 7: shared flock -- a beat arriving while another holds the lock
# skips silently (race prevention, not a throttle: the next 15-minute
# overflow tick picks the work up)
rm -f "$sb/ff/failfirst-research"
( exec 9>"$sb/lock-ext"; flock 9; touch "$sb/locked"; sleep 5 ) &
lockpid=$!
while [ ! -e "$sb/locked" ]; do sleep 0.05; done
RESEARCH_LOCK_FILE_OVERRIDE="$sb/lock-ext" run_beat "$idle" RESEARCH_LOCK_WAIT=1
need test ! -s "$sb/beat/stamp"
kill "$lockpid" 2>/dev/null || true
wait "$lockpid" 2>/dev/null || true
ok "lock held elsewhere: beat skips without error"

# --- 20-model-saturation ---
SCHEMA="CREATE TABLE events(ts TEXT, source TEXT, kind TEXT, identity TEXT,
 lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out INTEGER,
 cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT, body TEXT)"
emit() { # db ts kind wall_s
 sqlite3 "$1" "insert into events(ts,kind,source,wall_s)
  values('$2','$3','test',${4:-NULL})"
}

run_sat() { # db -> prints the reports.md rows; report root $sb/sat/root
 rm -rf "$sb/sat"
 mkdir -p "$sb/sat"
 STATE_FILE="$sb/sat/STATE.md" HNGH_REPORT_ROOT="$sb/sat/root" \
  HNGH_TELEMETRY_DB="$1" FAILFIRST_STATE_DIR="$sb/ff-empty" \
  bash "$root/cadence/day/20-model-saturation.sh" >/dev/null 2>&1
 cat "$sb/sat/root/docs/project/reports.md" 2>/dev/null
}

fresh_db() {
 rm -f "$sb/sat.db"
 sqlite3 "$sb/sat.db" "$SCHEMA"
 printf '%s' "$sb/sat.db"
}

hour="$(date -u +%Y-%m-%dT%H)"

# case 8: empty store -> "no data yet", once (identity dedup on rerun)
db="$(fresh_db)"
rows="$(run_sat "$db")"
need grep -q 'no data yet' <<<"$rows"
rows="$(run_sat "$db")"
need test "$(grep -c 'model-saturation' <<<"$rows")" = 1
ok "empty telemetry: 'no data yet' filed once (identity dedup)"

# case 9: estimated basis, 40% peak -> headroom ok
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 240 # est = mean research wall = 240
for m in 1 2 3 4 5 6; do emit "$db" "$hour:10:0${m}Z" model; done
rows="$(run_sat "$db")"
need grep -q 'basis: calls x 240s estimate (model events carry no wall-s)' <<<"$rows"
need grep -q 'peak hour .* at 40.0% utilization, daily total 40.0%' <<<"$rows"
need grep -q 'headroom ok (<50%)' <<<"$rows"
ok "40% estimated peak: headroom ok"

# case 10: estimated basis, 60% peak -> approaching saturation
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 240
for m in 1 2 3 4 5 6 7 8 9; do emit "$db" "$hour:10:0${m}Z" model; done
rows="$(run_sat "$db")"
need grep -q 'approaching saturation (50-80%)' <<<"$rows"
ok "60% estimated peak: approaching saturation"

# case 11: estimated basis, 85% peak -> saturated
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 60
for m in $(seq 1 51); do emit "$db" "$hour:11:$(printf '%02d' "$m"):00Z" model; done
rows="$(run_sat "$db")"
need grep -q 'saturated (>80%) - acceleration has hit the model-server ceiling' <<<"$rows"
ok "85% estimated peak: saturated"

# case 12: measured wall-s sums take precedence over the estimate
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 1 # tiny est; must be ignored
emit "$db" "$hour:12:00Z" model 2000
emit "$db" "$hour:12:30Z" model 1000
rows="$(run_sat "$db")"
need grep -q 'basis: measured wall-s' <<<"$rows"
need grep -q 'at 83.3% utilization' <<<"$rows"
grep -q 'calls x' <<<"$rows" && {
 echo "FAIL: estimate used despite wall-s"
 exit 1
}
ok "measured wall-s basis: 3000s busy = 83.3% saturated"

# case 13: failfirst tuning state appears in the utilization row
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 240
for m in 1 2 3 4 5 6; do emit "$db" "$hour:10:0${m}Z" model; done
printf 'speed=2\noks=0\nlast=degraded\nceiling=1\nlastrun=0\nn_ok=7\nn_deg=1\nn_fail=0\n' \
 >"$sb/ff-empty/failfirst-research"
rows="$(run_sat "$db")"
need grep -q 'failfirst tuning (ceiling = speed at first degradation)' <<<"$rows"
need grep -q 'research=standard(ok=7,degraded=1,failed=0,ceiling=1)' <<<"$rows"
ok "saturation instrument reports the failfirst tuning state"

echo "research governor contract: all cases passed"
