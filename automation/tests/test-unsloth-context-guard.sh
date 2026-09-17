#!/usr/bin/env bash
# test-unsloth-context-guard.sh — proof for the unsloth_chat context guard
# in lib/model.sh: the server VRAM-shrinks its window, so before sending
# we probe /api/inference/status (cached) and skip the leg when the prompt
# cannot fit (~90% of the ACTIVE context_length). Oversized -> breadcrumb +
# next backend; fitting -> leg used; endpoint down -> leg behaves as before.
# Hermetic: stub HTTP server, no real endpoints.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
stubdir="$(mktemp -d)"
stub_pids=""
trap 'rm -rf "$sb" "$stubdir"; [ -z "$stub_pids" ] || kill $stub_pids 2>/dev/null' EXIT
mkdir -p "$sb/lib" "$sb/archive" "$sb/dashboard"
ln -s "$root/lib/common.sh" "$root/lib/breadcrumbs.sh" "$root/lib/params.sh" "$root/lib/model.sh" "$root/lib/scrub.sh" "$root/lib/scrub.py" "$sb/lib/"
: >"$sb/cadence-params.tsv"
: >"$sb/STATE.md"

# stub: GET /api/inference/status -> CONTEXT_LENGTH env; POST chat -> reply.
# GET hits recorded so tests can prove the probe happened.
python3 - "$stubdir" <<'PY' &
import http.server, socketserver, sys, json, os
d = sys.argv[1]
ctx = os.environ.get("STUB_CONTEXT_LENGTH", "100")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        with open(os.path.join(d, "status-hits"), "a") as f:
            f.write(self.path + "\n")
        out = json.dumps({"context_length": int(ctx),
                          "active_model": "unsloth/stub-model"}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out))); self.end_headers()
        self.wfile.write(out)
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); self.rfile.read(n)
        with open(os.path.join(d, "chat-hits"), "a") as f:
            f.write(self.path + "\n")
        content = "stub-says-hi"
        out = json.dumps({"choices": [{"message": {"content": content}}],
                          "usage": {"prompt_tokens": 11}}).encode()
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out))); self.end_headers()
        self.wfile.write(out)
socketserver.TCPServer.allow_reuse_address = True
srv = socketserver.TCPServer(("127.0.0.1", 0), H)
with open(os.path.join(d, "stub-port"), "w") as f:
    f.write(str(srv.server_address[1]))
srv.serve_forever()
PY
stub_pids="$!"
i=0
while [ ! -s "$stubdir/stub-port" ] && [ $i -lt 50 ]; do
  sleep 0.1
  i=$((i + 1))
done
port="$(cat "$stubdir/stub-port")"

# one model_call in the sandbox; every other leg dead by construction.
call() { # prompt [unsloth_url] -> stdout
  (
    export AUTOMATION_ROOT="$sb" STATE_FILE="$sb/STATE.md" JOB_NAME=test
    export HOME="$sb" TOKEN_FILE="$sb/tok" REFRESH_FILE="$sb/nope2"
    printf 'stub-token' >"$sb/tok"
    chmod 600 "$sb/tok" # unsloth leg mode-gates its token file (gap-unsloth-tokenfile-600-gate)
    export REMOTE_TOKEN_FILE="$sb/nope3" REMOTE_URL=http://127.0.0.1:1
    export UNSLOTH_URL="${2:-http://127.0.0.1:$port}" OLLAMA_URL=http://127.0.0.1:1
    export OLLAMA_MODEL=stub-ollama
    export MODEL=stub-model UNSLOTH_FALLBACK_MODELS="" MODEL_TIMEOUT=5
    export MODEL_MAX_TOKENS=3072
    printf '%s' "$1" | bash -c '. "'"$root"'/lib/model.sh"; model_call'
  )
}
fails=0
ck() { # desc expected actual
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

# 1. fitting prompt (tiny vs 100-token stub window) -> leg used, probe ran.
out="$(call "hello small")"
ck "fitting: leg used" "stub-says-hi" "$out"
ck "fitting: model used" "unsloth:stub-model" "$(cat "$sb/tmp-modelused.txt")"
ck "fitting: status probed" "1" "$(wc -l <"$stubdir/status-hits")"
ck "fitting: chat hit once" "1" "$(wc -l <"$stubdir/chat-hits")"

# 2. oversized prompt -> leg skipped, archived, probe answered from cache.
rm -f "$sb/tmp-unsloth-ctx.txt"
big="$(python3 -c "print(' '.join(['word'] * 300))")" # ~390 est > 90
out="$(call "$big")"
ck "oversized: empty stdout" "" "$out"
ck "oversized: archived" "none:archive-only" "$(cat "$sb/tmp-modelused.txt")"
ls "$sb"/archive/skipped-*.txt >/dev/null 2>&1 && echo "ok: oversized: prompt archived" || {
  echo "FAIL: oversized: prompt not archived"
  fails=$((fails + 1))
}
hit1="$(wc -l <"$stubdir/status-hits")"
out="$(call "$big")"
ck "oversized: window cached (no extra probe)" "$hit1" "$(wc -l <"$stubdir/status-hits")"

# 3. endpoint down (dead port) -> guard disabled, leg attempted as before.
rm -f "$sb/tmp-unsloth-ctx.txt"
out="$(call "down" 1)"
ck "down: leg attempted (archive-only after failure)" "" "$out"

echo "fails=$fails"
[ "$fails" = 0 ]
