# launch-session.sh — THE gated delegated-session launcher (one path).
# Extracted verbatim from scripts/overnight-cycle.sh's gated-session block
# (2026-09-06) so the watchdog respawn executor (jobs/agent-respawn.sh)
# reuses the exact launch path instead of inventing a second launcher.
#
# Source AFTER lib/common.sh (needs ROOT, BRIDGE, STORE, TIMEOUT_S,
# SESSION_MODEL, classify_cause — sources lib/causes.sh itself if absent).
#
# launch_session SLUG OBJECTIVE PROMPT_FILE -> sets globals:
#   LAUNCH_RC            0 session ran; 75 bridge refused (no session, no
#                        spend — caller files the alert)
#   LAUNCH_RUN_ID        bridge run id
#   LAUNCH_LOG           log path relative to ROOT
#   LAUNCH_DISPOSITION   cancelled (rc=0) | dead (rc!=0) — existing ledger
#                        vocabulary, unchanged
#   LAUNCH_CAUSE         lib/causes.sh classification of the log tail
#   LAUNCH_BRIDGE_MSG    last bridge output line (for the refusal alert)
# Appends the shared delegated-session ledger row to logs/budget.md and
# closes the bridge run. Test seams: OMP_BRIDGE_BIN / OMP_BIN_CMD override
# the real binaries.

declare -F classify_cause >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/causes.sh"
declare -F get_param >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/params.sh"
declare -F context_pack >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/context-pack.sh"
declare -F breadcrumb >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/breadcrumbs.sh"

# append_ocgo_lesson -- the self-steering loop's write side (2026-09-11,
# hngh opencode configuration layer): one line per opencode session into
# automation/state/ocgo-agent-lessons.md — UTC date | cause class | the
# sentence the next session should know (lesson_for_cause, lib/causes.sh).
# The executor/scout agent prompts read this tail at session start and
# steer away from the recorded classes; the file is capped at 200 entries
# (oldest dropped, header kept). Never a daemon; runs inside the launch
# path after classification.
append_ocgo_lesson() { # cause-class
 local file="$AUTOMATION_ROOT/state/ocgo-agent-lessons.md"
 mkdir -p "$AUTOMATION_ROOT/state" 2>/dev/null
 [ -f "$file" ] || printf '%s\n' \
  '# ocgo-agent lessons — one line per opencode session: UTC date | cause' \
  '# class | the sentence the next session should know. The executor/scout' \
  '# agents read the tail at session start and actively avoid the recorded' \
  '# failure classes (the learning loop; design' \
  '# docs/research/2026-09-10-opencode-agentic-surface.md).' >>"$file"
 printf '%s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" \
  "$(lesson_for_cause "$1")" >>"$file"
 # cap: header lines + newest 200 entries
 local header
 header="$(grep -c '^#' "$file" 2>/dev/null || printf 0)"
 {
  head -n "$header" "$file"
  tail -n +"$((header + 1))" "$file" | tail -n 200
 } >"$file.tmp" &&
  mv "$file.tmp" "$file"
}

# default bridge path (overnight-cycle sets BRIDGE itself; respawn and
# standalone callers get the kernel default)
BRIDGE="${BRIDGE:-${HNGH_HOME:-$HOME/Projects/etc/hngh}/scripts/omp-bridge}"

