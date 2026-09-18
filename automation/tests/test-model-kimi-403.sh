#!/usr/bin/env bash
# test-model-kimi-403.sh — session-layer proof that a live-but-forbidden
# kimi endpoint (HTTP 403, the revoked-key shape seen 264x in STATE.md:
# `| model | kimi | HTTP 403 -> next backend`) fails over instead of
# answering: kimi leg returns 1, MODEL_USED is NOT kimi, no kimi telemetry
# row is emitted, the 403 breadcrumb names the code, and the next quota leg
# (ocgo) answers. Hermetic: stub endpoints only, fixture keys, fixture db.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/home/db" "$sb/lib" "$sb/archive" "$sb/dashboard" "$sb/db" "$sb/jobs" "$sb/.config/hngh"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$root/lib/scrub.sh" "$root/lib/scrub.py" "$sb/lib/"
ln -s "$root/jobs/telemetry.py" "$sb/jobs/telemetry.py"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

. "$root/tests/stub-lib.sh"

# 403 stub: always answers HTTP 403 Forbidden (revoked-key shape).
stub_403() { # name
 local name="$1"
 rm -f "$stubdir/$name-port"
 python3 - "$stubdir" "$name" <<'PY' &
import http.server, socketserver, sys, os
d, name = sys.argv[1], sys.argv[2]
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); self.rfile.read(n)
        body = b'{"error": {"message": "forbidden", "type": "forbidden"}}'
        self.send_response(403); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body))); self.end_headers()
        self.wfile.write(body)
socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(("127.0.0.1", 0), H)
with open(os.path.join(d, name + "-port"), "w") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
PY
 stub_pids="$stub_pids $!"
 local i=0
 while [ ! -s "$stubdir/$name-port" ] && [ $i -lt 50 ]; do
  sleep 0.1
  i=$((i + 1))
 done
 :
}

call() { # prompt [K=V ...] -> stdout
 local prompt="$1"
 shift
 local kv
 (
  export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
  export HOME="$sb" HNGH_HOME_DIR="$sb/home" TOKEN_FILE="$sb/nope" REFRESH_FILE="$sb/nope2"
  export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
  export UNSLOTH_URL=http://127.0.0.1:1 OLLAMA_URL=http://127.0.0.1:1
  export OLLAMA_MODEL=stub-ollama
  export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
  export MODEL_MAX_TOKENS=3072
  export KIMI_KEY_FILE="$sb/.config/hngh/kimi-key"
  unset KIMI_AI_KEY KIMI_FOR_CODING_KEY MOONSHOTAI_API_KEY KIMI_MODEL KIMI_URL
  unset KIMI_DAILY_CAP_CALLS MODEL_PIN
  for kv in "$@"; do export "$kv"; done
  printf '%s' "$prompt" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
 )
}
fails=0
ck() { # desc expected actual
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

stub_403 stub403
port403="$(cat "$stubdir/stub403-port")"
[ -n "$port403" ] || { echo "FAIL: 403 stub did not start"; exit 1; }
stub_start stubB
portB="$(cat "$stubdir/stubB-port")"
[ -n "$portB" ] || { echo "FAIL: stubB did not start"; exit 1; }

# kimi 403s, ocgo answers: failover, not success.
printf 'opencode-url\thttp://127.0.0.1:%s\ttest\ttest\nopencode-model\tglm-test-model\ttest\ttest\n' "$portB" >"$sb/cadence-params.tsv"
out="$(call "hello-403" "KIMI_AI_KEY=stub-key-never-real" "KIMI_MODEL=kimi-test-model" \
 "KIMI_URL=http://127.0.0.1:$port403" "OPENCODE_API_KEY=stub-key-never-real" \
 "OCGO_CAP_5H_CALLS=100000")"
ck "403: fall-through answers" "stub-says-hi" "$out"
ck "403: kimi NOT used" "ocgo:glm-test-model" "$(cat "$sb/tmp-modelused.txt")"
grep -q "| model | kimi | HTTP 403 -> next backend" "$sb/STATE.md" &&
 echo "ok: 403: breadcrumb names the code" || {
 echo "FAIL: 403: no 403 breadcrumb"
 fails=$((fails + 1))
}
ck "403: no kimi telemetry row" "0" \
 "$(sqlite3 "$sb/home/db/telemetry.db" "select count(*) from events where kind='model' and source='kimi'" 2>/dev/null || echo DB-MISSING)"

[ "$fails" = 0 ] && echo "test-model-kimi-403: all pass" || {
 echo "test-model-kimi-403: $fails failure(s)"
 exit 1
}
