#!/usr/bin/env bash
# test-research-accel2.sh -- sandbox proofs for research acceleration
# wave 2 (2026-09-07):
#   a) deck-pin-on-busy in 33-research-beat: busy load + armed deck leg
#      -> the run is PINNED to the deck (no defer, stamp consumed); busy
#      load + unarmed deck -> defers exactly as before, no stamp.
#   b) 30m/50-research-overflow: own-stamp fresh -> skip; stale own-stamp
#      + hour stamp <30min -> silent defer; stale + hour stamp >=30min ->
#      runs pinned (odd counter kimi, even lobehub) without consuming the
#      hour stamp.
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
 TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
 REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
 UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1
 OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096 KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
 LOBEHUB_KEY_FILE="$sb/.config/hngh/lobehub-key"
)
beat_run() { # [K=V ...] -> one hour-beat run; caller args win
 (
  cd "$sb"
  rm -f "$sb/beat-stamp"
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$sb/beat-count" \
   RESEARCH_LOADAVG_FILE="$sb/loadavg" RESEARCH_BEAT_HOURS=1 \
   "$@" \
   bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
overflow_run() { # [K=V ...] -> one 30m-tier overflow run
 (
  cd "$sb"
  env -i PATH="$PATH" HOME="$sb" "${BEAT_ENV[@]}" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_LOADAVG_FILE="$sb/loadavg" \
   RESEARCH_BEAT_HOURS=1 \
   RESEARCH_OVERFLOW_STAMP_FILE="$sb/of-stamp" \
   RESEARCH_BEAT_STAMP_FILE="$sb/beat-stamp" \
   RESEARCH_OVERFLOW_COUNT_FILE="$sb/of-count" \
   "$@" \
   bash "$sb/cadence/30m/50-research-overflow.sh" >/dev/null 2>&1
 )
}
reset_beat() { # n-planned-lines -> fresh pool, counters, telemetry, hits
 rm -f "$sb/beat-stamp" "$sb/beat-count" "$sb/of-stamp" "$sb/of-count" \
  "$sb/tmp-modelused.txt" "$sb/synth-stamp" "$sb/research-dispositions.tsv" \
  "$stubdir/synth-reply"
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

# --- a) deck-pin-on-busy ------------------------------------------------
# a1: busy + deck armed -> run pinned to the deck, no defer, stamp eaten
reset_beat 2
printf '%s\n' "$busy" >"$sb/loadavg-busy"
beat_run "${deck_env[@]}" "RESEARCH_LOADAVG_FILE=$sb/loadavg-busy"
ck "busy+deck: deck stub answered" "1" "$(hits stubD)"
ck "busy+deck: unsloth never hit" "0" "$(hits stubU)"
ck "busy+deck: model used = deck" "deck:deck-test" "$(cat "$sb/tmp-modelused.txt")"
grep -q 'research-deck-pin' "$sb/STATE.md" &&
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

# a2: busy + deck unarmed -> defer exactly as before, no stamp
reset_beat 2
printf '%s\n' "$busy" >"$sb/loadavg-busy"
beat_run "RESEARCH_LOADAVG_FILE=$sb/loadavg-busy"
ck "busy+unarmed: unsloth never hit" "0" "$(hits stubU)"
grep -q 'research-deferred' "$sb/STATE.md" &&
 grep -q 'research deferred: load 12.00 >= ceiling' "$sb/STATE.md" &&
 echo "ok: busy+unarmed: deferred breadcrumb" || {
 echo "FAIL: busy+unarmed: no deferred breadcrumb"
 fails=$((fails + 1))
}
[ ! -e "$sb/beat-stamp" ] &&
 echo "ok: busy+unarmed: stamp NOT consumed" || {
 echo "FAIL: busy+unarmed: stamp consumed"
 fails=$((fails + 1))
}

# --- b) overflow beat ---------------------------------------------------
b4stale=$((now - 7200))
# b1: own stamp fresh -> skip
reset_beat 4
printf '%s\n' "$now" >"$sb/of-stamp"
printf '%s\n' "$b4stale" >"$sb/beat-stamp"
overflow_run "${kimi_env[@]}"
ck "overflow fresh: kimi never hit" "0" "$(hits stubK)"
ck "overflow fresh: unsloth never hit" "0" "$(hits stubU)"
ck "overflow fresh: own stamp untouched" "$now" "$(cat "$sb/of-stamp")"

# b2: own stamp stale + hour stamp <30min -> silent defer
reset_beat 4
printf '%s\n' "$((now - 7200))" >"$sb/of-stamp"
printf '%s\n' "$((now - 600))" >"$sb/beat-stamp"
overflow_run "${kimi_env[@]}"
ck "overflow 30m-guard: kimi never hit" "0" "$(hits stubK)"
ck "overflow 30m-guard: unsloth never hit" "0" "$(hits stubU)"
ck "overflow 30m-guard: own stamp untouched" "$((now - 7200))" "$(cat "$sb/of-stamp")"
grep -q 'research' "$sb/STATE.md" && {
 echo "FAIL: overflow 30m-guard: not silent (STATE touched)"
 fails=$((fails + 1))
} || echo "ok: overflow 30m-guard: silent defer"

# b3: stale + hour stamp >=30min -> runs pinned kimi (counter 0 -> 1, odd)
reset_beat 4
printf '%s\n' "$((now - 7200))" >"$sb/of-stamp"
printf '%s\n' "$((now - 3600))" >"$sb/beat-stamp"
overflow_run "${kimi_env[@]}"
ck "overflow run1 (odd): kimi pinned" "1" "$(hits stubK)"
ck "overflow run1: unsloth never hit" "0" "$(hits stubU)"
ck "overflow run1: kimi model used" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
grep -q $'line-1\texpanding\t' "$sb/research-lines.tsv" &&
 echo "ok: overflow run1: line-1 advanced" || {
 echo "FAIL: overflow run1: line-1 not advanced"
 fails=$((fails + 1))
}
new_of="$(cat "$sb/of-stamp")"
[ "$new_of" != "$((now - 7200))" ] &&
 echo "ok: overflow run1: own stamp consumed" || {
 echo "FAIL: overflow run1: own stamp not consumed"
 fails=$((fails + 1))
}
ck "overflow run1: hour stamp NOT consumed" "$((now - 3600))" "$(cat "$sb/beat-stamp")"

# b4: next overflow run (counter 1 -> 2, even) pins lobehub; unarmed ->
# falls through to the local chain inside model_call (never blocks)
printf '%s\n' "$((now - 7200))" >"$sb/of-stamp"
printf '%s\n' "$((now - 3600))" >"$sb/beat-stamp"
overflow_run "${kimi_env[@]}"
ck "overflow run2 (even): kimi not re-hit" "1" "$(hits stubK)"
ck "overflow run2: lobehub unarmed -> local answers" "unsloth:stub-model" \
 "$(cat "$sb/tmp-modelused.txt")"
ck "overflow run2: unsloth hit once" "1" "$(hits stubU)"

# --- c) review interleave ------------------------------------------------
# c1: counter 3 -> run 4, 4%4=0, crystallized line present -> REVIEW even
# with planned lines available
reset_beat 8
seed_crystallized line-old
printf '%s\n' 3 >"$sb/beat-count"
beat_run "${kimi_env[@]}"
ck "interleave %4: review pinned kimi" "1" "$(hits stubK)"
ck "interleave %4: unsloth never hit" "0" "$(hits stubU)"
grep -q $'line-old\treviewed\t' "$sb/research-lines.tsv" &&
 echo "ok: interleave %4: oldest crystallized reviewed" || {
 echo "FAIL: interleave %4: line-old not reviewed"
 fails=$((fails + 1))
}
grep -q $'line-1\tplanned\t' "$sb/research-lines.tsv" &&
 echo "ok: interleave %4: planned line NOT advanced" || {
 echo "FAIL: interleave %4: planned line advanced during review"
 fails=$((fails + 1))
}
grep -q $'line-old\tparked\t' "$sb/research-dispositions.tsv" 2>/dev/null &&
 echo "ok: interleave %4: disposition appended" || {
 echo "FAIL: interleave %4: no disposition row"
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

# c3: aligned interleave but counter not at %4 -> normal advance
reset_beat 8
seed_crystallized line-old
printf '%s\n' 0 >"$sb/beat-count"
beat_run "${kimi_env[@]}"
ck "counter 1 (1%4): kimi never hit" "0" "$(hits stubK)"
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
