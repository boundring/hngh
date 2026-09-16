#!/usr/bin/env bash
# test-model-remote-token-mode.sh — the remote (openrouter) leg must gate
# its key file on mode 600 exactly like the kimi/ocgo/zai legs: a too-open
# REMOTE_TOKEN_FILE is fail-closed skipped (breadcrumb naming the fix,
# "key file too open -> next backend") BEFORE the key is read or sent;
# a 600 file flows on to _post_chat (reaching a dead URL proves the gate
# passed). Mirrors test-probe-model-route.py ProbeTokenMode (f809a05f).
# Hermetic: stub HTTP listener counts hits; no real endpoints.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"

# remote_chat with the key file and endpoint wired by the case.
call() { # keyfile [url] -> stdout
  local url="${2:-http://127.0.0.1:1}"
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
    export REMOTE_TOKEN_FILE="$1" REMOTE_URL="$url"
    export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
    export MODEL_MAX_TOKENS=512 REMOTE_MODEL=stub-remote
    bash -c '. "'"$root"'/lib/model.sh"; remote_chat hi 16'
  )
}
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
tok="$sb/remote.key"
printf 'remote-key-value-1\n' >"$tok"

# 1. too-open key file (0644): leg refuses fail-closed, nothing sent.
chmod 644 "$tok"
: >"$sb/STATE.md"
out="$(call "$tok")"
ck "0644: empty stdout" "" "$out"
ck "0644: too-open breadcrumb" "1" \
  "$(grep -c 'key file too open (chmod 600 required) -> next backend' "$sb/STATE.md")"
stub_start remote
port="$(cat "$stubdir/remote-port")"
out="$(call "$tok" "http://127.0.0.1:$port")"
ck "0644 vs live stub: empty stdout" "" "$out"
ck "0644 vs live stub: zero POSTs (value never sent)" "0" \
  "$(wc -l <"$stubdir/remote-hits" | tr -d ' ')"

# 2. the 0600 control: gate passes, the leg proceeds to _post_chat
#    (dead URL -> the HTTP breadcrumb shape proves the flow got past
#    the gate; a live stub would see exactly one POST).
chmod 600 "$tok"
: >"$sb/STATE.md"
out="$(call "$tok")"
ck "0600 dead URL: empty stdout" "" "$out"
ck "0600 dead URL: got past the gate (HTTP breadcrumb)" "1" \
  "$(grep -c '| model | remote | HTTP' "$sb/STATE.md")"
ck "0600 dead URL: no too-open breadcrumb" "0" \
  "$(grep -c 'too open' "$sb/STATE.md")"
rm -f "$stubdir/remote-hits"; : >"$stubdir/remote-hits"
out="$(call "$tok" "http://127.0.0.1:$port")"
ck "0600 vs live stub: stub answered" "stub-says-hi" "$out"
ck "0600 vs live stub: exactly one POST" "1" \
  "$(wc -l <"$stubdir/remote-hits" | tr -d ' ')"

# 3. absent key file stays the dormant leg (existing contract, pinned
#    so the new gate cannot regress it).
: >"$sb/STATE.md"
out="$(call "$sb/definitely-absent.key")"
ck "absent: empty stdout" "" "$out"
ck "absent: no-key-file breadcrumb" "1" \
  "$(grep -c 'no key file -> next backend' "$sb/STATE.md")"

[ "$fails" = 0 ] && echo "test-model-remote-token-mode: all pass" || {
  echo "test-model-remote-token-mode: $fails failure(s)"
  exit 1
}
