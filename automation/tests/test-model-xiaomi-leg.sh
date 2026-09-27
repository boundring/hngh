#!/usr/bin/env bash
# test-model-xiaomi-leg.sh — sandbox proof for the Xiaomi quota leg in
# lib/model.sh (course-correction slice 5): no key/no model -> skip
# (archive-only); env key + model + stub -> answered with
# MODEL_USED=xiaomi:<model>; xiaomi_chat ITSELF emits exactly one
# telemetry row (direct callers — ghost counsel bridge — are visible to
# the pacer); hard cap via xiaomi-cap-day / XIAOMI_DAILY_CAP_CALLS ->
# breadcrumb + next leg answers; helper boundary checks. Hermetic: no
# real endpoints, no real key, telemetry db is a seeded fixture.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/home/db" "$sb/lib" "$sb/archive" "$sb/dashboard" "$sb/db" "$sb/jobs" "$sb/.config/hngh"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$root/lib/scrub.sh" "$root/lib/scrub.py" "$sb/lib/"
ln -s "$root/jobs/telemetry.py" "$sb/jobs/telemetry.py"
: >"$sb/cadence-params.tsv" # Inventory: no xiaomi rows unless a case sets one
export HNGH_CRUMBS_DB="$sb/crumbs.db"
export CRUMBS_WRITER="$root/lib/crumbs.py"
crumbs() { python3 "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }
crumbs_reset() { rm -f "$HNGH_CRUMBS_DB" "$HNGH_CRUMBS_DB-wal" "$HNGH_CRUMBS_DB-shm"; }

. "$root/tests/stub-lib.sh"
seed_events() { # source n -> n telemetry model/<source> events stamped today
 python3 - "$1" "$2" <<PY
import sqlite3, datetime, sys
db = sqlite3.connect("$sb/home/db/telemetry.db")
db.execute("CREATE TABLE IF NOT EXISTS events(ts TEXT, source TEXT, kind TEXT, identity TEXT, lane TEXT, unit TEXT, model TEXT, tokens_in INTEGER, tokens_out INTEGER, cost_usd REAL, wall_s REAL, subject TEXT, refs TEXT, body TEXT)")
today = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
for _ in range(int(sys.argv[2])):
    db.execute("INSERT INTO events(ts, source, kind) VALUES (?, ?, 'model')", (today + "T00:00:00Z", sys.argv[1]))
db.commit()
PY
}
rows() { sqlite3 "$sb/home/db/telemetry.db" \
 "select count(*) from events where kind='model' and source='xiaomi'" 2>/dev/null; }

# direct xiaomi_chat call (the ghost-counsel bridge path, not model_call)
xchat() { # prompt [K=V ...] -> stdout
 local prompt="$1"
 shift
 local kv
 (
  export AUTOMATION_ROOT="$sb" JOB_NAME=test
  export HOME="$sb" HNGH_HOME_DIR="$sb/home"
  export HNGH_TELEMETRY_DB="$sb/home/db/telemetry.db"
  export MODEL_TIMEOUT=5
  export XIAOMI_KEY_FILE="$sb/.config/hngh/xiaomi-key"
  unset XIAOMI_AI_API_KEY XIAOMI_MODEL XIAOMI_URL XIAOMI_DAILY_CAP_CALLS
  unset MODEL_PIN
  for kv in "$@"; do export "$kv"; done
  printf '%s' "$prompt" | bash -c '. "'"$root"'/lib/model.sh"; xiaomi_chat "$(cat)" 30'
 )
}
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

# --- 1. no key, no url/model -> fail-closed skip, empty stdout.
out="$(xchat "hello-1")"
ck "no key, no endpoint: empty stdout" "" "$out"

# --- 2. env key + model + stub -> answered; xiaomi_chat emits its own
#        telemetry row (source=xiaomi), so direct callers are paced.
stub_start stubB # not in $( ): the background stub would hold the capture pipe open
stubB_port="$(cat "$stubdir/stubB-port")"
[ -n "$stubB_port" ] || {
 echo "FAIL: stubB did not start"
 exit 1
}
out="$(xchat "hello-2" "XIAOMI_AI_API_KEY=stub-key-never-real" \
 "XIAOMI_MODEL=mimo-test-model" "XIAOMI_URL=http://127.0.0.1:$stubB_port")"
ck "env key+model: stub content" "stub-says-hi" "$out"
ck "env key+model: chat emitted one row" "1" "$(rows)"

# --- 3. hard cap reached -> refused before the HTTP call, crumb written.
rm -f "$sb/home/db/telemetry.db"
crumbs_reset
seed_events xiaomi 2
: >"$stubdir/stubB-hits"
out="$(xchat "hello-3" "XIAOMI_AI_API_KEY=stub-key-never-real" \
 "XIAOMI_MODEL=mimo-test-model" "XIAOMI_URL=http://127.0.0.1:$stubB_port" \
 "XIAOMI_DAILY_CAP_CALLS=2")"
