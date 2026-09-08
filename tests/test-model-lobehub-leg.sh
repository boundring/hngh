#!/usr/bin/env bash
# test-model-lobehub-leg.sh — sandbox proof for the key+agent-gated lobehub
# leg in lib/model.sh (docs/LOBEHUB.md), OpenAI Responses shape (verified
# live 2026-09-07): no key file -> leg invisible; key + no agent id ->
# skipped fail-closed; key + agent id + stub endpoint -> answered with
# MODEL_USED=lobehub:<agent-id> and a Responses-shaped request (input +
# max_output_tokens present, messages absent); output_text parse; dead
# endpoint -> fallback; daily cap exhausted -> next leg; pin=lobehub routes
# there first. Hermetic: no real endpoints, no real key, telemetry db is a
# fixture we seed.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/dashboard" "$sb/.config/hngh"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
mkdir -p "$sb/jobs"
cp "$root/jobs/telemetry.py" "$sb/jobs/"
: >"$sb/cadence-params.tsv" # Inventory: no lobehub rows unless a case sets one
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
STUB_CONTENT=lobehub-says-hi
seed_events() { # n -> n telemetry model/lobehub events stamped today
 python3 - "$1" <<PY
import sqlite3, datetime, sys
db = sqlite3.connect("$sb/dashboard/telemetry.db")
db.execute("CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT, kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
for _ in range(int(sys.argv[1])):
    db.execute("INSERT INTO events(ts, source, kind) VALUES (?, 'lobehub', 'model')", (today + "T00:00:00Z",))
db.commit()
PY
}

# one model_call in the sandbox; every upstream leg dead by construction.
call() { # prompt [pin] -> stdout
 (
  export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
  export HOME="$sb" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
  export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
  export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
  export OLLAMA_MODEL=stub-ollama
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export MODEL_MAX_TOKENS=3072 LOBEHUB_KEY_FILE="$sb/.config/hngh/lobehub-key"
  [ -n "${2:-}" ] && export MODEL_PIN="$2" || unset MODEL_PIN
  printf '%s' "$1" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
 )
}
set_rows() { printf 'lobehub-endpoint\t%s\ttest\ttest\nlobehub-agent-id\tagt_test_agent\ttest\ttest\n' "$1" >"$sb/cadence-params.tsv"; }
set_agent_rows() { printf 'lobehub-endpoint\t%s\ttest\ttest\n' "$1" >"$sb/cadence-params.tsv"; }
rm_key() { rm -f "$sb/.config/hngh/lobehub-key"; }
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

# 1. no key file, no agent row -> leg invisible, archive-only catches it.
out="$(call "hello-1")"
ck "no key, no agent: empty stdout" "" "$out"
ck "no key, no agent: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# 2. key + live stub, no agent id anywhere -> gate skips fail-closed.
stub_start lobehub
port="$(cat "$stubdir/lobehub-port" 2>/dev/null)"
[ -n "$port" ] || {
 echo "FAIL: stub did not start"
 exit 1
}
printf 'lobehub-test-key-never-real' >"$sb/.config/hngh/lobehub-key"
chmod 600 "$sb/.config/hngh/lobehub-key"
set_agent_rows "http://127.0.0.1:$port"
out="$(call "hello-2")"
ck "key but no agent id: empty stdout" "" "$out"
ck "key but no agent id: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# 3. key + agent id + live stub -> Responses-shape request, output_text parse.
set_rows "http://127.0.0.1:$port"
out="$(call "hello-3")"
ck "key+agent: stub content (output_text parse)" "lobehub-says-hi" "$out"
ck "key+agent: lobehub used with agent tag" "lobehub:agt_test_agent" "$(cat "$sb/tmp-modelused.txt")"
python3 - "$stubdir/lobehub-bodies" <<'PY'
import json, sys
d = json.loads(open(sys.argv[1]).read().strip().splitlines()[-1])
ok = d.get("model") == "agt_test_agent" and d.get("input") == "hello-3" \
     and d.get("max_output_tokens") == 3072 and "messages" not in d \
     and "temperature" not in d
print("ok: request is Responses shape (model=agent, input, max_output_tokens, no messages/temperature)" if ok else "FAIL: bad request shape: %r" % d)
sys.exit(0 if ok else 1)
PY
[ $? = 0 ] || fails=$((fails + 1))
ck "key+agent: telemetry row emitted" "1" \
 "$(sqlite3 "$sb/dashboard/telemetry.db" "select count(*) from events where kind='model' and source='lobehub'")"

# 4. key + agent, dead endpoint -> HTTP 000 breadcrumb, archive-only kept.
set_rows "http://127.0.0.1:1"
out="$(call "hello-4")"
ck "dead endpoint: empty stdout" "" "$out"
ck "dead endpoint: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
grep -q "| model | lobehub | HTTP 000 -> next backend" "$sb/STATE.md" &&
 echo "ok: dead endpoint: breadcrumb written" || {
 echo "FAIL: dead endpoint: no breadcrumb"
 fails=$((fails + 1))
}

# 5. daily cap exhausted -> skip without a call (cap row set to 2, 2 events).
rm -f "$sb/dashboard/telemetry.db"
seed_events 2
set_rows "http://127.0.0.1:$port"
printf 'lobehub-daily-cap\t2\ttest\ttest\n' >>"$sb/cadence-params.tsv"
out="$(call "hello-5")"
ck "cap exhausted: empty stdout" "" "$out"
ck "cap exhausted: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

# 6. pin=lobehub -> lobehub first; answered leg tags the agent id.
rm -f "$sb/dashboard/telemetry.db"
set_rows "http://127.0.0.1:$port"
out="$(call "hello-6" lobehub)"
ck "pin=lobehub: stub content" "lobehub-says-hi" "$out"
ck "pin=lobehub: lobehub used with agent tag" "lobehub:agt_test_agent" "$(cat "$sb/tmp-modelused.txt")"

[ "$fails" = 0 ] && echo "test-model-lobehub-leg: all pass" || {
 echo "test-model-lobehub-leg: $fails failure(s)"
 exit 1
}
