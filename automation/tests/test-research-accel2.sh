#!/usr/bin/env bash
# test-research-accel2.sh -- sandbox proofs for research acceleration
# wave 2 (2026-09-07):
#   a) deck-pin-on-busy in 33-research-beat: busy load + armed deck leg
#      -> the run is PINNED to the deck (no defer, stamp consumed); busy
#      load + unarmed deck -> defers exactly as before, no stamp.
#   b) 30m/50-research-overflow: own-stamp fresh -> skip; stale own-stamp
#      + hour stamp <30min -> silent defer; stale + hour stamp >=30min ->
#      runs pinned kimi without consuming the hour stamp.
#   c) review interleave: counter %research-review-interleave reviews the
#      oldest crystallized line even with planned lines present; 0 or a
#      non-aligned counter advances the planned line.
#   d) demand synthesizer: empty pool + fixture sources -> sourced
#      synth-<date>-<n> subjects appended (unsourced ones discarded),
#      daily-capped second run skips synthesis and falls to the review
#      path.
# Hermetic: stub endpoints only, sandbox repo copy, no real model, no
# ~/.hngh writes, no live telemetry.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/jobs" "$sb/cadence" "$sb/archive" "$sb/dashboard" \
 "$sb/digest" "$sb/kernel/docs/research" "$sb/kernel/scripts" \
 "$sb/kernel/docs/project" "$sb/.config/hngh" "$sb/report-root"
cp -r "$root/lib/." "$sb/lib/"
cp -r "$root/jobs/telemetry.py" "$sb/jobs/"
cp -r "$root/cadence/." "$sb/cadence/"
cp "$HOME/Projects/etc/hngh/scripts/report-queue" "$sb/kernel/scripts/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
stub_start stubU # unsloth (local chain)
stub_start stubK # kimi
stub_start stubD # deck
stubU_port="$(cat "$stubdir/stubU-port")"
stubK_port="$(cat "$stubdir/stubK-port")"
stubD_port="$(cat "$stubdir/stubD-port")"
printf 'stub-token-never-real' >"$sb/unsloth-token"
kimi_env=("KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubK_port")
deck_env=("DECK_URL=http://127.0.0.1:$stubD_port" "DECK_MODEL=deck-test")

day="$(date -u +%Y-%m-%d)"
now="$(date +%s)"
busy="12.00 3.00 1.00 5/900 1234"
idle="0.10 0.20 0.10 1/900 1234"