ck "hard cap: empty stdout" "" "$out"
ck "hard cap: stub never hit" "0" "$(wc -l <"$stubdir/stubB-hits" | tr -d ' ')"
crumbs | grep -q "quota pace: xiaomi used 2/cap 2" &&
 echo "ok: hard cap: breadcrumb written" || {
 echo "FAIL: hard cap: no breadcrumb"
 fails=$((fails + 1))
}

# --- 4. cadence-params row arms the cap too (env override wins shape).
rm -f "$sb/home/db/telemetry.db"
crumbs_reset
printf 'xiaomi-cap-day\t5\ttest\ttest\n' >>"$sb/cadence-params.tsv"
seed_events xiaomi 5
out="$(xchat "hello-4" "XIAOMI_AI_API_KEY=stub-key-never-real" \
 "XIAOMI_MODEL=mimo-test-model" "XIAOMI_URL=http://127.0.0.1:$stubB_port")"
ck "row cap: blocked at 5" "" "$out"
crumbs | grep -q "quota pace: xiaomi used 5/cap 5" &&
 echo "ok: row cap: breadcrumb written" || {
 echo "FAIL: row cap: no breadcrumb"
 fails=$((fails + 1))
}

# --- 5. helper boundary: used == cap blocks; below the pace line goes.
rm -f "$sb/home/db/telemetry.db"
seed_events xiaomi 3
got="$(AUTOMATION_ROOT="$sb" HNGH_HOME_DIR="$sb/home" bash -c '. "'"$root"'/lib/model.sh"; quota_pace_blocked xiaomi 3')"
ck "helper: used==cap blocks (3 3)" "3 3" "$got"
rm -f "$sb/home/db/telemetry.db"
seed_events xiaomi 1
got="$(
 AUTOMATION_ROOT="$sb" HNGH_HOME_DIR="$sb/home" bash -c '. "'"$root"'/lib/model.sh"; quota_pace_blocked xiaomi 100000'
 echo "rc=$?"
)"
ck "helper: used=1, huge cap goes" "rc=1" "$got"

# --- 6. model_call ladder: capped xiaomi skips, deck (later leg) answers;
#        exactly one xiaomi leg-emit (no double count).
rm -f "$sb/home/db/telemetry.db"
crumbs_reset
printf 'xiaomi-cap-day\t2\ttest\ttest\n' >"$sb/cadence-params.tsv" # seam: case 4's cap-5 row would leak
seed_events xiaomi 2
out="$(
 export AUTOMATION_ROOT="$sb" JOB_NAME=test
 export HOME="$sb" HNGH_HOME_DIR="$sb/home" HNGH_TELEMETRY_DB="$sb/home/db/telemetry.db"
 export XIAOMI_KEY_FILE="$sb/.config/hngh/xiaomi-key" TOKEN_FILE="$sb/nope"
 export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
 export OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 export REMOTE_URL=http://127.0.0.1:1 REMOTE_TOKEN_FILE="$sb/nope2"
 export MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=3072 HNGH_LOADCTX_PIN=0
 unset XIAOMI_DAILY_CAP_CALLS MODEL_PIN
 export XIAOMI_AI_API_KEY=stub-key-never-real XIAOMI_MODEL=mimo-test-model
 export XIAOMI_URL=http://127.0.0.1:$stubB_port
 export DECK_URL=http://127.0.0.1:$stubB_port DECK_MODEL=deck-test
 printf '%s' "hello-6" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
)"
ck "ladder: capped xiaomi skipped, deck answers" "stub-says-hi" "$out"
ck "ladder: capped xiaomi emits nothing (seeded 2 only)" "2" "$(rows)"

# --- 7. uncapped ladder run: xiaomi answers, and the leg + chat emit
#        EXACTLY one row (no double count).
rm -f "$sb/home/db/telemetry.db"
crumbs_reset
out="$(
 export AUTOMATION_ROOT="$sb" JOB_NAME=test
 export HOME="$sb" HNGH_HOME_DIR="$sb/home" HNGH_TELEMETRY_DB="$sb/home/db/telemetry.db"
 export XIAOMI_KEY_FILE="$sb/.config/hngh/xiaomi-key" TOKEN_FILE="$sb/nope"
 export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
 export OLLAMA_MODEL=stub-ollama MODEL=stub-model UNSLOTH_FALLBACK_MODELS=""
 export REMOTE_URL=http://127.0.0.1:1 REMOTE_TOKEN_FILE="$sb/nope2"
 export MODEL_TIMEOUT=5 MODEL_MAX_TOKENS=3072 HNGH_LOADCTX_PIN=0
 unset XIAOMI_DAILY_CAP_CALLS MODEL_PIN
 export XIAOMI_AI_API_KEY=stub-key-never-real XIAOMI_MODEL=mimo-test-model
 export XIAOMI_URL=http://127.0.0.1:$stubB_port
 printf '%s' "hello-7" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
)"
ck "ladder: xiaomi answers" "stub-says-hi" "$out"
ck "ladder: exactly one xiaomi row (no double emit)" "1" "$(rows)"

[ "$fails" = 0 ] && echo "test-model-xiaomi-leg: all pass" || {
 echo "test-model-xiaomi-leg: $fails failure(s)"
 exit 1
}
