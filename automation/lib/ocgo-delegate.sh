# ocgo-delegate.sh — the omp hngh_opencode tool's ONE launch path
# (2026-09-13). Delegates a single bounded opencode session through
# lib/launch-session.sh's opencode branch; every cost control lives in
# that branch already (context pack, OPENCODE_CONFIG pin to config/
# opencode/opencode.jsonc, bili env-only MITM, R2 attribution emitter,
# lesson append, budget row) — this wrapper reuses it, never
# re-implements it, and adds only what the branch does not decide:
#
#   usage: ocgo-delegate.sh SLUG OBJECTIVE [MAX_MINUTES] [PROVIDER]
#        PROVIDER: opencode-go (default) | kimi | zai; env OCGO_PROVIDER
#        also selects (arg wins). kimi rides the Kimi Code K3 quota
#        (model.sh kimi_chat key order; child sees KIMI_API_KEY only),
#        paced against kimi-daily-cap. zai rides the Z.AI subscription
#        (Z_AI_API_KEY; child sees ZAI_API_KEY only), paced against
#        zai-cap-5h-calls + zai-cap-week-calls (tightest wins).
#
#   (a) multi-window pacer BEFORE anything spends: ocgo_pace_blocked
#       gates EVERY OpenCode Go window (5h $12 / 7d $30 / monthly $60 ->
#       opencode-cap-{5h,7d,month}-calls; tightest window wins, sources
#       ocgo,ocgo-agent counted together) -- blocked -> exit 75 with a
#       budget line, no session, no bridge run (fail-closed: no budget =
#       no session).
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
. "$AROOT/lib/model.sh" # ocgo_pace_blocked

ROOT="${ROOT:-${HNGH_HOME:-$(cd "$(dirname "$0")/../.." && pwd)}}"
STORE="${STORE:-$AUTOMATION_ROOT/store/ocgo-delegate}"
mkdir -p "$STORE" "$ROOT/prompts/overnight" "$ROOT/logs"

slug="${1:-task}"
slug="$(LC_ALL=C printf '%s' "$slug" | tr -c 'A-Za-z0-9' '-')"
objective="${2:-}"
max_min="${3:-10}"
provider="${4:-${OCGO_PROVIDER:-opencode-go}}"
case "$provider" in
opencode-go | kimi | zai) ;;
*)
 printf 'refused: unknown provider %s (opencode-go | kimi | zai); no session launched\n' \
  "$provider" >&2
 exit 2
 ;;
esac
case "$max_min" in *[!0-9]* | '') max_min=10 ;; esac
[ "$max_min" -ge 1 ] || max_min=1
[ "$max_min" -le 30 ] || max_min=30 # leg budget: opencode-agent 1800s
TIMEOUT_S=$((max_min * 60))
# launch_session's omp-fallback model (env > paid model > the house
# default -- the same chain agent-respawn.sh:57 applies); unbound under
# set -u otherwise, which killed the first live tool-path launch
SESSION_MODEL="${SESSION_MODEL:-${OVERNIGHT_PAID_MODEL:-zai/glm-5.3}}"

# (a) pacer first -- nothing after this line spends until the check passes
if [ "$provider" = "zai" ]; then
 # same Z.AI subscription the model.sh zai_chat leg spends: count both
 # against the 5h + weekly pair (env ZAI_CAP_5H_CALLS / ZAI_CAP_WEEK_CALLS override)
 pace="$(zai_pace_blocked || true)"
 if [ -n "$pace" ]; then
  _o_label="${pace%% *}" _o_used="${pace#* }"
  printf 'refused: budget pacer blocked -- zai %s-window used %s of cap %s; no session launched\n' \
   "$_o_label" "${_o_used%% *}" "${_o_used##* }" >&2
  exit 75
 fi
elif [ "$provider" = "kimi" ]; then
 # same Kimi quota the deck-chat leg spends: count both against
 # kimi-daily-cap (env KIMI_DAILY_CAP_CALLS overrides)
 cap="${KIMI_DAILY_CAP_CALLS:-$(get_param kimi-daily-cap 40)}"
 pace="$(quota_pace_blocked kimi "$cap" || true)"
 if [ -n "$pace" ]; then
  printf 'refused: budget pacer blocked -- kimi used %s of cap %s today (kimi-daily-cap); no session launched\n' \
   "${pace% *}" "${pace#* }" >&2
  exit 75
 fi
else
 pace="$(ocgo_pace_blocked)"
 if [ -n "$pace" ]; then
  _o_label="${pace%% *}" _o_used="${pace#* }"
  printf 'refused: budget pacer blocked -- ocgo+ocgo-agent %s-window used %s of cap %s; no session launched\n' \
   "$_o_label" "${_o_used%% *}" "${_o_used##* }" >&2
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

prompt="$ROOT/prompts/overnight/ocgo-delegate-$slug-$$.txt"
{
 printf '%s\n\n' "$objective"
 if [ -n "$lessons" ]; then
  printf 'Lessons from previous opencode sessions (actively avoid the recorded failure classes):\n%s\n' \
   "$lessons"
 fi
} >"$prompt"

OCGO_PROVIDER="$provider" HNGH_SESSION_EXECUTOR=opencode \
 launch_session "ocgo-$slug" "$objective" "$prompt" executor
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
