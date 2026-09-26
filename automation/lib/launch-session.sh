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
#   LAUNCH_DISPOSITION   complete (rc=0) | dead (rc!=0) — P4 root-cause
#                        fix: a clean rc=0 run is complete; the old
#                        "cancelled" label mislabeled every healthy
#                        session as a cause=unknown cancellation
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
declare -F launch_jcode_worker >/dev/null ||
 . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/launch-jcode.sh"

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
BRIDGE="${BRIDGE:-${HNGH_HOME:-$(cd "$(dirname "$0")/../.." && pwd)}/scripts/omp-bridge}"

# bridge store per launch: hngh records run-1 per store, so two
# --run-start calls against one store record-conflict. A beat used to
# share one store across its dream pass and executor (and extra plan
# slots), so every launch after the first refused rc=75 with no session
# and no spend — the 2026-09-11 throughput stall. run-end MUST use the
# same store as run-start (omp-bridge closes the run in BRIDGE_STORE),
# so the dir is fixed per launch, not per process.
launch_store() { # -> fresh bridge store dir for this launch on stdout
 printf '%s/launch-%s-%s' "${STORE:?STORE unset}" "$1" "$(date +%Y%m%dT%H%M%S)-$$"
}

launch_session() { # slug objective prompt_file [role] (env: STORE TIMEOUT_S SESSION_MODEL)
 LAUNCH_RC=0 LAUNCH_RUN_ID="" LAUNCH_LOG="" \
  LAUNCH_DISPOSITION="" LAUNCH_CAUSE="" LAUNCH_BRIDGE_MSG=""
 local slug="$1" objective="$2" prompt_file="$3"
 # session class for the budget row (cost-tiering plan step 1): set
 # by the selector for a plan step, defaults T2; anything other than
 # an exact T1/T2/T3 fails closed to the T2 default.
 local sclass="${SESSION_CLASS:-T2}"
 case "$sclass" in
 T1 | T2 | T3) ;;
 *) sclass="T2" ;;
 esac
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
 # $slug rides to launch_store: a bare call loses the caller's
 # positionals under set -u (bash 5.3), silently voiding the per-launch
 # store dir and falling back to the shared default -> record-conflict
 # refusals. Caught live by the 2026-09-11 bili-ocgo verification run.
 local bridge_store="$(launch_store "$slug")"
 bridge_out="$(OMP_BRIDGE_STORE="$bridge_store" \
  HNGH_LOADOUT="loadout-route-label=automation loadout-context-limit=2000 loadout-token-limit=50000 loadout-cost-limit=2000 loadout-time-limit=$TIMEOUT_S" \
  "$bridge_bin" --run-start "overnight-$slug" "$objective" 2>&1)"
 bridge_rc=$?
 run_id="$(printf '%s' "$bridge_out" | sed -n 's/.*run \(run-[0-9]*\).*/\1/p' | head -1)"
 if [ "$bridge_rc" -ne 0 ] || [ -z "$run_id" ]; then
  # raised limits refused (fail-closed): retry with config.env verbatim
  bridge_out="$(OMP_BRIDGE_STORE="$bridge_store" "$bridge_bin" --run-start \
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
launch) before re-deriving any repo fact from scratch.

