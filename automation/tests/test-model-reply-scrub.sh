#!/usr/bin/env bash
# test-model-reply-scrub.sh — chain-wide reply-side no-echo scrub in
# lib/model.sh (extension of the news-lane law, llc-model-hygiene-law
# follow-up 2026-09-16): model_call is the ONE consumer entry every leg
# answers through, so a stub leg echoing host path tokens must come back
# from model_call scrubbed (/home, /tmp, ~ redacted to the fixed marker,
# URL-shaped tokens preserved, prose kept) — every consumer lane
# (research beat, reviews, digest, overnight) inherits the law at the
# chokepoint. Also pins: archive-only contract intact (empty stdout,
# raw prompt archived unmutated on the input side), truncation flag
# preserved through the scrub, and a second leg (ollama shape) covered
# by the same seam. Hermetic: no real endpoints, no real repos touched.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/dashboard"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
cp "$root/lib/scrub.sh" "$root/lib/scrub.py" "$sb/lib/" # single-source scrub
: >"$sb/cadence-params.tsv"                             # Inventory: no deck row unless a case sets one
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"
PATHY="Checked $HOME/secret.txt and /tmp/cache then ~/.hngh/db/telemetry.db plus a bare /home and /tmp, a url https://example.com/doc and www.example.com/home/x; kept prose.
second /home line stays prose."
SCRUBBED='Checked [redacted path] and [redacted path] then [redacted path] plus a bare [redacted path] and [redacted path], a url https://example.com/doc and www.example.com/home/x; kept prose.
second [redacted path] line stays prose.'
STUB_CONTENT="$PATHY"

# one model_call in the sandbox; every upstream leg dead by construction.
call() { # prompt [pin] -> stdout
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export OLLAMA_URL="${SANDBOX_OLLAMA_URL:-http://127.0.0.1:1}"
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT="${MT:-5}"
    export HNGH_LOADCTX_PIN=0 # no /load POST: pre-pin contracts only (2026-09-22 context lane)
    export MODEL_MAX_TOKENS="${MT:-3072}"
    export MODEL_PIN="${2:-}"
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

# 1. RED pin: a stub leg (deck) echoing pathy content must come back
# scrubbed from model_call — the single output-side chokepoint.
stub_start deck
port="$(cat "$stubdir/deck-port" 2>/dev/null)"
[ -n "$port" ] || {
  echo "FAIL: stub did not start"
  exit 1
}
set_row "http://127.0.0.1:$port"
out="$(call "echo-test" deck)"
ck "deck leg: pathy reply scrubbed" "$SCRUBBED" "$out"
ck "deck leg: deck used" "deck:deck" "$(cat "$sb/tmp-modelused.txt")"
ck "deck leg: truncation flag preserved (empty)" "" "$(cat "$sb/tmp-modeltrunc.txt" 2>/dev/null)"

# 2. second leg through the same seam: ollama shape (deck row unset ->
# chain falls to ollama -> stub answers the /api/chat shape).
set_row ""
SANDBOX_OLLAMA_URL="http://127.0.0.1:$port"
out="$(call "echo-test-2")"
unset SANDBOX_OLLAMA_URL
ck "ollama leg: pathy reply scrubbed" "$SCRUBBED" "$out"
ck "ollama leg: ollama used" "ollama:stub-ollama" "$(cat "$sb/tmp-modelused.txt")"

# 3. archive-only contract intact: unset row, dead ollama -> empty
# stdout, none:archive-only used, and the ARCHIVED RAW PROMPT is NOT
# mutated by the output-side law (input hygiene stays with the caller).
out="$(call "archive me $HOME/x")"
ck "archive-only: empty stdout" "" "$out"
ck "archive-only: used" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
arch="$(ls "$sb"/archive/skipped-*.txt 2>/dev/null | head -1)"
[ -n "$arch" ] && grep -qF "$HOME/x" "$arch" &&
  echo "ok: archive-only: raw prompt unmutated" || {
  echo "FAIL: archive-only: raw prompt missing/mutated"
  fails=$((fails + 1))
}

# summary
if [ "$fails" -eq 0 ]; then
  echo "ALL PASS"
  exit 0
fi
echo "$fails FAILURE(S)"
exit 1
