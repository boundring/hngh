#!/usr/bin/env bash
# test-model-refresh-hygiene.sh — the refresh path must obey the
# tree-wide credential-seam contract. The single-use refresh token is
# credential material (possession mints access tokens), so:
#  1. its VALUE never rides curl argv (/proc/<pid>/cmdline exposure —
#     the same class as the 2026-09-16/17 bearer-argv conversions):
#     the JSON body is staged to a mktemp file and sent as -d @"$btmp"
#     (file PATH on argv, value never — the _post_chat/unsloth_attempt
#     pattern),
#  2. REFRESH_FILE is read only through the mode-600 stat gate every
#     other credential-file read has (the sixth reader; the
#     gap-unsloth-tokenfile-600-gate slice closed five TOKEN_FILE/
#     REMOTE_TOKEN_FILE readers and exempted only the post-refresh
#     TOKEN_FILE re-read).
# Red/green method, two mechanisms:
#  - /proc-style argv capture: stub curl on PATH records ARGV: and —
#    emulating the two curl features the refresh path relies on so the
#    success path completes — the staged body (BODY:, read from the
#    -d @file target) and the -o target (filled with the stub answer).
#  - real wire: a local HTTP stub records the arriving POST (path +
#    raw body) and answers a valid rotated pair, proving the wire
#    shape is unchanged (body bytes, %{http_code}/-o semantics) while
#    the value stays off argv.
# Hermetic: localhost stub + sandbox files only; asserted values are
# stub-only, nothing real is read or sent.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/bin"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$sb/lib/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"
. "$root/tests/stub-lib.sh"

VAL="refresh-secret-value-1"
NEW_ACCESS="new-access-value-2"
NEW_REFRESH="new-refresh-value-2"
STUB_O="{\"access_token\":\"stub-access-x\",\"refresh_token\":\"stub-refresh-x\"}"

fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# stub curl: /proc-style argv capture. Emulates the two curl features
# the refresh path relies on so the success path completes: -d @file
# (BODY: is the file content real curl would put on the wire) and
# -o file (the stub answer written to the response tmp). No network.
cat >"$sb/bin/curl" <<'EOF'
#!/usr/bin/env bash
{
  printf 'ARGV: %s\n' "$*"
  prev=""
  for a in "$@"; do
    if [ "$prev" = "-d" ] && [ "${a#@}" != "$a" ]; then
      printf 'BODY:'
      cat "${a#@}"
      printf '\n'
    fi
    if [ "$prev" = "-o" ]; then
      printf '%s' "$STUB_O" >"$a"
    fi
    prev="$a"
  done
} >>"$CURL_LOG"
printf '200'
EOF
chmod +x "$sb/bin/curl"

# real refresh stub: records POST path + raw body, answers a rotated pair.
cat >"$stubdir/refresh-stub.py" <<'PY'
import http.server, socketserver, sys, os, json
d = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n)
        with open(os.path.join(d, "refresh-hits"), "a") as f:
            f.write(self.path + "\n")
        with open(os.path.join(d, "refresh-bodies"), "ab") as f:
            f.write(body + b"\n")
        out = json.dumps({"access_token": os.environ["NEW_ACCESS"],
                          "refresh_token": os.environ["NEW_REFRESH"]}).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out)))
        self.end_headers()
        self.wfile.write(out)
socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(("127.0.0.1", 0), H)
with open(os.path.join(d, "refresh-port"), "w") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
PY

# operator posture: the pair on disk, mode 600.
arm() {
  printf 'access-secret-value-0\n' >"$sb/unsloth.token"
  printf '%s\n' "$VAL" >"$sb/unsloth.refresh"
  chmod 600 "$sb/unsloth.token" "$sb/unsloth.refresh"
}

call_refresh() { # url stubcurl(0|1) -> refresh_unsloth_token rc via $?
  local url="$1" stubcurl="$2"
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$sb/unsloth.token" REFRESH_FILE="$sb/unsloth.refresh"
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export UNSLOTH_URL="$url" OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
    export MODEL_MAX_TOKENS=512 REMOTE_MODEL=stub-remote
    export NEW_ACCESS="$NEW_ACCESS" NEW_REFRESH="$NEW_REFRESH" STUB_O="$STUB_O"
    export CURL_LOG="$sb/curl.log"
    if [ "$stubcurl" = "1" ]; then
      export PATH="$sb/bin:$PATH"
    fi
    : >"$sb/curl.log"
    bash -c '. "'"$root"'/lib/model.sh"; refresh_unsloth_token'
  )
}

# --- 1. argv capture (stub curl): value never on argv; body staged ---
arm
rc=0
out="$(call_refresh "$sb/no-such-endpoint" 1)" || rc=$?
ck "argv: refresh call succeeded via stub answer" "0" "$rc"
ck "argv: exactly one curl call" "1" "$(grep -c '^ARGV:' "$sb/curl.log" 2>/dev/null || true)"
ck "argv: refresh endpoint on argv (URL, not secret)" "1" \
  "$(grep '^ARGV:' "$sb/curl.log" | grep -c '/api/auth/refresh')"
