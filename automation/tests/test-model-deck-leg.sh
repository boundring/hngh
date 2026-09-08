#!/usr/bin/env bash
# test-model-deck-leg.sh — sandbox proof for the param-gated deck leg in
# lib/model.sh: unset/empty deck-model-endpoint -> leg invisible (falls
# through to archive-only); set -> POSTs the OpenAI-shaped body to the
# stub endpoint; unreachable/slow -> MODEL_TIMEOUT honored, archive-only
# preserved. Hermetic: no real endpoints, no real repos touched.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/dashboard"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
: >"$sb/cadence-params.tsv" # Inventory: no deck row unless a case sets one
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
STUB_CONTENT=deck-says-hi

# one model_call in the sandbox; every upstream leg dead by construction.
call() { # prompt -> stdout
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT="${MT:-5}"
    export MODEL_MAX_TOKENS="${MT:-3072}"
    printf '%s' "$1" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
  )
}
set_row() { printf 'deck-model-endpoint\t%s\ttest\ttest\n' "$1" >"$sb/cadence-params.tsv"; }
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# 1. unset row -> leg invisible, archive-only catches the prompt.
out="$(call "hello-1")"
ck "unset row: empty stdout" "" "$out"
ck "unset row: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
ls "$sb"/archive/skipped-*.txt >/dev/null 2>&1 && echo "ok: unset row: prompt archived" || {
  echo "FAIL: unset row: prompt not archived"
  fails=$((fails + 1))
}

# 2. row set to the live stub -> deck leg answers.
stub_start deck
port="$(cat "$stubdir/deck-port" 2>/dev/null)"
[ -n "$port" ] || {
  echo "FAIL: stub did not start"
  exit 1
}
set_row "http://127.0.0.1:$port"
out="$(call "hello-2")"
ck "set row: stub content" "deck-says-hi" "$out"
ck "set row: deck used" "deck:deck" "$(cat "$sb/tmp-modelused.txt")"

# 3. row set to a dead URL -> HTTP 000 breadcrumb, archive-only preserved.
set_row "http://127.0.0.1:1"
out="$(call "hello-3")"
ck "dead row: empty stdout" "" "$out"
ck "dead row: archive-only used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
grep -q "| model | deck | HTTP 000 -> next backend" "$sb/STATE.md" &&
  echo "ok: dead row: breadcrumb written" || {
  echo "FAIL: dead row: no breadcrumb"
  fails=$((fails + 1))
}

# 4. MODEL_TIMEOUT honored: stub sleeps 3s, timeout 1s -> leg fails.
stub_start deck 3
port="$(cat "$stubdir/deck-port" 2>/dev/null)"
MT=1 set_row "http://127.0.0.1:$port"
MT=1 out="$(call "hello-4")"
ck "slow stub beyond MODEL_TIMEOUT: empty stdout" "" "$out"
ck "slow stub beyond MODEL_TIMEOUT: archive-only" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"

rm -rf "$sb"
[ "$fails" = 0 ] && echo "test-model-deck-leg: all pass" || {
  echo "test-model-deck-leg: $fails failure(s)"
  exit 1
}
