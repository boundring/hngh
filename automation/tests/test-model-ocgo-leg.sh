#!/usr/bin/env bash
# test-model-ocgo-leg.sh — sandbox proof for the OpenCode Go quota leg in
# lib/model.sh (chat-completions shape, opencode.ai/zen/go/v1; 5h-window
# pacing per R3, docs/research/2026-09-10-passthrough-and-quota-interleaving.md):
# no key/no model row -> skip (archive-only); env key or mode-600 key file
# + model + stub -> answered with MODEL_USED=ocgo:<model> + telemetry row
# (source=ocgo); 5h-window pace-blocked or hard-capped -> breadcrumb +
# next leg answers; dead endpoint -> HTTP 000 breadcrumb + fall-through;
# empty/absent rows = leg skipped; key file 644 refused. Hermetic: no real
# endpoints, no real key, telemetry db is a fixture we seed. The session
# env may carry OPENCODE_API_KEY — call() unsets it.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/dashboard" "$sb/jobs" "$sb/.config/hngh"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
cp "$root/jobs/telemetry.py" "$sb/jobs/"
: >"$sb/cadence-params.tsv" # no ocgo rows unless a case sets one
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
seed_events() { # source n [age_seconds] -> n model/<source> events that old
 python3 - "$@" <<PY
import sqlite3, datetime, sys
db = sqlite3.connect("$sb/dashboard/telemetry.db")
db.execute("CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT, kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
src, n = sys.argv[1], int(sys.argv[2])
age = int(sys.argv[3]) if len(sys.argv) > 3 else 0
ts = (datetime.datetime.now(datetime.timezone.utc) - datetime.timedelta(seconds=age)).strftime("%Y-%m-%dT%H:%M:%SZ")
for _ in range(n):
    db.execute("INSERT INTO events(ts, source, kind) VALUES (?, ?, 'model')", (ts, src))
db.commit()
PY
}

# one model_call in the sandbox; per-case env passed as K=V args.
call() { # prompt [K=V ...] -> stdout
 local k
 (
  export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
  export HOME="$sb" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
  export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
  export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
  export OLLAMA_MODEL=stub-ollama DECK_URL=http://127.0.0.1:1
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export MODEL_MAX_TOKENS=3072
  unset OPENCODE_API_KEY KIMI_AI_KEY KIMI_FOR_CODING_KEY MOONSHOTAI_API_KEY \
   LOBEHUB_KEY OCGO_URL OCGO_MODEL OCGO_CAP_5H_CALLS MODEL_PIN
  local prompt="$1"
  shift
  for k in "$@"; do export "$k"; done
  printf '%s' "$prompt" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
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
pace_seed_count_5h() { # cap -> used count just above the 5h pace line now
 local elapsed=$(($(date -u +%s) % 18000))
 awk -v c="$1" -v e="$elapsed" 'BEGIN{printf "%d", int(c*e/18000) + 2}'
}
set_lobe_rows() { printf 'lobehub-endpoint\t%s\ttest\ttest\nlobehub-agent-id\tagt_test_quota\ttest\ttest\n' "$1" >"$sb/cadence-params.tsv"; }

# --- 1. no key, no model row -> leg invisible, archive-only catches it.
stub_start stubB # not in $( ): the background stub would hold the capture pipe open
stubB_port="$(cat "$stubdir/stubB-port")"
[ -n "$stubB_port" ] || {
 echo "FAIL: stub did not start"
 exit 1
}
out="$(call "hello-1")"
ck "no key, no model: empty stdout" "" "$out"
ck "no key, no model: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# --- 2. env key armed but no opencode-model row -> still fail-closed skip.
out="$(call "hello-2" "OPENCODE_API_KEY=stub-key-never-real")"
ck "env key, no model row: empty stdout" "" "$out"
ck "env key, no model row: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# --- 3. env key + model row + stub -> ocgo leg answers with its model tag
#        and emits exactly one telemetry row (source=ocgo); request is
#        chat-completions shaped (messages present) with Bearer auth.
out="$(call "hello-3" "OPENCODE_API_KEY=stub-key-never-real" \
 "OCGO_MODEL=glm-test-model" "OCGO_URL=http://127.0.0.1:$stubB_port")"
ck "env key+model: stub content" "stub-says-hi" "$out"
ck "env key+model: ocgo used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"
ck "env key+model: telemetry row emitted" "1" \
 "$(sqlite3 "$sb/dashboard/telemetry.db" "select count(*) from events where kind='model' and source='ocgo'")"
grep -q '"messages"' "$stubdir/stubB-bodies" &&
 echo "ok: chat-completions body shape" || {
 echo "FAIL: body not chat-completions"
 fails=$((fails + 1))
}

# --- 4. file-key path: mode 600 key file answers; mode 644 is refused.
rm -f "$sb/dashboard/telemetry.db"
printf 'stub-key-never-real' >"$sb/.config/hngh/opencode-key"
chmod 600 "$sb/.config/hngh/opencode-key"
out="$(call "hello-4a" "OCGO_MODEL=glm-test-model" "OCGO_URL=http://127.0.0.1:$stubB_port")"
ck "file key 600: stub content" "stub-says-hi" "$out"
ck "file key 600: ocgo used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"
chmod 644 "$sb/.config/hngh/opencode-key"
out="$(call "hello-4b" "OCGO_MODEL=glm-test-model" "OCGO_URL=http://127.0.0.1:$stubB_port")"
ck "file key 644: empty stdout" "" "$out"
ck "file key 644: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
grep -q "key file too open" "$sb/STATE.md" &&
 echo "ok: file key 644: breadcrumb written" || {
 echo "FAIL: no 644 breadcrumb"
 fails=$((fails + 1))
}
chmod 600 "$sb/.config/hngh/opencode-key"

# --- 5. 5h-window pace-blocked (above the pace line, below the cap) ->
#        breadcrumb, next quota leg (kimi stub) answers.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
seed_events ocgo "$(pace_seed_count_5h 100)" 60 # just above the pace line
set_lobe_rows "http://127.0.0.1:$stubB_port"
out="$(call "hello-5" "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model" \
 "OCGO_URL=http://127.0.0.1:$stubB_port" "OCGO_CAP_5H_CALLS=100" \
 "LOBEHUB_KEY=stub-lobe-key")"
ck "5h pace-blocked: ocgo skipped, lobehub answers" "stub-says-hi" "$out"
ck "5h pace-blocked: lobehub used" "lobehub:agt_test_quota" "$(cat "$sb/tmp-modelused.txt")"
grep -q "quota pace 5h: ocgo used " "$sb/STATE.md" &&
 echo "ok: 5h pace-blocked: breadcrumb written" || {
 echo "FAIL: no pace breadcrumb"
 fails=$((fails + 1))
}

# --- 6. events aged OUT of the 5h window (6h old) do NOT count -> leg goes.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
seed_events ocgo 95 21600 # 6h old: outside the tightest window
out="$(call "hello-6" "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model" \
 "OCGO_URL=http://127.0.0.1:$stubB_port" "OCGO_CAP_5H_CALLS=100" \
 "LOBEHUB_KEY=stub-lobe-key")"
ck "outside-window events ignored: ocgo answers" "stub-says-hi" "$out"
ck "outside-window events ignored: ocgo used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"

# --- 7. hard cap reached inside the window -> skipped the same way.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
seed_events ocgo 3 60
out="$(call "hello-7" "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model" \
 "OCGO_URL=http://127.0.0.1:$stubB_port" "OCGO_CAP_5H_CALLS=3" \
 "LOBEHUB_KEY=stub-lobe-key")"
