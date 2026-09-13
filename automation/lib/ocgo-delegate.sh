# ocgo-delegate.sh — the omp hngh_opencode tool's ONE launch path
# (2026-09-13). Delegates a single bounded opencode session through
# lib/launch-session.sh's opencode branch; every cost control lives in
# that branch already (context pack, OPENCODE_CONFIG pin to config/
# opencode/opencode.jsonc, bili env-only MITM, R2 attribution emitter,
# lesson append, budget row) — this wrapper reuses it, never
# re-implements it, and adds only what the branch does not decide:
#
#   usage: ocgo-delegate.sh SLUG OBJECTIVE [MAX_MINUTES]
#
#   (a) 5h pacer BEFORE anything spends: quota_pace_blocked_5h counts
#       sources ocgo,ocgo-agent together against opencode-cap-5h-calls
#       (cadence-params.tsv; env OCGO_CAP_5H_CALLS overrides) -- blocked
#       -> exit 75 with a budget line, no session, no bridge run
#       (fail-closed: no budget = no session).
#   (b) lessons read: the tail of state/ocgo-agent-lessons.md rides in
#       the prompt (the append side stays in launch_session's
#       classification hook).
#   (c) timeout: MAX_MINUTES clamped to 1..30 -- the 30-minute ceiling is
#       the opencode-agent leg budget (config/leg-budgets.tsv max-time
#       1800s); default 10 (600s), one session per invocation.
#
# stdout: key=value result lines (session/rc/disposition/cause/log/
# run_id). Exit 0 = session ran clean, 1 = session ran and died,
# 75 = refused before any spend (pacer or bridge).
set -u

AROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$AROOT/lib/common.sh"
. "$AROOT/lib/params.sh"
. "$AROOT/lib/launch-session.sh"
. "$AROOT/lib/model.sh" # quota_pace_blocked_5h

ROOT="${ROOT:-${HNGH_HOME:-$HOME/Projects/etc/hngh}}"
STORE="${STORE:-$AUTOMATION_ROOT/store/ocgo-delegate}"
mkdir -p "$STORE" "$ROOT/prompts/overnight" "$ROOT/logs"

slug="${1:-task}"
slug="$(LC_ALL=C printf '%s' "$slug" | tr -c 'A-Za-z0-9' '-')"
objective="${2:-}"
max_min="${3:-10}"
case "$max_min" in *[!0-9]* | '') max_min=10 ;; esac
[ "$max_min" -ge 1 ] || max_min=1
[ "$max_min" -le 30 ] || max_min=30 # leg budget: opencode-agent 1800s
TIMEOUT_S=$((max_min * 60))

# (a) pacer first -- nothing after this line spends until the check passes
cap="${OCGO_CAP_5H_CALLS:-$(get_param opencode-cap-5h-calls 60)}"
pace="$(quota_pace_blocked_5h ocgo,ocgo-agent "$cap")"
if [ -n "$pace" ]; then
 printf 'refused: budget pacer blocked -- ocgo+ocgo-agent used %s of cap %s in the trailing 5h window (opencode-cap-5h-calls); no session launched\n' \
  "${pace% *}" "${pace#* }" >&2
 exit 75
fi

# (b) lessons read: bounded tail, the executor steers away from the
# recorded failure classes (the learning loop's read side)
lessons=""
lfile="$AUTOMATION_ROOT/state/ocgo-agent-lessons.md"
if [ -f "$lfile" ]; then
 lessons="$(tail -n 5 "$lfile")"
fi

prompt="$ROOT/prompts/overnight/ocgo-delegate-$slug-$$.txt"
{
 printf '%s\n\n' "$objective"
 if [ -n "$lessons" ]; then
  printf 'Lessons from previous opencode sessions (actively avoid the recorded failure classes):\n%s\n' \
   "$lessons"
 fi
} >"$prompt"

HNGH_SESSION_EXECUTOR=opencode launch_session "ocgo-$slug" "$objective" \
 "$prompt" executor
rm -f "$prompt"

printf 'session=%s\nrc=%s\ndisposition=%s\ncause=%s\nlog=%s\nrun_id=%s\n' \
 "$slug" "$LAUNCH_RC" "$LAUNCH_DISPOSITION" "$LAUNCH_CAUSE" \
 "$LAUNCH_LOG" "$LAUNCH_RUN_ID"
printf 'timeout_s=%s\n' "$TIMEOUT_S"
if [ "$LAUNCH_RC" -eq 0 ]; then
 exit 0
fi
if [ "$LAUNCH_RC" -eq 75 ]; then
 printf 'refused: bridge refused the launch (no session, no spend): %s\n' \
  "$LAUNCH_BRIDGE_MSG" >&2
 exit 75
fi
exit 1