ck "argv: %{http_code} semantics preserved" "1" \
  "$(grep '^ARGV:' "$sb/curl.log" | grep -c '%{http_code}')"
if grep '^ARGV:' "$sb/curl.log" 2>/dev/null | grep -qF "$VAL"; then
  echo "FAIL: argv: refresh token VALUE on curl argv (/proc cmdline exposure)"
  fails=$((fails + 1))
else
  echo "ok: argv: refresh token value absent from curl argv"
fi
ck "argv: body rides the staged -d @file form" "1" \
  "$(grep '^ARGV:' "$sb/curl.log" | grep -c ' -d @')"
ck "argv: staged body content is the refresh-token JSON" \
  "{\"refresh_token\":\"$VAL\"}" \
  "$(grep '^BODY:' "$sb/curl.log" | sed 's/^BODY://' | head -1)"
ck "argv: success breadcrumb" "1" \
  "$(grep -c '| model | token-refresh | ok (new single-use pair written)' "$sb/STATE.md")"
ck "argv: rotated refresh written" "stub-refresh-x" "$(cat "$sb/unsloth.refresh")"
ck "argv: rotated refresh mode 600" "600" "$(stat -c %a "$sb/unsloth.refresh")"
ck "argv: rotated access written" "stub-access-x" "$(cat "$sb/unsloth.token")"
ck "argv: rotated access mode 600" "600" "$(stat -c %a "$sb/unsloth.token")"

# --- 2. real wire: body arrives intact, rotation lands ---
arm
: >"$sb/STATE.md"
rm -f "$stubdir/refresh-hits" "$stubdir/refresh-bodies"
NEW_ACCESS="$NEW_ACCESS" NEW_REFRESH="$NEW_REFRESH" \
  python3 "$stubdir/refresh-stub.py" "$stubdir" &
stub_pids="$stub_pids $!"
i=0
while [ ! -s "$stubdir/refresh-port" ] && [ "$i" -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
rport="$(cat "$stubdir/refresh-port")"
rc=0
out="$(call_refresh "http://127.0.0.1:$rport" 0)" || rc=$?
ck "wire: refresh call succeeded" "0" "$rc"
ck "wire: exactly one POST" "1" "$(wc -l <"$stubdir/refresh-hits" | tr -d ' ')"
ck "wire: POST hit the refresh endpoint" "/api/auth/refresh" "$(head -1 "$stubdir/refresh-hits")"
ck "wire: arriving body is the refresh-token JSON (value rode the wire)" \
  "{\"refresh_token\":\"$VAL\"}" "$(head -1 "$stubdir/refresh-bodies")"
ck "wire: rotated refresh written" "$NEW_REFRESH" "$(cat "$sb/unsloth.refresh")"
ck "wire: rotated refresh mode 600" "600" "$(stat -c %a "$sb/unsloth.refresh")"
ck "wire: rotated access written" "$NEW_ACCESS" "$(cat "$sb/unsloth.token")"
ck "wire: success breadcrumb" "1" \
  "$(grep -c '| model | token-refresh | ok (new single-use pair written)' "$sb/STATE.md")"

# --- 3. REFRESH_FILE mode-600 gate (sixth credential-file reader) ---
arm
chmod 644 "$sb/unsloth.refresh"
rm -f "$stubdir/refresh-hits"
: >"$stubdir/refresh-hits"
: >"$sb/STATE.md"
rc=0
out="$(call_refresh "http://127.0.0.1:$rport" 0)" || rc=$?
ck "gate: 0644 refresh file refused (rc 1)" "1" "$rc"
ck "gate: too-open breadcrumb" "1" \
  "$(grep -c 'refresh key file too open (chmod 600 required)' "$sb/STATE.md")"
ck "gate: zero POSTs (value never sent)" "0" "$(wc -l <"$stubdir/refresh-hits" | tr -d ' ')"

# the 0600 control is sections 1-2 (gate passed); pin the absent-file
# dormant contract so the new gate cannot shadow it.
rm -f "$sb/unsloth.refresh"
: >"$sb/STATE.md"
rc=0
out="$(call_refresh http://127.0.0.1:1 0)" || rc=$?
ck "gate: absent refresh file refused (rc 1)" "1" "$rc"
ck "gate: absent-file breadcrumb" "1" \
  "$(grep -c 'no refresh token file' "$sb/STATE.md")"
ck "gate: no too-open crumb for the absent file" "0" \
  "$(grep -c 'too open' "$sb/STATE.md")"

if [ "$fails" = 0 ]; then
  echo "test-model-refresh-hygiene: all pass"
else
  echo "test-model-refresh-hygiene: $fails failure(s)"
  exit 1
fi
