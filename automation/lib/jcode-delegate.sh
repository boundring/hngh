# jcode-delegate.sh — the omp hngh_jcode tool's ONE launch path
# (2026-09-14). Delegates a single bounded jcode session through
# lib/launch-session.sh's jcode branch; every cost control lives in
# that branch already (context pack, jcode's own config auth, plain-log
# classification, budget row) — this wrapper reuses it, never
# re-implements it, and adds only what the branch does not decide:
#
#   usage: jcode-delegate.sh SLUG OBJECTIVE [MAX_MINUTES] [PROVIDER]
#        PROVIDER: zai (default) | unsloth; env JCODE_PROVIDER also
#        selects (arg wins). zai rides the Z.AI subscription jcode
#        already holds auth for (paced against the zai caps); unsloth
#        rides the local OpenAI-compatible endpoint (no pacer).
#
#   (a) pacer BEFORE anything spends: the zai leg counts against
#       zai-cap-5h-calls + zai-cap-week-calls (tightest wins) -- the
#       same subscription model.sh zai_chat spends; blocked -> exit 75
#       with a budget line, no session, no bridge run.
#   (b) lessons read: the tail of state/ocgo-agent-lessons.md rides in
#       the prompt (the executor steers away from the recorded failure
#       classes; the append side stays in launch_session).
#   (c) timeout: MAX_MINUTES clamped to 1..30, default 10 (600s), one
#       session per invocation.
#
# stdout: key=value result lines (session/rc/disposition/cause/log/
# run_id/provider/timeout_s). Exit 0 = session ran clean, 1 = session
# ran and died, 75 = refused before any spend (pacer or bridge).
set -u

AROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$AROOT/lib/common.sh"
. "$AROOT/lib/params.sh"
. "$AROOT/lib/launch-session.sh"
. "$AROOT/lib/model.sh" # zai_pace_blocked

ROOT="${ROOT:-${HNGH_HOME:-$(cd "$(dirname "$0")/../.." && pwd)}}"
STORE="${STORE:-$AUTOMATION_ROOT/store/jcode-delegate}"
mkdir -p "$STORE" "$ROOT/prompts/overnight" "$ROOT/logs"

slug="${1:-task}"
slug="$(LC_ALL=C printf '%s' "$slug" | tr -c 'A-Za-z0-9' '-')"
objective="${2:-}"
max_min="${3:-10}"
provider="${4:-${JCODE_PROVIDER:-zai}}"
case "$provider" in
zai | unsloth) ;;
*)
 printf 'refused: unknown provider %s (zai | unsloth); no session launched\n' \
  "$provider" >&2
 exit 2
 ;;
esac
case "$max_min" in *[!0-9]* | '') max_min=10 ;; esac
[ "$max_min" -ge 1 ] || max_min=1
[ "$max_min" -le 30 ] || max_min=30
TIMEOUT_S=$((max_min * 60))
# launch_session's omp-fallback model (env > paid model > the house
# default); unbound under set -u otherwise
SESSION_MODEL="${SESSION_MODEL:-${OVERNIGHT_PAID_MODEL:-zai/glm-5.3}}"

# (a) pacer first -- the zai leg shares the model.sh zai_chat budget;
# unsloth is the local box, unpaced
if [ "$provider" = "zai" ]; then
 pace="$(zai_pace_blocked || true)"
 if [ -n "$pace" ]; then
  printf 'refused: budget pacer blocked -- zai %s-window used %s of cap %s; no session launched\n' \
   "${pace%% *}" "${pace#* }" >&2
  exit 75
 fi
fi

# (b) lessons read: bounded tail, the executor steers away from the
# recorded failure classes (the learning loop's read side)
lessons=""
lfile="$AUTOMATION_ROOT/state/ocgo-agent-lessons.md"
if [ -f "$lfile" ]; then
 lessons="$(tail -n 5 "$lfile")"
fi

prompt="$ROOT/prompts/overnight/jcode-delegate-$slug-$$.txt"
{
 printf '%s\n\n' "$objective"
 if [ -n "$lessons" ]; then
  printf 'Lessons from previous agent sessions (actively avoid the recorded failure classes):\n%s\n' \
   "$lessons"
 fi
} >"$prompt"

JCODE_PROVIDER="$provider" HNGH_SESSION_EXECUTOR=jcode \
 launch_session "jcode-$slug" "$objective" "$prompt" executor
rm -f "$prompt"

printf 'session=%s\nrc=%s\ndisposition=%s\ncause=%s\nlog=%s\nrun_id=%s\n' \
 "$slug" "$LAUNCH_RC" "$LAUNCH_DISPOSITION" "$LAUNCH_CAUSE" \
 "$LAUNCH_LOG" "$LAUNCH_RUN_ID"
printf 'provider=%s\ntimeout_s=%s\n' "$provider" "$TIMEOUT_S"
if [ "$LAUNCH_RC" -eq 0 ]; then
 exit 0
fi
if [ "$LAUNCH_RC" -eq 75 ]; then
 printf 'refused: bridge refused the launch (no session, no spend): %s\n' \
  "$LAUNCH_BRIDGE_MSG" >&2
 exit 75
fi
exit 1
