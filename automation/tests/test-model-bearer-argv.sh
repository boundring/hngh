#!/usr/bin/env bash
# test-model-bearer-argv.sh — the model.sh chat legs must carry the
# credential in the stdin curl config (`curl -K -`,
# `header = "Authorization: Bearer %s"` directive), never on the curl
# argv: a Bearer header on argv sits world-readable in
# /proc/<pid>/cmdline for the whole call (up to MODEL_TIMEOUT). Same
# class already fixed at the notify seam
# (docs/records/2026-09-16-notify-token-argv-exposure.md) and for the
# credential-health probes of the SAME endpoints
# (docs/records/2026-09-16-credential-health-bearer-stdin.md, ccf8d7b5)
# — after which these production legs were the only remaining
# Bearer-on-argv sites in the tree.
#
# Covered seams: _post_chat bearer arg (remote/kimi/ocgo/zai chat legs,
# exercised via remote_chat + ocgo_chat), unsloth_attempt (unsloth chat
# + retry path), _unsloth_ctx_limit (context-window probe), and the
# no-bearer deck leg (must stay free of any Authorization header). The
# request JSON body rides a tmp file (`-d @"$btmp"`), because -K - and
# -d @- cannot share stdin. Hermetic: stub curl records ARGV:/STDIN:
# lines (test-credential-health-argv.sh pattern); asserted values are
# stub-only, nothing real is read or sent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/lib" "$sb/bin" "$sb/state"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" \
  "$root/lib/model.sh" "$sb/lib/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# stub curl: records argv (ARGV:) plus, when -K is present, the stdin
# config (STDIN:) to $CURL_LOG; answers HTTP 200.
cat >"$sb/bin/curl" <<'EOF'
#!/usr/bin/env bash
{
  printf 'ARGV: %s\n' "$*"
  case " $* " in *" -K "*) printf 'STDIN:'; cat; printf '\n';; esac
} >>"$CURL_LOG"
echo "200"
EOF
chmod +x "$sb/bin/curl"

call_model() { # fn [args...] -> stdout of model.sh function $fn
  local fn="$1"
  shift
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    export HOME="$sb" PATH="$sb/bin:$PATH"
    export HNGH_TELEMETRY_DB="$sb/telemetry.db" MODEL_TIMEOUT=5
    export TOKEN_FILE="$sb/unsloth.token" REFRESH_FILE="$sb/unsloth.refresh"
    export WALL_S_FILE="$sb/wall" TOKIN_FILE="$sb/tokin"
    export TOKOUT_FILE="$sb/tokout" POST_CODE_FILE="$sb/postcode"
    export REMOTE_TOKEN_FILE="$sb/remote.key" REMOTE_URL="$sb/no-such-endpoint"
    export REMOTE_MODEL=stub-remote REMOTE_DAILY_CAP_CALLS=200
    export UNSLOTH_URL="$sb/no-such-endpoint" OLLAMA_URL="http://127.0.0.1:1"
    export OLLAMA_MODEL=stub-ollama MODEL=stub-model
    export UNSLOTH_FALLBACK_MODELS="" MODEL_MAX_TOKENS=512
    export HNGH_LOADCTX_PIN=0 # no /load curl: this suite counts exactly one call per leg (2026-09-22 context lane)
    export OPENCODE_API_KEY=stub-ocgo-key-value-3
    export OCGO_URL="$sb/no-such-endpoint" OCGO_MODEL=stub-ocgo
    export DECK_URL="$sb/no-such-endpoint" DECK_MODEL=stub-deck
    export CURL_LOG="$sb/curl.log"
    : >"$sb/curl.log"
    bash -c '. "'"$root"'/lib/model.sh"; '"$fn"' "$@"' _ "$@"
  )
}
no_argv_secret() { # desc value — value must not appear outside STDIN lines
  if grep -v '^STDIN:' "$sb/curl.log" 2>/dev/null | grep -qF "$2"; then
    echo "FAIL: $1: secret on curl argv"
    fails=$((fails + 1))
  else
    echo "ok: $1: value absent from curl argv"
  fi
}
in_stdin() { # desc value — value must appear on a STDIN line
  if grep '^STDIN:' "$sb/curl.log" 2>/dev/null | grep -qF "$2"; then
    echo "ok: $1: value carried in stdin curl config"
  else
    echo "FAIL: $1: stdin curl config missing value"
    fails=$((fails + 1))
  fi
}
uses_kdash() { # desc — the single curl record must use ` -K `
  if grep '^ARGV:' "$sb/curl.log" 2>/dev/null | grep -q ' -K '; then
    echo "ok: $1: curl invoked with the stdin config (-K -)"
  else
    echo "FAIL: $1: curl not using -K -"
    fails=$((fails + 1))
  fi
}
one_call() { # desc — exactly one curl record in the log
  ck "$1" "1" "$(grep -c '^ARGV:' "$sb/curl.log" 2>/dev/null || true)"
}

# --- 1. remote leg (_post_chat bearer seat; key file armed) ---
printf 'remote-key-value-1\n' >"$sb/remote.key"
chmod 600 "$sb/remote.key"
out="$(call_model remote_chat hi 16)"
one_call "remote: exactly one curl call"
uses_kdash "remote"
no_argv_secret "remote" "remote-key-value-1"
in_stdin "remote" "Authorization: Bearer remote-key-value-1"

# --- 2. ocgo leg (_post_chat bearer seat; env key armed) ---
out="$(call_model ocgo_chat hi 16)"
one_call "ocgo: exactly one curl call"
uses_kdash "ocgo"
no_argv_secret "ocgo" "stub-ocgo-key-value-3"
in_stdin "ocgo" "Authorization: Bearer stub-ocgo-key-value-3"

# --- 3. unsloth_attempt (bearer header on the chat/retry path) ---
out="$(call_model unsloth_attempt "$sb/resp" stub-model hi 16 0 unsloth-key-value-2)"
one_call "unsloth_attempt: exactly one curl call"
uses_kdash "unsloth_attempt"
no_argv_secret "unsloth_attempt" "unsloth-key-value-2"
in_stdin "unsloth_attempt" "Authorization: Bearer unsloth-key-value-2"

# --- 4. _unsloth_ctx_limit (GET probe of the inference-status endpoint) ---
out="$(call_model _unsloth_ctx_limit unsloth-key-value-4)"
one_call "ctx-limit: exactly one curl call"
uses_kdash "ctx-limit"
no_argv_secret "ctx-limit" "unsloth-key-value-4"
in_stdin "ctx-limit" "Authorization: Bearer unsloth-key-value-4"

# --- 5. deck leg (no bearer): no Authorization header anywhere, and no
#        phantom empty-bearer header introduced by the config feed ---
out="$(call_model deck_chat hi 16)"
one_call "deck: exactly one curl call"
if grep -q 'Authorization' "$sb/curl.log" 2>/dev/null; then
  echo "FAIL: deck: Authorization appeared without a key"
  fails=$((fails + 1))
else
  echo "ok: deck: no Authorization header on the keyless leg"
fi

if [ "$fails" -gt 0 ]; then
  echo "model-bearer-argv: $fails failure(s)"
  exit 1
fi
echo "model-bearer-argv contract: all cases passed"
