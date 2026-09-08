# stub-lib.sh — the one HTTP stub for the model-leg tests (reorientation
# A4: the five duplicated stub_start definitions folded into this lib).
# stub_start NAME [SLEEP] -> stub on 127.0.0.1:<ephemeral>, port written
# to $stubdir/<NAME>-port (silent on stdout: never call it inside $( ) —
# the background server would hold the capture pipe open). Every POST is
# recorded: request path appended to $stubdir/<NAME>-hits, raw body
# appended to $stubdir/<NAME>-bodies (one per line) so tests can prove a
# leg was (or was never) reached and inspect the request shape. Reply is
# the superset body (OpenAI choices[], ollama .message, and the lobehub
# Responses .output_text shape all parse) with content: synthesis prompts
# -> $stubdir/synth-reply (or "no-subjects"), VERDICT prompts -> a
# parseable verdict (the review-transition path), else $STUB_CONTENT
# (default "stub-says-hi"). SLEEP seconds delay the answer — the
# MODEL_TIMEOUT proof. Caller owns $stubdir, stub_pids="" init, and the
# kill trap.
stub_start() { # name [sleep_seconds]
  local name="$1" sleep_s="${2:-0}"
  rm -f "$stubdir/$name-port" "$stubdir/$name-hits" "$stubdir/$name-bodies"
  touch "$stubdir/$name-hits" "$stubdir/$name-bodies"
  STUB_CONTENT="${STUB_CONTENT:-stub-says-hi}" python3 - "$stubdir" "$name" "$sleep_s" <<'PY' &
import http.server, socketserver, sys, json, os, time
d, name, sleep_s = sys.argv[1], sys.argv[2], float(sys.argv[3])
default_content = os.environ.get("STUB_CONTENT", "stub-says-hi")
class H(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_POST(self):
        n = int(self.headers.get("Content-Length", 0)); body = self.rfile.read(n)
        with open(os.path.join(d, name + "-hits"), "a") as f:
            f.write(self.path + "\n")
        with open(os.path.join(d, name + "-bodies"), "ab") as f:
            f.write(body + b"\n")
        text = body.decode("utf-8", "replace")
        if "Propose 2-3 research subjects" in text:
            p = os.path.join(d, "synth-reply")
            content = open(p).read() if os.path.exists(p) else "no-subjects"
        elif "VERDICT:" in text:
            content = "VERDICT: parked -- stub reason"
        else:
            content = default_content
        out = json.dumps({"choices": [{"message": {"content": content}}],
                          "message": {"content": content},
                          "object": "response", "status": "completed",
                          "output_text": content,
                          "output": [{"content": [{"type": "output_text", "text": content}],
                                      "role": "assistant", "status": "completed",
                                      "type": "message"}]}).encode()
        time.sleep(sleep_s)
        self.send_response(200); self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(out))); self.end_headers()
        self.wfile.write(out)
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