launch_session() { # slug objective prompt_file [role] (env: STORE TIMEOUT_S SESSION_MODEL)
 LAUNCH_RC=0 LAUNCH_RUN_ID="" LAUNCH_LOG="" \
  LAUNCH_DISPOSITION="" LAUNCH_CAUSE="" LAUNCH_BRIDGE_MSG=""
 local slug="$1" objective="$2" prompt_file="$3"
 local role="${4:-overnight-lead}"
 local outcome_model="$SESSION_MODEL" oc_ran=0 oc_rc=0
 local bridge_bin="${OMP_BRIDGE_BIN:-$BRIDGE}"
 local omp_bin="${OMP_BIN_CMD:-}"
 local bctx_bin=""
 if [ -z "$omp_bin" ]; then
  # Machine launches route through the billion-context proxy the same
  # way the operator's interactive fish wrappers do (command bili omp
  # -- $argv in ~/.config/fish/functions/omp.fish) — hngh
  # docs/records/2026-08-24-context-budget-and-toolchain.md chose that
  # path for humans; this makes machine launches match. Fail-open:
  # bili absent means an uncompressed launch with a visible trail,
  # never a failed launch.
  bctx_bin="$(command -v bili || true)"
  if [ -z "$bctx_bin" ]; then
   omp_bin="$(command -v omp || true)"
   [ -n "$omp_bin" ] || omp_bin="$HOME/.bun/bin/omp"
   breadcrumb "launch-session" "bctx-absent" \
    "bctx: bili absent — launching uncompressed"
  fi
 fi

 mkdir -p "${STORE:?STORE unset}" "$ROOT/prompts/overnight" "$ROOT/logs"

 # waste guard: regenerate the context pack fresh at launch so
 # the session cites pre-digested facts instead of re-grepping the repo
 # (session-cost telemetry 2026-09-07: sessions burned up to 3.6M input
 # tokens on orientation alone). Assembled from existing files,
 # size-capped; the path is carried in the session brief below.
 local ctx
 ctx="$(context_pack "$role" "$slug")"

 local bridge_out bridge_rc run_id
 bridge_out="$(OMP_BRIDGE_STORE="$STORE" \
  HNGH_LOADOUT="loadout-route-label=automation loadout-context-limit=2000 loadout-token-limit=50000 loadout-cost-limit=2000 loadout-time-limit=$TIMEOUT_S" \
  "$bridge_bin" --run-start "overnight-$slug" "$objective" 2>&1)"
 bridge_rc=$?
 run_id="$(printf '%s' "$bridge_out" | sed -n 's/.*run \(run-[0-9]*\).*/\1/p' | head -1)"
 if [ "$bridge_rc" -ne 0 ] || [ -z "$run_id" ]; then
  # raised limits refused (fail-closed): retry with config.env verbatim
  bridge_out="$(OMP_BRIDGE_STORE="$STORE" "$bridge_bin" --run-start \
   "overnight-$slug" "$objective" 2>&1)"
  bridge_rc=$?
  run_id="$(printf '%s' "$bridge_out" | sed -n 's/.*run \(run-[0-9]*\).*/\1/p' | head -1)"
  if [ "$bridge_rc" -ne 0 ] || [ -z "$run_id" ]; then
   LAUNCH_RC=75
   LAUNCH_BRIDGE_MSG="$(printf '%s' "$bridge_out" | tail -n 1)"
   return 0
  fi
 fi
 LAUNCH_RUN_ID="$run_id"

 local ts log
 ts="$(date +%Y%m%dT%H%M%S)"
 log="logs/overnight-$slug-$ts.log"
 LAUNCH_LOG="$log"
 local body
 body="$(cat "$prompt_file")

Read the pre-digested repo context at $ctx (regenerated fresh at this
launch) before re-deriving any repo fact from scratch."
 # executor selection (design docs/research/2026-09-10-opencode-agentic-
 # surface.md s5): one cadence-params row; empty/absent = omp fail-closed;
 # env HNGH_SESSION_EXECUTOR overrides the row (per-caller precedence).
 local executor
 executor="${HNGH_SESSION_EXECUTOR:-$(get_param session-executor omp)}"
 # timeout stays OUTSIDE bili (timeout -> bili -> omp): the SIGTERM
 # still lands on the process-tree root and kills the whole tree.
 if [ "$executor" = "opencode" ]; then
  # opencode executor: same wrapper contract, different child. --format
  # json (agent spend + session ids) to the side log; the emitter
  # attributes it (R2) and extracts plain text into the classifier's
  # log path (lib/causes.sh keyword matching — json escapes would
  # break keyword matching, design risk 2). OPENCODE_CONFIG pins the
  # hngh-owned config layer (config/opencode/: copied secret-deny block,
  # executor/scout agent roles, MCP registrations): --auto approves
  # everything not explicitly denied (design risk 1). The credential rides
  # the same trust pattern as model.sh ocgo_chat (env OPENCODE_API_KEY
  # first, else the operator key file, mode 600; the value is never
  # echoed and never exported into the launcher's shell). Fail-closed:
  # opencode binary, model row, or credential absent -> omp with a
  # breadcrumb.
  local oc_bin oc_model oc_key=""
  oc_bin="$(command -v opencode || true)"
  oc_model="$(get_param opencode-model '')"
  if [ -z "${OPENCODE_API_KEY:-}" ]; then
   local kfile="${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}"
   if [ -f "$kfile" ] &&
    [ "$(stat -c %a "$kfile" 2>/dev/null)" = "600" ]; then
    oc_key="$(cat "$kfile" 2>/dev/null)"
   else
    breadcrumb launch-session "ocgo-executor" \
     "no OPENCODE_API_KEY and no 600 key file -> omp"
   fi
  fi
  if [ -n "$oc_bin" ] && [ -n "$oc_model" ] &&
   [ -n "${OPENCODE_API_KEY:-}$oc_key" ]; then
   outcome_model="opencode-go/$oc_model" oc_ran=1
   OPENCODE_API_KEY="${OPENCODE_API_KEY:-$oc_key}" \
    OPENCODE_CONFIG="$AUTOMATION_ROOT/config/opencode/opencode.jsonc" \
    timeout "$TIMEOUT_S" "$oc_bin" run --dir "$ROOT" --format json \
    --agent executor -m "opencode-go/$oc_model" --auto "$body" \
    >"$ROOT/$log.json" 2>&1
   oc_rc=$? # captured before the emitter masks $?
   python3 "$AUTOMATION_ROOT/jobs/ocgo-attribution.py" \
    "$ROOT/$log.json" --plain "$ROOT/$log" \
    --burn "$AUTOMATION_ROOT/state/ocgo-agent-burn.tsv" \
    --telemetry "${HNGH_TELEMETRY_DB:-$AUTOMATION_ROOT/dashboard/telemetry.db}" \
    >/dev/null 2>&1 || true
  else
   breadcrumb launch-session "ocgo-executor" \
    "opencode binary or opencode-model row absent -> omp"
   timeout "$TIMEOUT_S" "$omp_bin" -p --model "$SESSION_MODEL" \
    "$body" >"$ROOT/$log" 2>&1
  fi
 elif [ -n "$bctx_bin" ]; then
  timeout "$TIMEOUT_S" "$bctx_bin" omp -- -p --model "$SESSION_MODEL" \
   "$body" >"$ROOT/$log" 2>&1
 else
  timeout "$TIMEOUT_S" "$omp_bin" -p --model "$SESSION_MODEL" \
   "$body" >"$ROOT/$log" 2>&1
 fi
 LAUNCH_RC=$? # rc=124 = timeout kill; classifier + respawn guards key on it
 # the emitter ran last inside the opencode branch and masked the child's
 # rc — restore it (disposition, cause, and demote key on it; first-session
 # finding 2026-09-11)
 [ "$oc_ran" = 1 ] && LAUNCH_RC="$oc_rc"

 case "$LAUNCH_RC" in
 0) LAUNCH_DISPOSITION="cancelled" ;;
 *) LAUNCH_DISPOSITION="dead" ;;
 esac
 # cause classification for the disposition spine (lib/causes.sh bestiary);
 # a missing/unreadable log classifies as unknown
 LAUNCH_CAUSE="$(classify_cause "$ROOT/$log")"
 # self-steering loop: one lesson line per opencode session (after
 # classification — the lesson cites the cause class). Happy-path skip:
 # a clean exit (rc=0) classified unknown matched no failure keyword —
 # recording it would pollute the file with "you failed" noise on every
 # success (first-session finding 2026-09-11).
 if [ "$oc_ran" = 1 ] && { [ "$LAUNCH_RC" -ne 0 ] ||
  [ "$LAUNCH_CAUSE" != unknown ]; }; then
  append_ocgo_lesson "$LAUNCH_CAUSE"
 fi
 printf '%s | overnight|%s | session-run\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" >>"$ROOT/logs/budget.md"
 OMP_BRIDGE_STORE="$STORE" "$bridge_bin" --run-end "$run_id" \
  "$LAUNCH_DISPOSITION" >/dev/null 2>&1 || true
 # model-outcome demotion counter (stall-recovery step 1): ok resets,
 # bad-execution counts toward demotion, other classes only record
 declare -F record_model_outcome >/dev/null ||
  . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model-demote.sh"
 if [ "$LAUNCH_RC" -eq 0 ] && [ -s "$ROOT/$log" ] && [ "$LAUNCH_CAUSE" != bad-execution ]; then
  record_model_outcome "$outcome_model" ok
 else
  record_model_outcome "$outcome_model" "$LAUNCH_CAUSE"
 fi
 return 0
}
