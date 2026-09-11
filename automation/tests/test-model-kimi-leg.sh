#!/usr/bin/env bash
# test-model-kimi-leg.sh — sandbox proof for the kimi quota leg, quota-window
# pacing, and MODEL_PIN in lib/model.sh: no key/no model -> skip (archive-
# only); env key or mode-600 key file + model + stub -> answered with
# MODEL_USED=kimi:<model> + telemetry row; pace-blocked (above the pace
# line, below cap) or hard-capped -> breadcrumb + next leg answers; dead
# endpoint -> HTTP 000 breadcrumb + fall-through; MODEL_PIN=local -> quota
# stubs (deck/kimi/ocgo) never hit, unsloth answers. Hermetic: no real
# endpoints, no real key, telemetry db is a fixture we seed. The operator's
# session env may carry KIMI_* keys — call() unsets them.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/dashboard" "$sb/jobs" "$sb/.config/hngh"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
ln -s "$root/jobs/telemetry.py" "$sb/jobs/telemetry.py"
: >"$sb/cadence-params.tsv" # Inventory: no kimi/ocgo rows unless a case sets one
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
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
set_ocgo_rows() { printf 'opencode-url\t%s\ttest\ttest\nopencode-model\tglm-test-model\ttest\ttest\n' "$1" >"$sb/cadence-params.tsv"; }

# one model_call in the sandbox; per-case env passed as K=V args.
call() { # prompt [K=V ...] -> stdout
 local prompt="$1"
 shift
 local kv
 (
  export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
  export HOME="$sb" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
  export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
  export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
  export OLLAMA_MODEL=stub-ollama
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export MODEL_MAX_TOKENS=3072
  export KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
  # the operator's session may arm real keys/models — hermetic tests start bare
  unset KIMI_AI_KEY KIMI_FOR_CODING_KEY MOONSHOTAI_API_KEY KIMI_MODEL KIMI_URL
  unset KIMI_DAILY_CAP_CALLS MODEL_PIN
  for kv in "$@"; do export "$kv"; done
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

# --- 1. no key, no model row -> leg invisible, archive-only catches it.
out="$(call "hello-1")"
ck "no key, no model: empty stdout" "" "$out"
ck "no key, no model: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# --- 2. env key armed but no kimi-model row -> still fail-closed skip.
out="$(call "hello-2" "KIMI_AI_KEY=stub-key-never-real")"
ck "env key, no model row: empty stdout" "" "$out"
ck "env key, no model row: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# --- 3. env key + model + live stub -> kimi leg answers with its model tag
#        and emits exactly one telemetry row (source=kimi).
stub_start stubB # not in $( ): the background stub would hold the capture pipe open
stubB_port="$(cat "$stubdir/stubB-port")"
[ -n "$stubB_port" ] || {
 echo "FAIL: stubB did not start"
 exit 1
}
out="$(call "hello-3" "KIMI_AI_KEY=stub-key-never-real" \
 "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubB_port")"
ck "env key+model: stub content" "stub-says-hi" "$out"
ck "env key+model: kimi used" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
ck "env key+model: telemetry row emitted" "1" \
 "$(sqlite3 "$sb/dashboard/telemetry.db" "select count(*) from events where kind='model' and source='kimi'")"

# --- 4. file-key path: mode 600 key file answers; mode 644 is refused.
rm -f "$sb/dashboard/telemetry.db"
printf 'stub-key-never-real' >"$sb/.config/hngh/kimi-key"
chmod 600 "$sb/.config/hngh/kimi-key"
out="$(call "hello-4a" "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubB_port")"
ck "file key 600: stub content" "stub-says-hi" "$out"
ck "file key 600: kimi used" "kimi:kimi-test-model" "$(cat "$sb/tmp-modelused.txt")"
chmod 644 "$sb/.config/hngh/kimi-key"
out="$(call "hello-4b" "KIMI_MODEL=kimi-test-model" "KIMI_URL=http://127.0.0.1:$stubB_port")"
ck "file key 644: empty stdout" "" "$out"
ck "file key 644: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
grep -q "key file too open" "$sb/STATE.md" &&
 echo "ok: file key 644: breadcrumb written" || {
 echo "FAIL: file key 644: no breadcrumb"
 fails=$((fails + 1))
}
chmod 600 "$sb/.config/hngh/kimi-key"

# --- 5. pace-blocked (above the pace line, below the cap) -> breadcrumb,
#        next quota leg (ocgo) answers.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
set_ocgo_rows "http://127.0.0.1:$stubB_port"
seed_events kimi "$(pace_seed_count 100)"
out="$(call "hello-5" "KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" \
 "KIMI_URL=http://127.0.0.1:$stubB_port" "KIMI_DAILY_CAP_CALLS=100" \
 "OCGO_URL=http://127.0.0.1:$stubB_port" "OPENCODE_API_KEY=stub-key-never-real" \
 "OCGO_MODEL=glm-test-model" "OCGO_CAP_5H_CALLS=100000")"
ck "pace-blocked: kimi skipped, ocgo answers" "stub-says-hi" "$out"
ck "pace-blocked: ocgo used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"
grep -q "quota pace: kimi used " "$sb/STATE.md" &&
 echo "ok: pace-blocked: breadcrumb written" || {
 echo "FAIL: pace-blocked: no breadcrumb"
 fails=$((fails + 1))
}

# --- 6. hard cap reached -> skipped the same way.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
seed_events kimi 2
out="$(call "hello-6" "KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" \
 "KIMI_URL=http://127.0.0.1:$stubB_port" "KIMI_DAILY_CAP_CALLS=2" \
 "OCGO_URL=http://127.0.0.1:$stubB_port" "OPENCODE_API_KEY=stub-key-never-real" \
 "OCGO_MODEL=glm-test-model" "OCGO_CAP_5H_CALLS=100000")"
