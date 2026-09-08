#!/usr/bin/env bash
# smoke-test — end-to-end proof of the harness.
#   1. jobs/ping-hourly.sh  (real terminalfeed fetch + real model completion)
#   2. jobs/morning-digest.sh
#   3. verify dashboard/data.json + digest files exist, hngh runs recorded,
#      index.html renders (python3 http.server on a random port, curl, kill)
# Fails hard on any real bug; passes only with real artifacts.
set -u
cd "$(dirname "$0")/.." || exit 1
. ./lib/common.sh
. ./lib/breadcrumbs.sh

FAIL=0
ok()   { echo "SMOKE OK:  $*"; }
bad()  { echo "SMOKE FAIL: $*"; FAIL=1; }

# Deterministic smoke: start from a clean day. Snapshots are gitignored raw
# captures (regenerable), so resetting the current day makes the fetch see
# every source as "new" and guarantees a real model summary is produced.
TODAY="$(date +%F)"
rm -rf "$AUTOMATION_ROOT/snapshots/$TODAY" 2>/dev/null
rm -f "$AUTOMATION_ROOT/digest/$TODAY.md" "$AUTOMATION_ROOT/digest/MORNING-$TODAY.md"

# --- 1. hourly ping (real fetch + real model) ---
breadcrumb "smoke" "start" "make smoke: ping-hourly run starting"
./jobs/ping-hourly.sh; rc=$?
[ "$rc" = "0" ] && ok "ping-hourly.sh exit 0" || bad "ping-hourly.sh exit $rc"

# --- 2. morning digest ---
./jobs/morning-digest.sh; rc=$?
[ "$rc" = "0" ] && ok "morning-digest.sh exit 0" || bad "morning-digest.sh exit $rc"

# --- 3. artifacts ---
[ -s "dashboard/data.json" ] && jq -e . "dashboard/data.json" >/dev/null 2>&1 \
    && ok "dashboard/data.json exists + valid JSON" \
    || bad "dashboard/data.json missing/invalid"
[ -f "digest/$TODAY.md" ] && [ -s "digest/$TODAY.md" ] \
    && ok "digest/$TODAY.md exists (non-empty)" \
    || bad "digest/$TODAY.md missing/empty"
grep -q "CRITICAL\|NOTABLE\|CONTEXT" "digest/$TODAY.md" 2>/dev/null \
    && ok "digest has tiered summary" \
    || bad "digest has no tiered summary (model may have produced nothing)"
RUNS="$(jq -r '.hngh_runs // 0' dashboard/data.json 2>/dev/null)"
[ "${RUNS:-0}" -ge 1 ] 2>/dev/null && ok "hngh runs recorded ($RUNS)" \
    || bad "no hngh runs recorded in data.json"
[ -s "STATE.md" ] && ok "STATE.md has breadcrumbs" || bad "STATE.md empty"

# --- 4. dashboard renders over HTTP ---
PORT=$(( 20000 + RANDOM % 20000 ))
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory dashboard >/dev/null 2>&1 &
SRV=$!
sleep 1
CODE="$(curl -s -o /tmp/smoke-index.html -w '%{http_code}' --max-time 10 "http://127.0.0.1:$PORT/index.html")"
CODE2="$(curl -s -o /tmp/smoke-data.json -w '%{http_code}' --max-time 10 "http://127.0.0.1:$PORT/data.json")"
kill "$SRV" 2>/dev/null
wait "$SRV" 2>/dev/null
[ "$CODE" = "200" ] && grep -qi "hngh-automation" /tmp/smoke-index.html \
    && ok "index.html renders (HTTP $CODE)" || bad "index.html HTTP $CODE"
[ "$CODE2" = "200" ] && jq -e . /tmp/smoke-data.json >/dev/null 2>&1 \
    && ok "data.json served (HTTP 200, valid JSON)" || bad "data.json HTTP $CODE2"
rm -f /tmp/smoke-index.html /tmp/smoke-data.json

breadcrumb "smoke" "end" "smoke run finished (fail=$FAIL)"
echo
if [ "$FAIL" = "0" ]; then
  echo "SMOKE: ALL CHECKS PASSED"
  echo "--- digest/$TODAY.md (first 30 lines) ---"
  head -n 30 "digest/$TODAY.md"
  echo
  echo "--- STATE.md tail ---"
  tail -n 8 STATE.md
else
  echo "SMOKE: FAILURES — inspect above"; exit 1
fi