Bead circulation (bloodstream): if your assignment names a bead id
(hngh-XXX), claim it first with \`bd update <id> --status in_progress\`,
and close it with \`bd update <id> --status closed\` plus a \`bd comment\`
carrying commit hashes, files, and validation. Evidence on the bead,
not just in your report. DONE rule (browser-use steal, hngh-ddc): a
close claim requires independent verification -- run the evidence
Noul first (lib/typesafe.py: closeout_evidence_noul over the claimed
summary); a False verdict means the evidence does not support closing,
so do not close. None (no key/offline) keeps the existing human gate."
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
  local oc_bin oc_model oc_key="" bili_bin borigin="" bili_pid=""
  # registry-first (2026-09-26): hngh-packages.tsv col 4 names THE
  # opencode channel; PATH shadows lose (pacman v2 removed --dir and
  # killed machine-lane launches). No row / absent binary -> PATH.
  oc_bin=""
  reg_bin="$(awk -F'\t' -v h="$HOME" '$1=="opencode" {p=$4; gsub(/^~/, h, p); print p; exit}' \
   "$AUTOMATION_ROOT/config/hngh-packages.tsv" 2>/dev/null)"
  if [ -n "$reg_bin" ] && [ -x "$reg_bin" ]; then
   oc_bin="$reg_bin"
  else
   oc_bin="$(command -v opencode || true)"
   [ -n "$reg_bin" ] && breadcrumb launch-session "ocgo-executor" \
    "registry opencode ($reg_bin) absent -> PATH resolution"
  fi
  # test seam mirrors OMP_BIN_CMD; hermetic tests scope PATH instead of
  # set-but-empty (the empty value falls through to PATH discovery)
  bili_bin="${BILI_OCGO_BIN:-$(command -v bili || true)}"
  # provider selection (operator quota-utilization directive 2026-09-13):
  # env OCGO_PROVIDER picks the quota leg -- opencode-go (default, the
  # OpenCode Go T2 bucket) | kimi (Kimi Code K3 quota). Fail-closed: an
  # unknown value falls back to opencode-go with a breadcrumb.
  local oc_provider="${OCGO_PROVIDER:-opencode-go}"
  case "$oc_provider" in
  opencode-go | kimi | zai) ;;
  *)
   breadcrumb launch-session "ocgo-executor" \
    "unknown OCGO_PROVIDER '$oc_provider' -> opencode-go"
   oc_provider="opencode-go"
   ;;
  esac
  if [ "$oc_provider" = "kimi" ]; then
   oc_model="$(get_param kimi-model '')"
  elif [ "$oc_provider" = "zai" ]; then
   oc_model="$(get_param zai-model '')"
  else
   oc_model="$(get_param opencode-model '')"
  fi
  local kfile=""
  if [ "$oc_provider" = "kimi" ] || [ "$oc_provider" = "zai" ]; then
   # quota-provider keys: same trust pattern as the model.sh chat legs
   # (env first, else 600 key file); the value reaches the child ONLY as
   # the config layer's {env:...} name. Never echoed, never logged.
   if [ "$oc_provider" = "zai" ]; then
    oc_key="${Z_AI_API_KEY:-}"
    kfile="${ZAI_KEY_FILE:-$HOME/.config/hngh/zai-key}"
   else
    # Kimi Code key: the SAME resolution order as model.sh kimi_chat (env
    # KIMI_AI_KEY -> KIMI_FOR_CODING_KEY -> MOONSHOTAI_API_KEY -> key file
    # mode 600). The value reaches the child ONLY as KIMI_API_KEY (the
    # config layer's {env:KIMI_API_KEY}); never echoed, never logged.
    oc_key="${KIMI_AI_KEY:-${KIMI_FOR_CODING_KEY:-${MOONSHOTAI_API_KEY:-}}}"
    kfile="${KIMI_KEY_FILE:-$HOME/.config/hngh/kimi-key}"
   fi
   if [ -z "$oc_key" ]; then
    if [ -f "$kfile" ] &&
     [ "$(stat -c %a "$kfile" 2>/dev/null)" = "600" ]; then
     oc_key="$(cat "$kfile" 2>/dev/null)"
    else
     breadcrumb launch-session "ocgo-executor" \
      "$oc_provider: no env key and no 600 key file -> omp"
    fi
   fi
  else
   if [ -z "${OPENCODE_API_KEY:-}" ]; then
    kfile="${OPENCODE_KEY_FILE:-$HOME/.config/hngh/opencode-key}"
    if [ -f "$kfile" ] &&
     [ "$(stat -c %a "$kfile" 2>/dev/null)" = "600" ]; then
     oc_key="$(cat "$kfile" 2>/dev/null)"
    else
     breadcrumb launch-session "ocgo-executor" \
      "no OPENCODE_API_KEY and no 600 key file -> omp"
    fi
   fi
  fi
  local oc_ready=""
  if [ "$oc_provider" = "kimi" ] || [ "$oc_provider" = "zai" ]; then
   [ -n "$oc_key" ] && oc_ready=1 # env OPENCODE_API_KEY is the OTHER quota
  else
   [ -n "${OPENCODE_API_KEY:-}$oc_key" ] && oc_ready=1
  fi
  # quota pacing at the CHOKE POINT (quota-tightest-window-pacing rule,
  # 2026-09-13): the wrapper's pacer only guards the wrapper route, so the
  # branch enforces pacing itself BEFORE the first call lands --
  # opencode-go through ocgo_pace_blocked (EVERY product window gated,
  # tightest wins: 5h $12 / 7d $30 / monthly $60, sources
  # ocgo+ocgo-agent counted together), kimi against the daily cap it
  # shares with the deck-chat leg. Blocked or pacer unavailable -> omp fallback
  # (fail-closed: no budget = no session). The wrapper keeps its earlier
  # rc=75 refusal (cheaper: no bridge run); this is the guarantee that
  # every route is paced, not just the wrapper's.
  local pace_blocked=""
  declare -F ocgo_pace_blocked >/dev/null || {
   [ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model.sh" ] &&
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model.sh"
  }
  if ! declare -F ocgo_pace_blocked >/dev/null; then
   breadcrumb launch-session "ocgo-executor" \
    "quota pacer unavailable -> omp (fail-closed)"
   pace_blocked="unavailable"
  elif [ "$oc_provider" = "kimi" ]; then
   local capd="${KIMI_DAILY_CAP_CALLS:-$(get_param kimi-daily-cap 40)}"
   pace_blocked="$(quota_pace_blocked kimi "$capd" || true)"
   [ -n "$pace_blocked" ] && breadcrumb launch-session "ocgo-executor" \
    "kimi daily pacer blocked (${pace_blocked% *} of cap ${pace_blocked#* }) -> omp"
  elif [ "$oc_provider" = "zai" ]; then
   declare -F zai_pace_blocked >/dev/null || true
   pace_blocked="$(zai_pace_blocked || true)"
   [ -n "$pace_blocked" ] && breadcrumb launch-session "ocgo-executor" \
    "Z.AI pacer blocked (${pace_blocked%% *}-window used ${pace_blocked#* }) -> omp"
  else
   pace_blocked="$(ocgo_pace_blocked || true)"
   [ -n "$pace_blocked" ] && breadcrumb launch-session "ocgo-executor" \
    "opencode-go pacer blocked (${pace_blocked%% *}-window used ${pace_blocked#* }) -> omp"
  fi
  if [ -n "$oc_bin" ] && [ -n "$oc_model" ] && [ -n "$oc_ready" ] &&
   [ -z "$pace_blocked" ]; then
   outcome_model="$oc_provider/$oc_model" oc_ran=1
   local oc_agent="executor" oc_model_flag="opencode-go/$oc_model"
   local emit_src=()
   if [ "$oc_provider" = "kimi" ]; then
    # dedicated agent (config layer pins executor to opencode-go) and
    # attribution source=kimi so the kimi daily pacer counts these calls
    oc_agent="executor-kimi"
    oc_model_flag="kimi/$oc_model"
    emit_src=(--source kimi)
   elif [ "$oc_provider" = "zai" ]; then
    oc_agent="executor-zai"
    oc_model_flag="zai/$oc_model"
    emit_src=(--source zai)
   fi
   # bili compression on the opencode leg (2026-09-11): env-only MITM
   # redirect — the hngh config layer is NEVER written or replaced
   # (`bili opencode`'s temp-config path strict-parses JSON and would
   # silently drop the .jsonc layer incl. the secret-deny block;
   # docs/records/2026-09-11-bili-opencode.md). A healthy proxy on
   # BILI_OCGO_PORT (default 8787) is reused; else one is spawned
   # (killed after the run); bili absent/unreachable -> fail-open
   # direct with a visible breadcrumb, exactly like the omp branch.
   local bport="${BILI_OCGO_PORT:-8787}"
   if [ -n "$bili_bin" ]; then
    if curl -sf -m 2 "http://127.0.0.1:$bport/__bili/health" \
     >/dev/null 2>&1; then
     borigin="http://127.0.0.1:$bport"
    else
     BILI_MITM_DOMAINS=opencode.ai "$bili_bin" start \
      --host 127.0.0.1 --port "$bport" \
      >>"$ROOT/logs/bili-ocgo-$ts.log" 2>&1 &
     bili_pid=$!
     local _try=0
     while [ -z "$borigin" ] && [ "$_try" -lt 20 ]; do
      sleep 0.5
      curl -sf -m 2 "http://127.0.0.1:$bport/__bili/health" \
       >/dev/null 2>&1 && borigin="http://127.0.0.1:$bport"
      _try=$((_try + 1))
     done
     if [ -z "$borigin" ]; then
      kill "$bili_pid" 2>/dev/null
      breadcrumb launch-session "ocgo-executor" \
       "bili proxy unreachable -> opencode uncompressed (direct)"
     fi
    fi
    if [ -n "$borigin" ] && [ -f "${XDG_DATA_HOME:-$HOME/.local/share}/billion-context/ca/root-ca.pem" ]; then
     export HTTPS_PROXY="$borigin"
     export NODE_EXTRA_CA_CERTS="${XDG_DATA_HOME:-$HOME/.local/share}/billion-context/ca/root-ca.pem"
    elif [ -n "$borigin" ]; then
     breadcrumb launch-session "ocgo-executor" \
      "bili CA pem absent -> opencode uncompressed (direct)"
    fi
   else
    breadcrumb launch-session "ocgo-executor" \
     "bili absent -> opencode uncompressed (direct)"
   fi
   if [ -z "$borigin" ]; then
    # no wrap: strip any ambient proxy envs inherited from a
    # bili-wrapped parent (its proxy dies with the parent — a stale
    # HTTPS_PROXY here would break every direct session's fetch)
    unset HTTPS_PROXY NODE_EXTRA_CA_CERTS 2>/dev/null
   fi
   # Leg budgets (R5): this branch's binding pair is registered in
   # automation/config/leg-budgets.tsv as leg `opencode-agent`
   # (max-time 1800s = TIMEOUT_S, max-output 50000 = loadout token-limit).
   # The opencode-go gateway declares no per-call edge timeout; the session
   # wall-clock below is the enforced ceiling. The key rides a LITERAL
   # prefix assignment per provider (e1 finding #3, 2026-09-16): never an
   # env(1) argv word (its /proc cmdline is readable for env's pre-exec
   # lifetime) and never an export (the launcher's own environment stays
   # untouched for the other legs). Quoted array words are never re-parsed
   # as assignments, so only the prefix itself is an assignment.
   local -a oc_cmd=(timeout "$TIMEOUT_S" "$oc_bin" run
    --dir "$ROOT" --format json --agent "$oc_agent"
    -m "$oc_model_flag" --auto "$body")
   if [ "$oc_provider" = "kimi" ]; then
    KIMI_API_KEY="$oc_key" \
     OPENCODE_CONFIG="$AUTOMATION_ROOT/config/opencode/opencode.jsonc" \
     "${oc_cmd[@]}" >"$ROOT/$log.json" 2>&1
   elif [ "$oc_provider" = "zai" ]; then
    ZAI_API_KEY="$oc_key" \
     OPENCODE_CONFIG="$AUTOMATION_ROOT/config/opencode/opencode.jsonc" \
     "${oc_cmd[@]}" >"$ROOT/$log.json" 2>&1
   else
    OPENCODE_API_KEY="${OPENCODE_API_KEY:-$oc_key}" \
     OPENCODE_CONFIG="$AUTOMATION_ROOT/config/opencode/opencode.jsonc" \
     "${oc_cmd[@]}" >"$ROOT/$log.json" 2>&1
   fi
   oc_rc=$? # captured before the emitter masks $?
   if [ -n "$borigin" ]; then
    unset HTTPS_PROXY NODE_EXTRA_CA_CERTS
    [ -n "$bili_pid" ] && kill "$bili_pid" 2>/dev/null
   fi
   python3 "$AUTOMATION_ROOT/jobs/ocgo-attribution.py" \
    "$ROOT/$log.json" --plain "$ROOT/$log" \
    --burn "$AUTOMATION_ROOT/state/ocgo-agent-burn.tsv" \
    --telemetry "${HNGH_TELEMETRY_DB:-${HNGH_HOME_DIR:-$HOME/.hngh}/db/telemetry.db}" \
    "${emit_src[@]}" \
    >/dev/null 2>&1 || true
  else
   breadcrumb launch-session "ocgo-executor" \
    "opencode binary or opencode-model row absent -> omp"
   timeout "$TIMEOUT_S" "$omp_bin" -p --model "$SESSION_MODEL" \
    "$body" >"$ROOT/$log" 2>&1
  fi
 elif [ "$executor" = "jcode" ]; then
  # jcode executor (2026-09-14): the ONE branch with no key plumbing --
  # jcode holds its own auth in its config ([providers.zai] /
  # [providers.unsloth]); no bili MITM, no R2 emitter (the plain-text
  # log feeds the classifier directly). Order: SDK worker shim (plan
  # 2026-09-14-jcode-primary-harness step 2 decision: permission
  # events are the certificate bridge surface, not raw CLI spawn) ->
  # CLI `jcode run` -> omp, each leg taken only when the previous is
  # unavailable (shim/node/binary absent), each with a breadcrumb.
  # Proxy envs are dropped for the CLI child only (env -u): a stale
  # HTTPS_PROXY inherited from a bili-wrapped parent breaks every
  # fetch (same lesson as the opencode no-wrap path).
  # oc_ran stays 0: LAUNCH_RC is already the branch rc, and the lesson
  # loop stays an ocgo-attributed surface.
  local jc_provider jc_model_flag jc_model=() jw_rc=75 jc_bin jc_pace=""
  jc_provider="${JCODE_PROVIDER:-$(get_param jcode-provider zai)}"
  case "$jc_provider" in
  zai | unsloth) ;;
  *)
   breadcrumb launch-session "jcode-executor" \
    "unknown JCODE_PROVIDER '$jc_provider' -> zai"
   jc_provider="zai"
   ;;
  esac
  # spend pacing (2026-09-14 coexistence review gap #1): the zai leg
  # counts against the SAME subscription windows zai_chat spends
  # (zai-cap-5h-calls + zai-cap-week-calls, tightest wins). Blocked ->
  # omp fallback leg with a breadcrumb — identical contract to the
  # opencode branch. unsloth rides the local box: unpaced.
  if [ "$jc_provider" = "zai" ]; then
   declare -F zai_pace_blocked >/dev/null ||
    . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/model.sh"
   jc_pace="$(zai_pace_blocked || true)"
   [ -n "$jc_pace" ] && breadcrumb launch-session "jcode-executor" \
    "Z.AI pacer blocked (${jc_pace%% *}-window used ${jc_pace#* }) -> cli/omp fallback"
  fi
  jc_model_flag="$(get_param jcode-model '')"
  [ -n "$jc_model_flag" ] && jc_model=(-m "$jc_model_flag")
  if [ -z "$jc_pace" ] && [ -r "$ROOT/jcode/worker.mjs" ] && command -v node >/dev/null 2>&1 &&
   declare -F launch_jcode_worker >/dev/null; then
   local jc_prompt_file
   jc_prompt_file="$(mktemp "${TMPDIR:-/tmp}/hngh-jc-prompt.XXXXXX")"
   printf '%s' "$body" >"$jc_prompt_file"
   outcome_model="jcode/$jc_provider/sdk"
   JCODE_PROMPT_FILE="$jc_prompt_file" JCODE_LOG="$ROOT/$log" \
    timeout "$TIMEOUT_S" bash -c \
    ". '$AUTOMATION_ROOT/lib/launch-jcode.sh'; launch_jcode_worker"
   jw_rc=$?
   rm -f "$jc_prompt_file"
   [ "$jw_rc" -ne 0 ] && breadcrumb launch-session "jcode-executor" \
    "sdk worker rc=$jw_rc -> cli fallback"
  else
   breadcrumb launch-session "jcode-executor" \
    "sdk shim or node absent -> cli fallback"
  fi
  if [ "$jw_rc" -ne 0 ]; then
   jc_bin="$(command -v jcode || true)"
   if [ -n "$jc_bin" ] && [ -z "$jc_pace" ]; then
    outcome_model="jcode/$jc_provider${jc_model_flag:+/$jc_model_flag}"
    # provider-profile configs ([providers.<name>] in config.toml, e.g.
    # unsloth) must use --provider-profile: `-p <name>` only accepts the
    # built-in provider enum (first-session finding: the witnessed-cycle
    # runs of 2026-09-14 21:59/22:05 flash-failed on `invalid value
    # 'unsloth'`)
    if [ "$jc_provider" = "unsloth" ]; then
     env -u HTTPS_PROXY -u NODE_EXTRA_CA_CERTS \
      timeout "$TIMEOUT_S" "$jc_bin" run --provider-profile unsloth \
      "${jc_model[@]}" -C "$ROOT" --quiet "$body" >"$ROOT/$log" 2>&1
    else
     env -u HTTPS_PROXY -u NODE_EXTRA_CA_CERTS \
      timeout "$TIMEOUT_S" "$jc_bin" run -p "$jc_provider" \
      "${jc_model[@]}" -C "$ROOT" --quiet "$body" >"$ROOT/$log" 2>&1
    fi
   else
    breadcrumb launch-session "jcode-executor" "jcode binary absent -> omp"
    timeout "$TIMEOUT_S" "$omp_bin" -p --model "$SESSION_MODEL" \
     "$body" >"$ROOT/$log" 2>&1
   fi
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
 0) LAUNCH_DISPOSITION="complete" ;;
 *) LAUNCH_DISPOSITION="dead" ;;
 esac
 # cause classification for the disposition spine (lib/causes.sh bestiary);
 # a missing/unreadable log classifies as unclassified
 LAUNCH_CAUSE="$(classify_cause "$ROOT/$log" "$LAUNCH_RC")"
 # P4: cause=unknown is banned on transitions — a dying session whose
 # log matches no class is named unclassified and rides the spine as
 # one deduped report row (window 7d) so watchers see the gap.
 if [ "$LAUNCH_RC" -ne 0 ] && [ "$LAUNCH_CAUSE" = unclassified ]; then
  rq="${HNGH_REPORT_QUEUE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/scripts/report-queue}"
  [ -x "$rq" ] && "$rq" --add alert \
   --identity "cause-unclassified:$slug" --window 604800 \
   "session $slug died rc=$LAUNCH_RC with no matching failure class; log tail matched nothing in the bestiary" \
   >/dev/null 2>&1 || true
 fi
 # self-steering loop: one lesson line per opencode OR jcode session
 # (after classification — the lesson cites the cause class). Happy-path
 # skip: a clean exit (rc=0) classified unclassified matched no failure
 # keyword — recording it would pollute the file with "you failed" noise
 # on every success (first-session finding 2026-09-11). jcode parity
 # (coexistence review gap #3, 2026-09-14): the executor column already
 # reads the tail at launch; the append side now covers jcode-attributed
 # sessions too, keyed on the executor that actually ran.
 if { [ "$oc_ran" = 1 ] ||
  [ "${outcome_model:-}" = "jcode/${jc_provider:-}/${jc_model_flag:-}/sdk" ] ||
  [ "${outcome_model:-}" = "jcode/${jc_provider:-}${jc_model_flag:+/${jc_model_flag:-}}" ]; } &&
  { [ "$LAUNCH_RC" -ne 0 ] || [ "$LAUNCH_CAUSE" != unclassified ]; }; then
  append_ocgo_lesson "$LAUNCH_CAUSE"
 fi
 # budget row carries the cost class (plan 2026-09-10-cost-tiering
 # step 1): `class=T1|T2|T3` appended to the session-run row, plus
 # model+source quota-leg attribution (rule quota-leg-attribution:
 # SimDesign/QueueDeps coordinator rows carried neither, so their
 # spend was untrackable).
 printf '%s | overnight|%s | session-run | class=%s | model=%s | source=%s\n' \
  "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$slug" "$sclass" \
  "${outcome_model:-unknown}" "${SESSION_SOURCE:-unknown}" >>"$ROOT/logs/budget.md"
 OMP_BRIDGE_STORE="$bridge_store" "$bridge_bin" --run-end "$run_id" \
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
