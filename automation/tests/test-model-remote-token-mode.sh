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
export HNGH_CRUMBS_DB="$sb/crumbs.db"
export CRUMBS_WRITER="$root/lib/crumbs.py"
crumbs() { python3 "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }
crumbs_reset() { rm -f "$HNGH_CRUMBS_DB" "$HNGH_CRUMBS_DB-wal" "$HNGH_CRUMBS_DB-shm"; }

. "$root/tests/stub-lib.sh"

# remote_chat with the key file and endpoint wired by the case.
call() { # keyfile [url] -> stdout
  local url="${2:-http://127.0.0.1:1}"
  (
    export AUTOMATION_ROOT="$sb" JOB_NAME=test
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
crumbs_reset
out="$(call "$tok")"
ck "0644: empty stdout" "" "$out"
ck "0644: too-open breadcrumb" "1" \
  "$(crumbs | grep -c 'key file too open (chmod 600 required) -> next backend')"
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
crumbs_reset
out="$(call "$tok")"
ck "0600 dead URL: empty stdout" "" "$out"
ck "0600 dead URL: got past the gate (HTTP breadcrumb)" "1" \
  "$(crumbs | grep -c '| model | remote | HTTP')"
ck "0600 dead URL: no too-open breadcrumb" "0" \
  "$(crumbs | grep -c 'too open')"
rm -f "$stubdir/remote-hits"
: >"$stubdir/remote-hits"
out="$(call "$tok" "http://127.0.0.1:$port")"
ck "0600 vs live stub: stub answered" "stub-says-hi" "$out"
ck "0600 vs live stub: exactly one POST" "1" \
  "$(wc -l <"$stubdir/remote-hits" | tr -d ' ')"

# 3. absent key file stays the dormant leg (existing contract, pinned
#    so the new gate cannot regress it).
crumbs_reset
out="$(call "$sb/definitely-absent.key")"
ck "absent: empty stdout" "" "$out"
ck "absent: no-key-file breadcrumb" "1" \
  "$(crumbs | grep -c 'no key file -> next backend')"

# 4. unsloth_chat — the FIFTH token-file reader (gap-unsloth-tokenfile-
#    600-gate): TOKEN_FILE needs the identical gate. Exposure: the token
#    file is chmod-600 only after a successful refresh; an
#    operator-created/restored 0644 file was silently read and sent as
#    the bearer header on every chat call. Same refusal byte shape as
#    the kimi/remote legs, above the cat.
ucall() { # tokenfile url -> unsloth_chat stdout
  (
    export AUTOMATION_ROOT="$sb" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$1" REFRESH_FILE="$sb/nope2"
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export UNSLOTH_URL="$2" OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
    export MODEL_MAX_TOKENS=512 REMOTE_MODEL=stub-remote
    export HNGH_LOADCTX_PIN=0 # no /load POST: this suite counts exactly one (2026-09-22 context lane)
    bash -c '. "'"$root"'/lib/model.sh"; unsloth_chat hi 16 stub-model'
  )
}
utok="$sb/unsloth.token"
printf 'unsloth-key-value-1\n' >"$utok"

# 4a. too-open token file (0644): the leg refuses fail-closed BEFORE the
#     value is read or sent; zero POSTs even against the live stub.
chmod 644 "$utok"
crumbs_reset
out="$(ucall "$utok" http://127.0.0.1:1)"
ck "unsloth 0644: empty stdout" "" "$out"
ck "unsloth 0644: too-open breadcrumb" "1" \
  "$(crumbs | grep -c 'key file too open (chmod 600 required) -> next backend')"
stub_start unsloth
uport="$(cat "$stubdir/unsloth-port")"
out="$(ucall "$utok" "http://127.0.0.1:$uport")"
ck "unsloth 0644 vs live stub: empty stdout" "" "$out"
ck "unsloth 0644 vs live stub: zero POSTs (value never sent)" "0" \
  "$(wc -l <"$stubdir/unsloth-hits" | tr -d ' ')"

# 4b. the 0600 control: gate passes, the leg proceeds (dead URL -> the
#     HTTP breadcrumb shape proves the flow got past the gate; the live
#     stub sees the POST and answers).
chmod 600 "$utok"
crumbs_reset
out="$(ucall "$utok" http://127.0.0.1:1)"
ck "unsloth 0600 dead URL: empty stdout" "" "$out"
ck "unsloth 0600 dead URL: got past the gate (HTTP breadcrumb)" "1" \
  "$(crumbs | grep -c '| model | unsloth | HTTP')"
ck "unsloth 0600 dead URL: no too-open breadcrumb" "0" \
  "$(crumbs | grep -c 'too open')"
out="$(ucall "$utok" "http://127.0.0.1:$uport")"
ck "unsloth 0600 vs live stub: stub answered" "stub-says-hi" "$out"
ck "unsloth 0600 vs live stub: exactly one POST" "1" \
  "$(wc -l <"$stubdir/unsloth-hits" | tr -d ' ')"

# 4c. absent token file stays the dormant leg (existing contract).
crumbs_reset
out="$(ucall "$sb/definitely-absent.token" http://127.0.0.1:1)"
ck "unsloth absent: empty stdout" "" "$out"
ck "unsloth absent: no-token-file breadcrumb" "1" \
  "$(crumbs | grep -c 'no token file -> next backend')"

# 5. refresh_unsloth_token — the SIXTH credential-file reader
#    (gap-refresh-argv-body-and-refreshfile-gate): REFRESH_FILE is
#    single-use but credential-bearing (possession mints access
#    tokens), so it gets the identical mode-600 gate above its cat.
#    Exposure: refresh_unsloth_token chmods the pair only AFTER a
#    successful rotation; an operator-created/restored 0644 refresh
#    file was silently read and POSTed as the request body. Same
#    refusal shape as sections 1/4, above the cat (dead URL -> rc 1
#    and the refresh-failure breadcrumb shape prove the flow died at
#    the gate, not at curl).
rcall() { # refreshfile -> refresh_unsloth_token rc
  (
    export AUTOMATION_ROOT="$sb" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$sb/nope4" REFRESH_FILE="$1"
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
    export MODEL_MAX_TOKENS=512 REMOTE_MODEL=stub-remote
    bash -c '. "'"$root"'/lib/model.sh"; refresh_unsloth_token'
  )
}
rtok="$sb/unsloth.refresh"
printf 'refresh-key-value-1\n' >"$rtok"

# 5a. too-open refresh file (0644): the gate refuses fail-closed BEFORE
#     the value is read or sent; no credential POST leaves the box.
chmod 644 "$rtok"
crumbs_reset
rc=0
out="$(rcall "$rtok")" || rc=$?
ck "refresh 0644: refused (rc 1)" "1" "$rc"
ck "refresh 0644: empty stdout" "" "$out"
ck "refresh 0644: too-open breadcrumb" "1" \
  "$(crumbs | grep -c 'refresh key file too open (chmod 600 required)')"

# 5b. the 0600 control: gate passes; the flow proceeds past the gate to
#     the POST (dead URL -> the FAILED token-refresh breadcrumb shape,
#     and NO too-open crumb, prove the gate did not fire).
chmod 600 "$rtok"
crumbs_reset
rc=0
out="$(rcall "$rtok")" || rc=$?
ck "refresh 0600: refused only at HTTP (rc 1)" "1" "$rc"
ck "refresh 0600: got past the gate (FAILED token-refresh breadcrumb)" "1" \
  "$(crumbs | grep -c '| model | token-refresh | FAILED')"
ck "refresh 0600: no too-open breadcrumb" "0" \
  "$(crumbs | grep -c 'too open')"

# 5c. absent refresh file keeps its own dormant breadcrumb (existing
#     contract, pinned so the new gate cannot shadow it).
crumbs_reset
rc=0
out="$(rcall "$sb/definitely-absent.refresh")" || rc=$?
ck "refresh absent: refused (rc 1)" "1" "$rc"
ck "refresh absent: no-refresh-token-file breadcrumb" "1" \
  "$(crumbs | grep -c 'no refresh token file')"
ck "refresh absent: no too-open breadcrumb" "0" \
  "$(crumbs | grep -c 'too open')"

[ "$fails" = 0 ] && echo "test-model-remote-token-mode: all pass" || {
  echo "test-model-remote-token-mode: $fails failure(s)"
  exit 1
}
