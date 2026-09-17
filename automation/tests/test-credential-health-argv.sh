#!/usr/bin/env bash
# test-credential-health-argv.sh — the three bearer probes in
# jobs/credential-health.sh (unsloth session, kimi, ocgo) must carry the
# secret in the stdin curl config (`curl -K -`, `header = "..."` line),
# never on the curl argv (/proc/<pid>/cmdline exposure for the call
# duration — same class as the notify-seam argv fix,
# docs/records/2026-09-16-notify-token-argv-exposure.md). Hermetic: stub
# curl records ARGV:/STDIN: lines (test-notify-seam.sh pattern); a
# loopback real-curl check proves -K - header + argv URL + -o/-w
# ordering. Asserted values are stub-only; nothing real is read or sent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { [ -n "${SRVPID:-}" ] && kill "$SRVPID" 2>/dev/null; rm -rf "$sb"; }
trap cleanup EXIT
mkdir -p "$sb/bin" "$sb/state" "$sb/.config/hngh"
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

# run credential-health.sh hermetically; args = extra K=V env assignments.
call() {
  local kv
  (
    export HOME="$sb" AUTOMATION_ROOT="$root" PATH="$sb/bin:$PATH"
    export JOB_NAME=test-credhealth HNGH_HOME="$root/.."
    export HNGH_REPORT_ROOT="$sb" HNGH_HOME_DIR="$sb/.hngh"
    export CREDENTIAL_FRESHNESS_LEDGER="$sb/fresh.tsv"
    export CREDENTIAL_FRESHNESS_OLA=604800
    export CURL_LOG="$sb/curl.log" STATE_FILE="$sb/state/STATE.md"
    export UNSLOTH_URL="$sb/no-such-endpoint" TOKEN_FILE="$sb/tok"
    : >"$sb/curl.log"; : >"$sb/state/STATE.md"; rm -f "$sb/fresh.tsv"
    # the operator's session may arm real channels — hermetic runs start bare
    unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID HNGH_WEBHOOK_URL HNGH_NOTIFY_EMAIL_CONF
    unset MOONSHOTAI_API_KEY KIMI_AI_KEY KIMI_FOR_CODING_KEY KIMI_KEY_FILE KIMI_URL
    unset OPENCODE_API_KEY OPENCODE_KEY_FILE OCGO_URL
    for kv in "$@"; do export "$kv"; done
    printf 'stub-token-value-123\n' >"$sb/tok"
    chmod 600 "$sb/tok"
    timeout 30 bash "$root/jobs/credential-health.sh" >/dev/null 2>&1
    echo "rc=$?"
  )
}
no_argv_secret() { # desc value — value must not appear outside STDIN lines
  if grep -v '^STDIN:' "$sb/curl.log" 2>/dev/null | grep -qF "$2"; then
    echo "FAIL: $1: secret on curl argv"; fails=$((fails + 1))
  else
    echo "ok: $1: value absent from curl argv"
  fi
}
in_stdin() { # desc value — value must appear on a STDIN line
  if grep '^STDIN:' "$sb/curl.log" 2>/dev/null | grep -qF "$2"; then
    echo "ok: $1: value carried in stdin curl config"
  else
    echo "FAIL: $1: stdin curl config missing value"; fails=$((fails + 1))
  fi
}
crumb() { # state-pattern -> count in the sandbox STATE.md
  grep -c "$2" "$sb/state/STATE.md" 2>/dev/null || true
}

# --- 1. unsloth session probe (token file armed) ---
out="$(call)"
ck "unsloth: exit 0" "rc=0" "$out"
no_argv_secret "unsloth" "stub-token-value-123"
in_stdin "unsloth" 'header = "Authorization: Bearer stub-token-value-123"'
ck "unsloth: crumb http=200" "1" "$(crumb unsloth 'http=200')"

# --- 2. kimi probe (env-armed key) ---
out="$(call MOONSHOTAI_API_KEY=stub-kimi-key-456 \
  KIMI_URL=http://127.0.0.1:1/v1/chat/completions)"
ck "kimi: exit 0" "rc=0" "$out"
no_argv_secret "kimi" "stub-kimi-key-456"
in_stdin "kimi" 'header = "Authorization: Bearer stub-kimi-key-456"'
ck "kimi: crumb names env source" "1" \
  "$(crumb kimi 'kimi (env MOONSHOTAI_API_KEY)')"

# --- 3. kimi probe (mode-600 key file armed) — the file-arming path must
# ride the same stdin-config shape.
printf 'stub-kimi-key-789\n' >"$sb/.config/hngh/kimi-key"
chmod 600 "$sb/.config/hngh/kimi-key"
out="$(call KIMI_URL=http://127.0.0.1:1/v1/chat/completions)"
ck "kimi file: exit 0" "rc=0" "$out"
no_argv_secret "kimi file" "stub-kimi-key-789"
in_stdin "kimi file" 'header = "Authorization: Bearer stub-kimi-key-789"'
rm -f "$sb/.config/hngh/kimi-key"

# --- 4. ocgo probe (env-armed key) ---
out="$(call OPENCODE_API_KEY=stub-ocgo-key-abc \
  OCGO_URL=http://127.0.0.1:1/v1/chat/completions)"