BEAT_ENV=(
 AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=33-research-beat.sh
 HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root"
 RESEARCH_SYNTH_STAMP_FILE="$sb/synth-stamp"
 FAILFIRST_STATE_DIR="$sb/ff" RESEARCH_LOCK_FILE="$sb/lock"
 TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
 REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
 UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1
 OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096 KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
)
beat_run() { # [K=V ...] -> one hour-beat run; caller args win
 (
  cd "$sb"
  rm -f "$sb/beat-stamp"
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$sb/beat-count" \
   RESEARCH_LOADAVG_FILE="$sb/loadavg" \
   "$@" \
   bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
overflow_run() { # [K=V ...] -> one 30m-tier overflow run
 (
  cd "$sb"
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_OVERFLOW_STAMP_FILE="$sb/of-stamp" \
   RESEARCH_OVERFLOW_COUNT_FILE="$sb/of-count" \
   OVERFLOW_SLEEP_S=0 \
   "$@" \
   bash "$sb/cadence/30m/50-research-overflow.sh" >/dev/null 2>&1
 )
}
reset_beat() { # n-planned-lines -> fresh pool, counters, telemetry, hits
 rm -f "$sb/beat-stamp" "$sb/beat-count" "$sb/of-stamp" "$sb/of-count" \
  "$sb/tmp-modelused.txt" "$sb/synth-stamp" "$sb/research-dispositions.tsv" \
  "$sb/lock"
 rm -rf "$sb/ff"
 rm -f "$stubdir/synth-reply"
 : >"$sb/STATE.md"
 rm -f "$sb/dashboard/telemetry.db"
 : >"$stubdir/stubU-hits"
 : >"$stubdir/stubK-hits"
 : >"$stubdir/stubD-hits"
 : >"$sb/research-subjects.txt"
 local i
 {
  for i in $(seq 1 "$1"); do
   printf 'line-%s\tplanned\t%s\tdesc-%s\n' "$i" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$i"
  done
 } >"$sb/research-lines.tsv"
 printf '%s\n' "$idle" >"$sb/loadavg"
}
seed_crystallized() { # id -> crystallized row + doc for review paths
 printf '%s\tcrystallized\t2026-09-06T00:00:00Z\tdesc-%s\n' "$1" "$1" \
  >>"$sb/research-lines.tsv"
 printf 'doc-%s\n' "$1" >"$sb/kernel/docs/research/2026-09-06-$1.md"
}
hits() { wc -l <"$stubdir/$1-hits" | tr -d ' '; }
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

# --- a) busy routing (fail-first: route, never defer) -------------------
# a1: busy + deck armed -> run pinned to the deck, no defer, stamp eaten
reset_beat 2
printf '%s\n' "$busy" >"$sb/loadavg-busy"
beat_run "${deck_env[@]}" "RESEARCH_LOADAVG_FILE=$sb/loadavg-busy"
ck "busy+deck: deck stub answered" "1" "$(hits stubD)"
ck "busy+deck: unsloth never hit" "0" "$(hits stubU)"
ck "busy+deck: model used = deck" "deck:deck-test" "$(cat "$sb/tmp-modelused.txt")"
grep -q 'research-route-deck' "$sb/STATE.md" &&
 grep -q 'local busy - research routed to deck (load 12.00 >= ' "$sb/STATE.md" &&
 echo "ok: busy+deck: routed-to-deck breadcrumb" || {
 echo "FAIL: busy+deck: no routed-to-deck breadcrumb"
 fails=$((fails + 1))
}
grep -q $'line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: busy+deck: run completed (line-1 planned->expanding)" || {
 echo "FAIL: busy+deck: line-1 not advanced"
 fails=$((fails + 1))
}
[ "$(cat "$sb/beat-stamp" 2>/dev/null)" != "" ] &&
 echo "ok: busy+deck: stamp consumed" || {
 echo "FAIL: busy+deck: stamp not consumed"
 fails=$((fails + 1))
}

# a2: busy + deck unarmed -> routes to a quota leg by parity; the quota
# pin is unarmed too, so model_call falls through to the local chain:
# the machine NEVER stops researching because the desktop is busy
reset_beat 2
printf '%s\n' "$busy" >"$sb/loadavg-busy"
beat_run "RESEARCH_LOADAVG_FILE=$sb/loadavg-busy"
grep -q 'research-route-quota' "$sb/STATE.md" &&
 grep -q 'local busy - research routed to' "$sb/STATE.md" &&
 echo "ok: busy+unarmed: quota route breadcrumb" || {
 echo "FAIL: busy+unarmed: no quota route breadcrumb"
 fails=$((fails + 1))
}
grep -q 'research-deferred' "$sb/STATE.md" && {
 echo "FAIL: busy+unarmed: deferred (fail-first never defers)"
 fails=$((fails + 1))
} || echo "ok: busy+unarmed: no defer"
ck "busy+unarmed: run completed on local fallthrough" "1" "$(hits stubU)"
grep -q $'line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: busy+unarmed: line-1 advanced" || {
 echo "FAIL: busy+unarmed: line-1 not advanced"
 fails=$((fails + 1))
}

# --- b) overflow beat: 15-minute cadence, own failfirst state -----------
# b1: full speed -> TWO beats per 30m tick (OVERFLOW_SLEEP_S=0), both
# pinned kimi; a pace-blocked kimi falls through to the local chain inside
# model_call (never blocks)
reset_beat 4
overflow_run "${kimi_env[@]}"
ck "overflow: kimi answered on both beats" "2" "$(hits stubK)"
ck "overflow run2: kimi answers" "kimi:kimi-test-model" \
 "$(cat "$sb/tmp-modelused.txt")"
ck "overflow run2: unsloth never hit" "0" "$(hits stubU)"
# pick_line finishes lines before starting them: beat 1 advances
# line-1 planned->expanding, beat 2 advances line-1 expanding->contracting
grep -q $'line-1\tcontracting\t' "$sb/research-lines.tsv" &&
 echo "ok: overflow: both beats advanced line-1" || {
 echo "FAIL: overflow: line-1 not advanced twice"
 fails=$((fails + 1))
}
[ -f "$sb/ff/failfirst-research-overflow" ] &&
 echo "ok: overflow: own tuning state file" || {
 echo "FAIL: overflow: no separate tuning state"
 fails=$((fails + 1))
}
[ ! -e "$sb/ff/failfirst-research" ] &&
 echo "ok: overflow: hour operation state untouched" || {
 echo "FAIL: overflow: wrote to the hour operation state"
 fails=$((fails + 1))
}
ck "overflow: state says ok at full" "ok" "$(sed -n 's/^last=//p' "$sb/ff/failfirst-research-overflow")"