ck "hard cap: ocgo skipped, lobehub answers" "stub-says-hi" "$out"
grep -q "quota pace 5h: ocgo used 3/cap 3" "$sb/STATE.md" &&
 echo "ok: hard cap: breadcrumb written" || {
 echo "FAIL: no cap breadcrumb"
 fails=$((fails + 1))
}

# --- 8. helper boundaries: used==cap blocks; fresh window goes.
rm -f "$sb/dashboard/telemetry.db"
seed_events ocgo 3 60
got="$(AUTOMATION_ROOT="$sb" bash -c '. "'"$root"'/lib/model.sh"; quota_pace_blocked_5h ocgo 3')"
ck "helper: used==cap blocks (3 3)" "3 3" "$got"
got="$(
 AUTOMATION_ROOT="$sb" bash -c '. "'"$root"'/lib/model.sh"; quota_pace_blocked_5h ocgo 100000'
 echo "rc=$?"
)"
ck "helper: fresh window goes" "rc=1" "$got"

# --- 9. dead ocgo endpoint -> HTTP 000 breadcrumb + fall-through.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
out="$(call "hello-9" "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model" \
 "OCGO_URL=http://127.0.0.1:1" "LOBEHUB_KEY=stub-lobe-key")"
ck "dead ocgo endpoint: fall-through to lobehub" "stub-says-hi" "$out"
ck "dead ocgo endpoint: lobehub used" "lobehub:agt_test_quota" \
 "$(cat "$sb/tmp-modelused.txt")"
grep -q "| model | ocgo | HTTP 000 -> next backend" "$sb/STATE.md" &&
 echo "ok: dead ocgo endpoint: breadcrumb written" || {
 echo "FAIL: no 000 breadcrumb"
 fails=$((fails + 1))
}

# --- 10. MODEL_PIN=ocgo routes there first; miss falls through to local.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
out="$(call "hello-10" "MODEL_PIN=ocgo" "OCGO_URL=http://127.0.0.1:1" \
 "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model")"
ck "pin=ocgo, dead leg: falls through to archive" "none:archive-only" \
 "$(cat "$sb/tmp-modelused.txt")"

# --- 11. MODEL_PIN=ocgo + live leg: ocgo answers, remote/kimi skipped.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
out="$(call "hello-11" "MODEL_PIN=ocgo" "OCGO_URL=http://127.0.0.1:$stubB_port" \
 "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model" \
 "KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" \
 "KIMI_URL=http://127.0.0.1:$stubB_port")"
ck "pin=ocgo, live leg: stub content" "stub-says-hi" "$out"
ck "pin=ocgo, live leg: ocgo used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"

[ "$fails" = 0 ] && echo "test-model-ocgo-leg: all pass" || {
 echo "test-model-ocgo-leg: $fails failure(s)"
 exit 1
}