ck "ocgo: exit 0" "rc=0" "$out"
no_argv_secret "ocgo" "stub-ocgo-key-abc"
in_stdin "ocgo" 'header = "Authorization: Bearer stub-ocgo-key-abc"'
ck "ocgo: crumb names env source" "1" \
  "$(crumb ocgo 'ocgo (env OPENCODE_API_KEY)')"

# --- 6. zero-length-ledger edge (2026-09-17 fix) — truncation must not
# self-heal: no re-seed into an existing-but-empty ledger, a REFUSED
# breadcrumb instead, and check() files the ledger-empty alert. Uses
# call_keep (preserves CREDENTIAL_FRESHNESS_LEDGER across runs).
call_keep() { # like call(), but keeps the freshness ledger between runs
  local kv
  (
    export HOME="$sb" AUTOMATION_ROOT="$root" PATH="$sb/bin:$PATH"
    export JOB_NAME=test-credhealth HNGH_HOME="$root/.."
    export HNGH_REPORT_ROOT="$sb" HNGH_HOME_DIR="$sb/.hngh"
    export CREDENTIAL_FRESHNESS_LEDGER="$sb/fresh.tsv"
    export CREDENTIAL_FRESHNESS_OLA=604800
    export CURL_LOG="$sb/curl.log" STATE_FILE="$sb/state/STATE.md"
    export UNSLOTH_URL="$sb/no-such-endpoint" TOKEN_FILE="$sb/tok"
    : >"$sb/curl.log"; : >"$sb/state/STATE.md"
    # the operator's session may arm real channels — hermetic runs start bare
    unset TELEGRAM_BOT_TOKEN TELEGRAM_CHAT_ID HNGH_WEBHOOK_URL HNGH_NOTIFY_EMAIL_CONF
    unset MOONSHOTAI_API_KEY KIMI_AI_KEY KIMI_FOR_CODING_KEY KIMI_KEY_FILE KIMI_URL
    unset OPENCODE_API_KEY OPENCODE_KEY_FILE OCGO_URL
    for kv in "$@"; do export "$kv"; done
    printf 'stub-token-value-123\n' >"$sb/tok"
    chmod 600 "$sb/tok"
    timeout 30 bash "$root/jobs/credential-health.sh" >/dev/null 2>&1
    echo "rc=$?"
  )
}

# 6a. truncated-to-zero ledger: re-seed must be refused and breadcrumbd;
# the ledger must still be zero bytes afterwards; job exits 0.
: >"$sb/fresh.tsv"
out="$(call_keep)"
ck "zero-ledger: exit 0" "rc=0" "$out"
ck "zero-ledger: refusal crumb" "1" \
  "$(crumb refusal 're-seed REFUSED')"
ck "zero-ledger: still zero bytes (no launder re-seed)" "0" \
  "$(wc -c <"$sb/fresh.tsv")"

# 6b. blank-lines-only ledger: nonzero size, so [ ! -s ] does not fire and
# no breadcrumb branch runs — check() must file the `ledger-empty` alert.
printf '\n   \n' >"$sb/fresh.tsv"
out="$(call_keep)"
ck "blank-ledger: exit 0" "rc=0" "$out"
if [ "$(grep -c 'ledger-empty' "$sb/docs/project/reports.md" 2>/dev/null || true)" -ge 1 ]; then
  echo "ok: blank-ledger: ledger-empty alert filed"
else
  echo "FAIL: blank-ledger: no ledger-empty alert row"; fails=$((fails + 1))
fi

# 6c. absent ledger: bootstrap seeds and crumbs (the original wiring).
rm -f "$sb/fresh.tsv"
out="$(call_keep)"
ck "absent-ledger: exit 0" "rc=0" "$out"
ck "absent-ledger: bootstrap crumb" "1" \
  "$(crumb bootstrap 'freshness ledger seeded (bootstrap)')"
[ -s "$sb/fresh.tsv" ] && echo "ok: absent-ledger: ledger seeded non-empty" || {
  echo "FAIL: absent-ledger: ledger not seeded"; fails=$((fails + 1))
}

# --- real-curl loopback: -K - header directive + argv URL + -o/-w
# ordering behaves identically (the exact probe shape the job uses).
python3 - "$sb" <<'PY' &
import http.server, sys
sb = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        open(sb + "/auth-header.txt", "w").write(self.headers.get("Authorization") or "")
        self.send_response(200); self.end_headers()
    def log_message(self, *a): pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
open(sb + "/port.txt", "w").write(str(srv.server_port))
srv.serve_forever()
PY
SRVPID=$!
for i in 1 2 3 4 5; do [ -s "$sb/port.txt" ] && break; sleep 0.2; done
port="$(cat "$sb/port.txt")"
code="$(printf 'header = "Authorization: Bearer loopback-key-xyz"\n' |
  curl -s --max-time 5 -K - -o /dev/null -w '%{http_code}' \
  "http://127.0.0.1:$port/v1/models")"
ck "loopback: http 200" "200" "$code"
# the server records the Authorization VALUE (the header line itself is
# "Authorization: Bearer loopback-key-xyz")
ck "loopback: header delivered" "Bearer loopback-key-xyz" \
  "$(cat "$sb/auth-header.txt" 2>/dev/null)"

[ "$fails" -eq 0 ] && echo "test-credential-health-argv: all pass" || {
  echo "test-credential-health-argv: $fails failure(s)"
  exit 1
}
