# launch-jcode.sh — Jcode executor wrapper for the delegated-session lane
# (plan step 3, 2026-09-14-jcode-primary-harness.plan.md). Same outer
# contract as the omp/opencode branches in lib/launch-session.sh: prompt
# file in, plain-text log out, exit rc 0 ran | 75 refused | 1 failed.
# The bridge run-start/run-end wrapping stays in launch-session.sh; this
# wrapper is only the child spawn, so the lane selector can point
# session-executor at jcode without duplicating ledger logic.
#
# Env:
#   JCODE_PROMPT_FILE   prompt file (required)
#   JCODE_LOG           output log path (required; plain text for
#                       lib/causes.sh keyword classification)
#   JCODE_WORKER_APPROVE  set to 1 ONLY with a valid JCODE_WORKER_CERT;
#                       forwarded to worker.mjs (certificate bridge)
#   JCODE_WORKER_CERT   certificate scope file (JSON: {"actions": [...],
#                       "expires": "<ISO-8601>"}); REQUIRED when approve
#                       is set; the wrapper validates shape + expiry
#                       fail-closed before any child spawns
#   JCODE_WORKER_HOME   instance home (default ~/.hngh-jcode-worker;
#                       created pinned, one runtime dir per lane)
#   JCODE_WORKER_TIMEOUT_MS  turn timeout (default 300000)
set -u

launch_jcode_worker() {
 local rc=0
 # resolved at CALL time: an env override set after sourcing must win
 # (hermetic tests bind a stub per case)
 local jcode_worker_bin="${JCODE_WORKER_BIN:-$(dirname "${BASH_SOURCE[0]}")/../jcode/worker.mjs}"
 local rc=0
 [ -n "${JCODE_PROMPT_FILE:-}" ] && [ -f "$JCODE_PROMPT_FILE" ] || {
  printf 'jcode-worker: JCODE_PROMPT_FILE missing\n' >&2
  return 75
 }
 [ -n "${JCODE_LOG:-}" ] || {
  printf 'jcode-worker: JCODE_LOG missing\n' >&2
  return 75
 }
 [ -r "$jcode_worker_bin" ] || {
  printf 'jcode-worker: shim absent: %s\n' "$jcode_worker_bin" >&2
  return 75
 }
 command -v node >/dev/null 2>&1 || {
  printf 'jcode-worker: node absent\n' >&2
  return 75
 }
 # certificate bridge (plan step 4): approve mode is invalid without a
 # certificate file that parses, has a non-empty actions array, and is
 # unexpired. Fail-closed BEFORE any child spawns (no spend on a bad
 # certificate). The shim re-validates (defense in depth).
 if [ "${JCODE_WORKER_APPROVE:-0}" = "1" ]; then
  [ -n "${JCODE_WORKER_CERT:-}" ] && [ -r "$JCODE_WORKER_CERT" ] || {
   printf 'jcode-worker: approve set but JCODE_WORKER_CERT missing\n' >&2
   return 75
  }
  python3 - "$JCODE_WORKER_CERT" <<'PYEOF' || return 75
import json, sys
from datetime import datetime, timezone
try:
    cert = json.load(open(sys.argv[1]))
    actions = cert["actions"]
    assert isinstance(actions, list) and actions, "actions must be a non-empty array"
    exp = datetime.fromisoformat(cert["expires"].replace("Z", "+00:00"))
    assert exp > datetime.now(timezone.utc), "certificate expired"
except Exception as exc:
    print(f"jcode-worker: certificate invalid: {exc}", file=sys.stderr)
    sys.exit(1)
PYEOF
 fi
 # node --input-type keeps argv as the single prompt source; the prompt
 # is passed as one argv blob (no shell interpolation of file content).
 local prompt_blob
 prompt_blob="$(cat "$JCODE_PROMPT_FILE")"
 node "$jcode_worker_bin" "$prompt_blob" >"$JCODE_LOG" 2>"$JCODE_LOG.err"
 rc=$?
 # errors go to a side log so the classifier reads only model text
 [ "$rc" -ne 0 ] && printf 'stderr:\n' >>"$JCODE_LOG" && \
  tail -c 2000 "$JCODE_LOG.err" >>"$JCODE_LOG"
 rm -f "$JCODE_LOG.err"
 return "$rc"
}