# b2: degraded overflow operation -> both beats of the tick throttle
# (15-minute tick: standard paces to 30 minutes)
reset_beat 4
(
 export FAILFIRST_STATE_DIR="$sb/ff"
 . "$root/lib/params.sh"
 . "$root/lib/failfirst.sh"
 record_outcome research-overflow 1 degraded
)
overflow_run "${kimi_env[@]}"
ck "overflow degraded: kimi never hit" "0" "$(hits stubK)"
ck "overflow degraded: unsloth never hit" "0" "$(hits stubU)"
grep -q 'research-overflow-throttled' "$sb/STATE.md" &&
 echo "ok: overflow degraded: throttled breadcrumb" || {
 echo "FAIL: overflow degraded: no throttle breadcrumb"
 fails=$((fails + 1))
}
ck "overflow degraded: still standard speed" "2" \
 "$(sed -n 's/^speed=//p' "$sb/ff/failfirst-research-overflow")"

# b3: standard speed aged past 2 overflow ticks (2*900s) -> gate releases
# (kimi count restarted at 0 by b2's reset_beat)
printf '%s\n' "$((now - 1801))" >"$sb/of-stamp"
sed -i "s/^lastrun=.*/lastrun=$((now - 1801))/" "$sb/ff/failfirst-research-overflow"
overflow_run "${kimi_env[@]}"
ck "overflow aged: gate released, kimi pinned" "1" "$(hits stubK)"

# --- c) review interleave ------------------------------------------------
# c1: counter 2 -> run 3, 3%3=0 (default interleave 3), crystallized
# line present -> REVIEW even with planned lines available
reset_beat 8
seed_crystallized line-old
printf '%s\n' 2 >"$sb/beat-count"
beat_run "${kimi_env[@]}" RESEARCH_REVIEW_INTERLEAVE=3
ck "interleave %3: review pinned kimi" "1" "$(hits stubK)"
ck "interleave %3: unsloth never hit" "0" "$(hits stubU)"
grep -q $'line-old\treviewed\t' "$sb/research-lines.tsv" &&
 echo "ok: interleave %3: oldest crystallized reviewed" || {
 echo "FAIL: interleave %3: line-old not reviewed"
 fails=$((fails + 1))
}
grep -q $'line-1\tplanned\t' "$sb/research-lines.tsv" &&
 echo "ok: interleave %3: planned line NOT advanced" || {
 echo "FAIL: interleave %3: planned line advanced during review"
 fails=$((fails + 1))
}
grep -q $'line-old\tparked\t' "$sb/research-dispositions.tsv" 2>/dev/null &&
 echo "ok: interleave %3: disposition appended" || {
 echo "FAIL: interleave %3: no disposition row"
 fails=$((fails + 1))
}

# c2: interleave=0 -> never review while planned lines exist
reset_beat 8
seed_crystallized line-old
printf '%s\n' 3 >"$sb/beat-count"
beat_run "${kimi_env[@]}" RESEARCH_REVIEW_INTERLEAVE=0
ck "interleave 0: kimi never hit" "0" "$(hits stubK)"
grep -q $'line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: interleave 0: planned line advanced" || {
 echo "FAIL: interleave 0: planned line not advanced"
 fails=$((fails + 1))
}
grep -q $'line-old\tcrystallized\t' "$sb/research-lines.tsv" &&
 echo "ok: interleave 0: crystallized line untouched" || {
 echo "FAIL: interleave 0: crystallized line touched"
 fails=$((fails + 1))
}

# c3: aligned interleave but counter not at %3 -> normal advance
reset_beat 8
seed_crystallized line-old
printf '%s\n' 0 >"$sb/beat-count"
beat_run "${kimi_env[@]}"
ck "counter 1 (1%3): kimi never hit" "0" "$(hits stubK)"
grep -q $'line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: counter 1: planned line advanced (no review)" || {
 echo "FAIL: counter 1: planned line not advanced"
 fails=$((fails + 1))
}