ck "hard cap: kimi skipped, ocgo answers" "stub-says-hi" "$out"
grep -q "quota pace: kimi used 2/cap 2" "$sb/STATE.md" &&
 echo "ok: hard cap: breadcrumb written" || {
 echo "FAIL: hard cap: no breadcrumb"
 fails=$((fails + 1))
}

# --- 7. helper boundaries: used == cap blocks; used == 1 with a huge cap goes.
rm -f "$sb/dashboard/telemetry.db"
seed_events kimi 3
got="$(AUTOMATION_ROOT="$sb" bash -c '. "'"$root"'/lib/model.sh"; quota_pace_blocked kimi 3')"
ck "helper: used==cap blocks (3 3)" "3 3" "$got"
got="$(
 AUTOMATION_ROOT="$sb" bash -c '. "'"$root"'/lib/model.sh"; quota_pace_blocked kimi 100000'
 echo "rc=$?"
)"
ck "helper: used=1, huge cap goes" "rc=1" "$got"

# --- 8. MODEL_PIN=local -> quota stubs (deck/kimi/ocgo) NEVER hit;
#        unsloth stub answers.
stub_start stubA
stubA_port="$(cat "$stubdir/stubA-port")"
[ -n "$stubA_port" ] || {
 echo "FAIL: stubA did not start"
 exit 1
}
printf 'stub-token-never-real' >"$sb/unsloth-token"
rm -f "$sb/dashboard/telemetry.db"
: >"$stubdir/stubB-hits" # earlier cases legitimately hit stubB; this one must not
out="$(call "hello-8" "MODEL_PIN=local" \
 "TOKEN_FILE=$sb/unsloth-token" "UNSLOTH_URL=http://127.0.0.1:$stubA_port" \
 "DECK_URL=http://127.0.0.1:$stubB_port" \
 "KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" \
 "KIMI_URL=http://127.0.0.1:$stubB_port" "OCGO_URL=http://127.0.0.1:1")"
ck "MODEL_PIN=local: local stub content" "stub-says-hi" "$out"
ck "MODEL_PIN=local: unsloth used" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
ck "MODEL_PIN=local: kimi/ocgo/deck stub never hit" "0" "$(hits stubB)"
ck "MODEL_PIN=local: unsloth stub hit" "1" "$(hits stubA)"

# --- 9. dead kimi endpoint -> HTTP 000 breadcrumb + fall-through.
rm -f "$sb/dashboard/telemetry.db"
: >"$sb/STATE.md"
out="$(call "hello-9" "KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" \
 "KIMI_URL=http://127.0.0.1:1" "OCGO_URL=http://127.0.0.1:$stubB_port" \
 "OPENCODE_API_KEY=stub-key-never-real" "OCGO_MODEL=glm-test-model" \
 "OCGO_CAP_5H_CALLS=100000")"
ck "dead kimi endpoint: fall-through to ocgo" "stub-says-hi" "$out"
ck "dead kimi endpoint: ocgo used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"
grep -q "| model | kimi | HTTP 000 -> next backend" "$sb/STATE.md" &&
 echo "ok: dead kimi endpoint: breadcrumb written" || {
 echo "FAIL: dead kimi endpoint: no breadcrumb"
 fails=$((fails + 1))
}

[ "$fails" = 0 ] && echo "test-model-kimi-leg: all pass" || {
 echo "test-model-kimi-leg: $fails failure(s)"
 exit 1
}
