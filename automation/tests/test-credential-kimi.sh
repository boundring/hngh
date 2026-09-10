#!/usr/bin/env bash
# test-credential-kimi.sh - the kimi credential-health probe must send the
# resolved key as Authorization to the leg's own endpoint (the 2026-09-10
# lesson: an unauthenticated GET on the models path read 401 for five days
# while real kimi_chat calls succeeded - the probe measured its own
# missing header, not the credential).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { [ -n "${SRVPID:-}" ] && kill "$SRVPID" 2>/dev/null; rm -rf "$sb"; }
trap cleanup EXIT
mkdir -p "$sb"
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}
# stub endpoint: 200 with any Authorization header, 401 without; records it
python3 - "$sb" <<'PY' &
import http.server, sys
sb = sys.argv[1]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        open(sb + "/auth-header.txt", "w").write(repr(self.headers.get("Authorization")))
        self.send_response(200 if self.headers.get("Authorization") else 401)
        self.end_headers()
    def log_message(self, *a): pass
srv = http.server.HTTPServer(("127.0.0.1", 0), H)
open(sb + "/port.txt", "w").write(str(srv.server_port))
srv.serve_forever()
PY
SRVPID=$!
for i in 1 2 3 4 5; do [ -s "$sb/port.txt" ] && break; sleep 0.2; done
port="$(cat "$sb/port.txt")"
STATE="$sb/STATE.md"; : >"$STATE"
: >"$sb/cadence-params.tsv"
HNGH_HOME="$root/.." AUTOMATION_ROOT="$root" STATE_FILE="$STATE" \
  KIMI_URL="http://127.0.0.1:$port/v1/chat/completions" \
  MOONSHOTAI_API_KEY="test.key.123" \
  timeout 30 bash "$root/jobs/credential-health.sh" >/dev/null 2>&1
rc=$?
ck "credential-health exits 0" "0" "$rc"
# the stub saw the resolved key as the Authorization header
ck "probe sent Authorization header" "1" \
  "$(grep -c "test.key.123" "$sb/auth-header.txt" 2>/dev/null || true)"
ck "crumb says http=200" "1" "$(grep -c "models endpoint http=200" "$STATE")"
echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || { echo "$fails FAILED"; exit 1; }