# --- d) demand synthesizer ----------------------------------------------
synth_fixtures() { # -> dispositions + lessons + backlog + alert identity
 mkdir -p "$sb/docs"
 {
  printf 'line\taction\tverdict\treviewer\tevidence\tdate\n'
  printf 'loop-recognition\tkilled\tduplicate class\tmodel:kimi\tdocs/x.md\t%s\n' "$day"
 } >"$sb/research-dispositions.tsv"
 {
  printf '# Lessons index\n\n'
  printf '| Lesson | Blocker | Evidence | Change landed | Guardrail added |\n'
  printf '|---|---|---|---|---|\n'
  printf '| ledger-sync commit race | staged copies race | docs/y.md | none | lane discipline |\n'
 } >"$sb/kernel/docs/project/lessons-index.md"
 printf '## Router dedup backlog (2026-09-07)\n\nbody text\n' >"$sb/docs/BACKLOG.md"
 HNGH_REPORT_ROOT="$sb/report-root" \
  python3 "$sb/kernel/scripts/report-queue" --add alert "probe alert text" \
  --identity 'stale-store:probe' --window 0 >/dev/null 2>&1
}
empty_pool() { # -> every line reviewed, subjects empty
 printf 'old-1\treviewed\t2026-09-05T00:00:00Z\tdesc-old-1\n' \
  >"$sb/research-lines.tsv"
 : >"$sb/research-subjects.txt"
}
# d1: empty pool + sourced reply -> 2 sourced subjects appended (the
# unsourced third line discarded), beat then advances the first synth line
reset_beat 0
synth_fixtures
empty_pool
printf 'synth-%s-1\tHow does the loop-recognition disposition change router dedup?\nsynth-%s-2\tApply the ledger-sync commit race lesson to staging discipline?\nsynth-%s-3\tGeneric filler question citing nothing recognizable.\n' \
 "$day" "$day" "$day" >"$stubdir/synth-reply"
beat_run "${kimi_env[@]}"
grep -q "synth-$day-1" "$sb/research-subjects.txt" &&
 grep -q "synth-$day-2" "$sb/research-subjects.txt" &&
 echo "ok: synth: sourced subjects appended" || {
 echo "FAIL: synth: sourced subjects not appended"
 fails=$((fails + 1))
}
grep -q "synth-$day-3" "$sb/research-subjects.txt" && {
 echo "FAIL: synth: unsourced subject appended"
 fails=$((fails + 1))
} || echo "ok: synth: unsourced subject discarded"
ck "synth: daily stamp written" "$day" "$(cat "$sb/synth-stamp")"
grep -q "synth-$day-1	expanding" "$sb/research-lines.tsv" &&
 echo "ok: synth: synthesized line picked up and advanced" || {
 echo "FAIL: synth: synthesized line not advanced"
 fails=$((fails + 1))
}
grep -q 'research-synth ' "$sb/STATE.md" &&
 echo "ok: synth: breadcrumb filed" || {
 echo "FAIL: synth: no breadcrumb"
 fails=$((fails + 1))
}

# d2: synth already stamped today -> capped; falls to the review path
# (crystallized line present, no synthesis call)
reset_beat 0
synth_fixtures
printf 'old-1\treviewed\t2026-09-05T00:00:00Z\tdesc-old-1\n' >"$sb/research-lines.tsv"
seed_crystallized line-old
printf '%s\n' "$day" >"$sb/synth-stamp"
beat_run "${kimi_env[@]}"
ck "synth capped: unsloth never hit (no synthesis call)" "0" "$(hits stubU)"
ck "synth capped: review ran on kimi" "1" "$(hits stubK)"
grep -q $'line-old\treviewed\t' "$sb/research-lines.tsv" &&
 echo "ok: synth capped: fell through to review path" || {
 echo "FAIL: synth capped: review path not taken"
 fails=$((fails + 1))
}

# d3: unsourced-only reply -> nothing appended, skip path
reset_beat 0
synth_fixtures
empty_pool
printf 'synth-%s-1\tWholly unrelated musing about the weather.\n' "$day" \
 >"$stubdir/synth-reply"
beat_run "${kimi_env[@]}"
ck "synth unsourced: subjects unchanged" "0" "$(wc -l <"$sb/research-subjects.txt" | tr -d ' ')"
grep -q 'research-synth-empty' "$sb/STATE.md" &&
 echo "ok: synth unsourced: empty-parse breadcrumb" || {
 echo "FAIL: synth unsourced: no empty-parse breadcrumb"
 fails=$((fails + 1))
}
grep -q 'research-skip' "$sb/STATE.md" &&
 echo "ok: synth unsourced: fell to skip path" || {
 echo "FAIL: synth unsourced: skip path not taken"
 fails=$((fails + 1))
}

[ "$fails" = 0 ] && echo "test-research-accel2: all pass" || {
 echo "test-research-accel2: $fails failure(s)"
 exit 1
}
