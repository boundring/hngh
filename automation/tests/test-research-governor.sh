#!/usr/bin/env bash
# test-research-governor.sh -- contract proofs for the idle-time research
# governor (Tier 3):
#   1. cadence/hour/33-research-beat.sh stamp gate + load guard matrix:
#      a beat runs only when BOTH gates pass (stale stamp AND load below
#      research-load-ceiling * nproc); a load defer exits 0 WITHOUT
#      consuming the stamp; the stamp gate fires before the load guard.
#   2. cadence/day/20-model-saturation.sh: empty telemetry -> one
#      "no data yet" row (identity-deduped on rerun); estimated and
#      measured busy-second fixtures produce the right peak/daily
#      utilization and headroom verdicts.
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
# the load-guard cases stay hermetic (no live DECK_URL/DECK_MODEL).
mkdir -p "$sb/lib" "$sb/cadence/hour"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/cadence/hour/33-research-beat.sh" "$sb/cadence/hour/"

run_beat() { # stamp_epoch loadavg_line [extra env as KEY=VAL...]
 local stamp="$1" load="$2"
 shift 2
 rm -rf "$sb/beat"
 mkdir -p "$sb/beat"
 : >"$sb/beat/STATE.md"
 printf '%s\n' "$load" >"$sb/beat/loadavg"
 printf '%s\n' "$stamp" >"$sb/beat/stamp"
 env -i PATH="$PATH" HOME="$HOME" \
  STATE_FILE="$sb/beat/STATE.md" \
  RESEARCH_STAMP_FILE="$sb/beat/stamp" \
  RESEARCH_LOADAVG_FILE="$sb/beat/loadavg" \
  RESEARCH_BEAT_HOURS=1 RESEARCH_BEAT_GATE_ONLY=1 \
  "$@" \
  bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
}

now="$(date +%s)"
stale=$((now - 7200))

# case 1: fresh stamp + load above ceiling -> stamp gate wins, no defer,
# stamp untouched (guard never reached: gate order is stamp first)
run_beat "$now" "12.00 3.00 1.00 5/900 1234"
need test ! -s "$sb/beat/STATE.md"
need test "$(cat "$sb/beat/stamp")" = "$now"
ok "fresh stamp + busy: stamp gate exits before the load guard"

# case 2: stale stamp + load above ceiling -> deferred breadcrumb, NO
# stamp write (defer does not consume the slot; next hour retries)
run_beat "$stale" "12.00 3.00 1.00 5/900 1234"
need grep -q 'research-deferred' "$sb/beat/STATE.md"
need grep -q 'research deferred: load 12.00 >= ceiling' "$sb/beat/STATE.md"
need grep -q '(machine busy)' "$sb/beat/STATE.md"
need test "$(cat "$sb/beat/stamp")" = "$stale"
ok "stale stamp + busy: deferred without consuming the stamp"

# case 3: stale stamp + load below ceiling -> beat runs (gate-only seam
# exits after the trap arms), stamp consumed
run_beat "$stale" "0.50 0.20 0.10 1/900 1234"
grep -q 'research-deferred' "$sb/beat/STATE.md" && {
 echo "FAIL: idle machine deferred a beat"
 exit 1
}
[ "$(cat "$sb/beat/stamp")" != "$stale" ] || {
 echo "FAIL: passing run did not stamp"
 exit 1
}
ok "stale stamp + idle: beat runs and stamps"

# case 4: fresh stamp + idle -> stamp gate wins before the guard
run_beat "$now" "0.50 0.20 0.10 1/900 1234"
need test ! -s "$sb/beat/STATE.md"
ok "fresh stamp + idle: stamp gate only"

# case 5: env override RESEARCH_LOAD_CEILING tightens the ceiling
# (0.01 * nproc); the same low load that passed case 3 now defers
limit="$(awk -v n="$(nproc)" 'BEGIN{printf "%.2f", 0.01 * n}')"
run_beat "$stale" "0.50 0.20 0.10 1/900 1234" RESEARCH_LOAD_CEILING=0.01
need grep -q "research deferred: load 0.50 >= ceiling $limit" "$sb/beat/STATE.md"
ok "RESEARCH_LOAD_CEILING env override + per-cpu math"

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
  HNGH_TELEMETRY_DB="$1" \
  bash "$root/cadence/day/20-model-saturation.sh" >/dev/null 2>&1
 cat "$sb/sat/root/docs/project/reports.md" 2>/dev/null
}

fresh_db() {
 rm -f "$sb/sat.db"
 sqlite3 "$sb/sat.db" "$SCHEMA"
 printf '%s' "$sb/sat.db"
}

hour="$(date -u +%Y-%m-%dT%H)"

# case 6: empty store -> "no data yet", once (identity dedup on rerun)
db="$(fresh_db)"
rows="$(run_sat "$db")"
need grep -q 'no data yet' <<<"$rows"
rows="$(run_sat "$db")"
need test "$(grep -c 'model-saturation' <<<"$rows")" = 1
ok "empty telemetry: 'no data yet' filed once (identity dedup)"

# case 7: estimated basis, 40% peak -> headroom ok
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 240 # est = mean research wall = 240
for m in 1 2 3 4 5 6; do emit "$db" "$hour:10:0${m}Z" model; done
rows="$(run_sat "$db")"
need grep -q 'basis: calls x 240s estimate (model events carry no wall-s)' <<<"$rows"
need grep -q 'peak hour .* at 40.0% utilization, daily total 40.0%' <<<"$rows"
need grep -q 'headroom ok (<50%)' <<<"$rows"
ok "40% estimated peak: headroom ok"

# case 8: estimated basis, 60% peak -> approaching saturation
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 240
for m in 1 2 3 4 5 6 7 8 9; do emit "$db" "$hour:10:0${m}Z" model; done
rows="$(run_sat "$db")"
need grep -q 'approaching saturation (50-80%)' <<<"$rows"
ok "60% estimated peak: approaching saturation"

# case 9: estimated basis, 85% peak -> saturated
db="$(fresh_db)"
emit "$db" "$hour:05:00Z" research 60
for m in $(seq 1 51); do emit "$db" "$hour:11:$(printf '%02d' "$m"):00Z" model; done
rows="$(run_sat "$db")"
need grep -q 'saturated (>80%) - acceleration has hit the model-server ceiling' <<<"$rows"
ok "85% estimated peak: saturated"

# case 10: measured wall-s sums take precedence over the estimate
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

echo "research governor contract: all cases passed"
