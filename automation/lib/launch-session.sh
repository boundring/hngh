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
declare -F context_pack >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/context-pack.sh"
declare -F breadcrumb >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/breadcrumbs.sh"

# default bridge path (overnight-cycle sets BRIDGE itself; respawn and
# standalone callers get the kernel default)
BRIDGE="${BRIDGE:-${HNGH_HOME:-$HOME/Projects/etc/hngh}/scripts/omp-bridge}"

launch_session() { # slug objective prompt_file [role] (env: STORE TIMEOUT_S SESSION_MODEL)
 LAUNCH_RC=0 LAUNCH_RUN_ID="" LAUNCH_LOG="" \
  LAUNCH_DISPOSITION="" LAUNCH_CAUSE="" LAUNCH_BRIDGE_MSG=""
 local slug="$1" objective="$2" prompt_file="$3"
 local role="${4:-overnight-lead}"
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
 # timeout stays OUTSIDE bili (timeout -> bili -> omp): the SIGTERM
 # still lands on the process-tree root and kills the whole tree.
 if [ -n "$bctx_bin" ]; then
  timeout "$TIMEOUT_S" "$bctx_bin" omp -- -p --model "$SESSION_MODEL" \
   "$body" >"$ROOT/$log" 2>&1
 else
  timeout "$TIMEOUT_S" "$omp_bin" -p --model "$SESSION_MODEL" \
   "$body" >"$ROOT/$log" 2>&1
 fi
 LAUNCH_RC=$? # rc=124 = timeout kill; classifier + respawn guards key on it

 case "$LAUNCH_RC" in
 0) LAUNCH_DISPOSITION="cancelled" ;;
 *) LAUNCH_DISPOSITION="dead" ;;
 esac
 # cause classification for the disposition spine (lib/causes.sh bestiary);
 # a missing/unreadable log classifies as unknown
 LAUNCH_CAUSE="$(classify_cause "$ROOT/$log")"
 printf '%s | overnight|%s | session-run\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" >>"$ROOT/logs/budget.md"
 OMP_BRIDGE_STORE="$STORE" "$bridge_bin" --run-end "$run_id" \
  "$LAUNCH_DISPOSITION" >/dev/null 2>&1 || true
 # model-outcome demotion counter (stall-recovery step 1): ok resets,
 # bad-execution counts toward demotion, other classes only record
 declare -F record_model_outcome >/dev/null ||
  . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model-demote.sh"
 if [ "$LAUNCH_RC" -eq 0 ] && [ -s "$ROOT/$log" ] && [ "$LAUNCH_CAUSE" != bad-execution ]; then
  record_model_outcome "$SESSION_MODEL" ok
 else
  record_model_outcome "$SESSION_MODEL" "$LAUNCH_CAUSE"
 fi
 return 0
}
