#!/usr/bin/env bash
# test-model-pin-routing.sh — sandbox proofs for MODEL_PIN routing (operator
# quota directive, 2026-09-07) and the research-beat kimi rotation:
#   pin=kimi  -> kimi stub answers; unsloth/deck/ocgo stubs provably
#                never hit; kimi request body keeps the max_tokens
#                passthrough and stays lean (no temperature).
#   pin=kimi + kimi pace-block -> local (unsloth) answers; local never
#                blocked by kimi state.
#   pin=deck  -> deck stub answers first; unsloth/kimi never hit.
#   pin=bogus -> ignored: full chain, unsloth answers.
#   33-research-beat rotation: runs 1,2 local / runs 3,6 kimi (share=3);
#   share=0 never pins; REVIEW transition always pins kimi.
# Hermetic: no real endpoints, no real keys, sandbox repo copy so the beat
# never touches the live telemetry/research state.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/jobs" "$sb/cadence" "$sb/archive" "$sb/dashboard" \
 "$sb/digest" "$sb/kernel/docs/research" "$sb/.config/hngh"
cp -r "$root/lib/." "$sb/lib/"
cp -r "$root/jobs/telemetry.py" "$sb/jobs/"
cp -r "$root/cadence/." "$sb/cadence/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
stub_start stubU # unsloth
stub_start stubK # kimi
stub_start stubD # deck
stubU_port="$(cat "$stubdir/stubU-port")"
stubK_port="$(cat "$stubdir/stubK-port")"
stubD_port="$(cat "$stubdir/stubD-port")"
printf 'stub-token-never-real' >"$sb/unsloth-token"
seed_events() { # source n -> n telemetry model/<source> events stamped today
 python3 - "$1" "$2" <<PY
import sqlite3, datetime, sys
db = sqlite3.connect("$sb/dashboard/telemetry.db")
db.execute("CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT, kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
for _ in range(int(sys.argv[2])):
    db.execute("INSERT INTO events(ts, source, kind) VALUES (?, ?, 'model')", (today + "T00:00:00Z", sys.argv[1]))
db.commit()
PY
}
pace_seed_count() { # cap -> used count just above the pace line for right now
 local elapsed=$((10#$(date -u +%H) * 3600 + 10#$(date -u +%M) * 60 + 10#$(date -u +%S)))
 awk -v c="$1" -v e="$elapsed" 'BEGIN{printf "%d", int(c*e/86400) + 2}'
}

# one model_call in the sandbox; per-case env passed as K=V args.
call() { # prompt [K=V ...] -> stdout
 local prompt="$1"
 shift
 local kv
 (
  export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
  export HOME="$sb" TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope"
  export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
  export UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1
  export OLLAMA_MODEL=stub-ollama
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export MODEL_MAX_TOKENS=3072
  export KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
  # hermetic: start bare of the operator's session env
  unset KIMI_AI_KEY KIMI_FOR_CODING_KEY MOONSHOTAI_API_KEY KIMI_MODEL KIMI_URL
  unset KIMI_DAILY_CAP_CALLS
  unset DECK_URL DECK_MODEL MODEL_PIN
  for kv in "$@"; do export "$kv"; done
  printf '%s' "$prompt" | bash -c '. "'"$sb"'/lib/model.sh"; model_call'
 )
}
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}
hits() { wc -l <"$stubdir/$1-hits" | tr -d ' '; }
reset_hits() {
 : >"$stubdir/stubU-hits"
 : >"$stubdir/stubK-hits"
 : >"$stubdir/stubD-hits"
}
kimi_env=("KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubK_port")
deck_env=("DECK_URL=http://127.0.0.1:$stubD_port" "DECK_MODEL=deck-test")
ocgo_env=("OCGO_URL=http://127.0.0.1:1" "OCGO_MODEL=glm-test-model" "OPENCODE_API_KEY=stub-key-never-real")

# --- 1. MODEL_PIN=kimi -> kimi answers; unsloth/deck/ocgo never hit;
#        the kimi body keeps the max_tokens passthrough and stays lean.
rm -f "$sb/dashboard/telemetry.db"
reset_hits
out="$(call "hello-1" "MODEL_PIN=kimi" "${kimi_env[@]}" "${deck_env[@]}" "${ocgo_env[@]}")"
ck "pin=kimi: kimi stub content" "stub-says-hi" "$out"
ck "pin=kimi: kimi used" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
ck "pin=kimi: kimi stub hit" "1" "$(hits stubK)"
ck "pin=kimi: unsloth stub never hit" "0" "$(hits stubU)"
ck "pin=kimi: deck stub never hit" "0" "$(hits stubD)"
ck "pin=kimi: telemetry row emitted" "1" \
 "$(sqlite3 "$sb/dashboard/telemetry.db" "select count(*) from events where kind='model' and source='kimi'")"
last_body="$(tail -n 1 "$stubdir/stubK-bodies")"
ck "pin=kimi: max_tokens passthrough (3072)" "3072" \
 "$(printf '%s' "$last_body" | jq -r '.max_tokens')"
ck "pin=kimi: no temperature field (gateway 400s on it)" "false" \
 "$(printf '%s' "$last_body" | jq 'has("temperature")')"

# --- 2. pin=kimi + kimi pace-blocked -> local (unsloth) answers.
rm -f "$sb/dashboard/telemetry.db"
reset_hits
seed_events kimi "$(pace_seed_count 100)"
out="$(call "hello-2" "MODEL_PIN=kimi" "${kimi_env[@]}" "${deck_env[@]}" \
 "KIMI_DAILY_CAP_CALLS=100")"
ck "pin=kimi pace-block: local answers" "stub-says-hi" "$out"
ck "pin=kimi pace-block: unsloth used" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
ck "pin=kimi pace-block: kimi stub never hit" "0" "$(hits stubK)"
ck "pin=kimi pace-block: unsloth stub hit" "1" "$(hits stubU)"

# --- 3. pin=deck -> deck answers first; unsloth/kimi never hit.
rm -f "$sb/dashboard/telemetry.db"
reset_hits
out="$(call "hello-3" "MODEL_PIN=deck" "${deck_env[@]}" "${kimi_env[@]}")"
ck "pin=deck: deck stub content" "stub-says-hi" "$out"
ck "pin=deck: deck used" "deck:deck-test" "$(cat "$sb/tmp-modelused.txt")"
ck "pin=deck: deck stub hit" "1" "$(hits stubD)"
ck "pin=deck: unsloth stub never hit" "0" "$(hits stubU)"
ck "pin=deck: kimi stub never hit" "0" "$(hits stubK)"

# --- 4. unknown pin value -> ignored, full chain (unsloth first).
rm -f "$sb/dashboard/telemetry.db"
reset_hits
out="$(call "hello-4" "MODEL_PIN=bogus" "${kimi_env[@]}" "${deck_env[@]}")"
ck "pin=bogus: full chain, unsloth answers" "stub-says-hi" "$out"
ck "pin=bogus: unsloth used" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
ck "pin=bogus: kimi stub never hit" "0" "$(hits stubK)"

# --- 5. pin=kimi + dead kimi endpoint -> falls through to local unsloth.
reset_hits
out="$(call "hello-5" "MODEL_PIN=kimi" "KIMI_AI_KEY=stub-key-never-real" \
 "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:1")"
ck "pin=kimi dead endpoint: unsloth answers" "stub-says-hi" "$out"
ck "pin=kimi dead endpoint: unsloth used" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"

# --- 6. research-beat rotation: runs 1,2 local; run 3 kimi; wraps at 6.
#        Sandbox repo copy (cp -r above) so the beat touches only $sb.
beat_run() { # [K=V ...] -> runs one full beat against the sandbox
 (
  cd "$sb"
  rm -f "$sb/beat-stamp" # each invocation is a fresh gate pass
  env -i PATH="$PATH" HOME="$sb" \
   AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=33-research-beat.sh \
   HNGH_HOME="$sb/kernel" HNGH_REPORT_ROOT="$sb/report-root" \
   RESEARCH_STAMP_FILE="$sb/beat-stamp" RESEARCH_BEAT_COUNT_FILE="$sb/beat-count" \
   RESEARCH_LOADAVG_FILE="$sb/loadavg" RESEARCH_BEAT_HOURS=1 \
   TOKEN_FILE="$sb/unsloth-token" REFRESH_FILE="$sb/nope" \
   REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1 \
   UNSLOTH_URL=http://127.0.0.1:$stubU_port OLLAMA_URL=http://127.0.0.1:1 \
   OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" \
   MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=4096 KIMI_KEY_FILE="$sb/.config/hngh/kimi-key" \
   "$@" \
   bash "$sb/cadence/hour/33-research-beat.sh" >/dev/null 2>&1
 )
}
reset_beat() { # n-lines seeded planned
 rm -f "$sb/beat-stamp" "$sb/beat-count" "$sb/tmp-modelused.txt"
 : >"$sb/STATE.md"
 rm -f "$sb/dashboard/telemetry.db"
 : >"$stubdir/stubK-bodies"
 local i
 {
  for i in $(seq 1 "$1"); do
   printf 'line-%s\tplanned\t%s\tdesc-%s\n' "$i" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$i"
  done
 } >"$sb/research-lines.tsv"
 # subjects re-seed planned lines via ensure_lines: empty for the REVIEW
 # case (0 lines) so pick_line can reach the crystallized line.
 if [ "$1" -gt 0 ]; then
  printf 'line-1\nline-2\nline-3\nline-4\nline-5\nline-6\nline-7\nline-8\n' >"$sb/research-subjects.txt"
 else
  : >"$sb/research-subjects.txt"
 fi
 printf '0.10 0.20 0.10 1/900 1234' >"$sb/loadavg"
}
kimi_rows() {
 sqlite3 "$sb/dashboard/telemetry.db" \
  "select count(*) from events where kind='model' and source='kimi'" 2>/dev/null
}

reset_beat 8
# interleave off: this section isolates the QUOTA rotation; the shared
# counter would otherwise review the crystallized line-1 on run 4
# (4%research-review-interleave) and pin kimi there instead.
ROTA=("RESEARCH_REVIEW_INTERLEAVE=0")
beat_run "${kimi_env[@]}" "${ROTA[@]}"
ck "rotation run1 (1%%3): local answers" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
ck "rotation run1: kimi stub never hit" "0" "$(hits stubK)"
beat_run "${kimi_env[@]}" "${ROTA[@]}"
ck "rotation run2 (2%%3): local answers" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
beat_run "${kimi_env[@]}" "${ROTA[@]}"
ck "rotation run3 (3%%3): kimi answers" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
ck "rotation run3: kimi stub hit once" "1" "$(hits stubK)"
beat_run "${kimi_env[@]}" "${ROTA[@]}"
ck "rotation run4 (4%%3): local answers" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
beat_run "${kimi_env[@]}" "${ROTA[@]}"
ck "rotation run5 (5%%3): local answers" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
beat_run "${kimi_env[@]}" "${ROTA[@]}"
ck "rotation run6 (6%%3): kimi answers again" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
ck "rotation: kimi telemetry rows" "2" "$(kimi_rows)"
# the kimi request from the beat kept the beat's 4096 budget passthrough
ck "rotation: beat kimi body max_tokens=4096" "4096" \
 "$(tail -n 1 "$stubdir/stubK-bodies" | jq -r '.max_tokens')"
# line transitioned normally through the pinned run
grep -q $'line-1\tcrystallized\t' "$sb/research-lines.tsv" &&
 echo "ok: rotation: line-1 reached crystallized" || {
 echo "FAIL: rotation: line-1 not crystallized"
 fails=$((fails + 1))
}

# --- 7. share=0 (env KIMI_RESEARCH_SHARE) -> never pin.
reset_beat 8
reset_hits
beat_run "${kimi_env[@]}" KIMI_RESEARCH_SHARE=0
beat_run "${kimi_env[@]}" KIMI_RESEARCH_SHARE=0
beat_run "${kimi_env[@]}" KIMI_RESEARCH_SHARE=0
ck "share=0: kimi stub never hit in 3 runs" "0" "$(hits stubK)"
ck "share=0: telemetry has no kimi rows" "0" "$(kimi_rows)"

# --- 8. REVIEW transition: always pins kimi (counter at 1, share would
#        not fire; the crystallized line has a doc so REVIEW=1).
reset_beat 0
reset_hits
printf 'line-old\tcrystallized\t2026-09-06T00:00:00Z\tdesc-old\n' >"$sb/research-lines.tsv"
printf 'doc-old\n' >"$sb/kernel/docs/research/2026-09-06-line-old.md"
beat_run "${kimi_env[@]}"
ck "review transition: kimi pinned despite counter=1" "2" "$(hits stubK)"
ck "review transition: kimi used" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
grep -q $'line-old\treviewed\t' "$sb/research-lines.tsv" &&
 echo "ok: review transition: line-old reviewed" || {
 echo "FAIL: review transition: line-old not reviewed"
 fails=$((fails + 1))
}
grep -q $'line-old\tparked\t' "$sb/research-dispositions.tsv" 2>/dev/null &&
 echo "ok: review transition: disposition row appended" || {
 echo "FAIL: review transition: no disposition row"
 fails=$((fails + 1))
}

# --- 9. review-prep pins kimi + chain-accurate alert text (static asserts).
grep -q 'MODEL_PIN="${MODEL_PIN:-kimi}"' "$root/cadence/day/04-review-prep.sh" &&
 echo "ok: review-prep: kimi pin present" || {
 echo "FAIL: review-prep: kimi pin missing"
 fails=$((fails + 1))
}
grep -q 'model chain down (pin=kimi exhausted through local)' \
 "$root/cadence/day/04-review-prep.sh" &&
 echo "ok: review-prep: chain-accurate alert text" || {
 echo "FAIL: review-prep: alert text not chain-accurate"
 fails=$((fails + 1))
}

[ "$fails" = 0 ] && echo "test-model-pin-routing: all pass" || {
 echo "test-model-pin-routing: $fails failure(s)"
 exit 1
}
