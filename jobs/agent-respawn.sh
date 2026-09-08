#!/usr/bin/env bash
# agent-respawn — bounded watchdog respawn executor (roguelike
# death-and-replacement; hngh docs/project/roguelike-agentic.md,
# brief schema docs/research/2026-08-30-handoff-brief-schema.md).
#
# Input: agent-handoffs.md dead rows — `overnight-lead ... rc=N dead ...
# cause=<c>` or watchdog `session-drop ... cause=<c>` — with no later
# disposition row (`respawn` / `respawn-refused`) for that session. Every
# dead row gets EXACTLY ONE disposition row, appended here; the ledger row
# is the record, logs/respawn-<date>.md the human log.
#
# STRICTLY bounded — respawning delegated sessions spends real money:
#   guard 1 steer-don't-kill: only transient causes respawn (bad-execution,
#     model-outage). missing-knowledge/missing-design -> the research
#     demand is queued via lib/causes.sh append_research_subject and the
#     death is never respawned; missing-authority -> the operator packet
#     already exists via alerts, never respawned.
#   guard 2 loop-break: never respawn the same mission more than once per
#     UTC day, and never a mission with >= respawn-max-attempts previous
#     deaths (repeated death without brief change is the anti-pattern
#     that killed operator trust — agent-handoffs.md 2026-09-05 x4). The
#     brief ALWAYS carries the death cause + one corrective instruction.
#   guard 3 budget: respawn-daily-cap respawns per UTC day (default 1),
#     plus the shared delegated-session ledger logs/budget.md against
#     OVERNIGHT_MAX_SESSIONS_DAY — the same count overnight-cycle enforces
#     (launch_session appends to that same ledger).
#   guard 4 authority: launch ONLY via lib/launch-session.sh — the exact
#     gated path extracted from scripts/overnight-cycle.sh. No second
#     launcher exists or may be added here.
#
# Model: SESSION_MODEL env > OVERNIGHT_PAID_MODEL > zai/glm-5.3 (the same
# paid fallback overnight-cycle uses; respawns are cap-1/day by default).
#
# Mounted from the 30m tier via cadence/30m/45-agent-respawn.sh.
# Fail-closed: every path exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/causes.sh"
. "$AUTOMATION_ROOT/lib/params.sh"
. "$AUTOMATION_ROOT/lib/launch-session.sh"

# hermetic test seam: re-root runtime artifacts (handoffs, STATE, logs,
# prompts, cadence-params.tsv) without touching lib resolution.
AUTOMATION_ROOT="${RESPAWN_ROOT:-$AUTOMATION_ROOT}"
ROOT="$AUTOMATION_ROOT"
STATE_FILE="$AUTOMATION_ROOT/STATE.md" # breadcrumbs.sh pinned it at source

HANDOFFS="${RESPAWN_HANDOFFS:-$AUTOMATION_ROOT/agent-handoffs.md}"
BUDGET_LEDGER="$AUTOMATION_ROOT/logs/budget.md"
LOG="logs/respawn-$(date -u +%F).md"
MAX_ATTEMPTS="$(get_param respawn-max-attempts 2)"
DAILY_CAP="$(get_param respawn-daily-cap 1)"
MAX_SESSIONS_DAY="${OVERNIGHT_MAX_SESSIONS_DAY:-4}"
TIMEOUT_S="${OVERNIGHT_TIMEOUT:-1800}"
STORE="$AUTOMATION_ROOT/snapshots/respawn-$(date +%Y%m%dT%H%M%S)-$$/"
SESSION_MODEL="${SESSION_MODEL:-${OVERNIGHT_PAID_MODEL:-zai/glm-5.3}}"

log_line() { # event detail — append to today's respawn log
  printf '%s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$1" "$2" \
    >>"$AUTOMATION_ROOT/$LOG"
}

# dead rows -> kind<TAB>ts<TAB>slug<TAB>sessid<TAB>cause<TAB>evidence
# (chronological, ledger order; cause column is present since 2026-09-06,
# earlier rows carry no cause= and are skipped — no cause, no respawn).
dead_rows() {
  awk -F' \\| ' '
    ($1 == "overnight-lead" && $4 ~ / dead /) ||
    ($1 == "session-drop") {
      cause = ""
      if (match($4, / cause=[A-Za-z-]+/)) {
        cause = substr($4, RSTART + 7, RLENGTH - 7)
        ev = substr($4, 1, RSTART - 1)
      } else next
      slug = $3; sub(/\|.*/, "", slug)
      sess = $3; sub(/^[^|]*\|/, "", sess)
      sub(/^[A-Za-z]+: /, "", ev)   # watchdog "class: " prefix off
      printf "%s\t%s\t%s\t%s\t%s\t%.140s\n", $1, $2, slug, sess, cause, ev
    }' "$HANDOFFS" 2>/dev/null
}

# corrective instruction — keyed by cause + evidence; single line
corrective() { # cause evidence
  case "$1:$2" in
  bad-execution:*timeout* | bad-execution:*timed*)
    printf 'run ONE smaller verified step and finish well inside half the prior time budget; checkpoint progress after each step'
    ;;
  bad-execution:*)
    printf 'reduce scope to the single smallest verified increment and stop after it lands; do not chain steps'
    ;;
  model-outage:*)
    printf 'probe model health first; on failure switch to the paid fallback instead of retrying a dead endpoint'
    ;;
  *)
    printf 'restate the objective as one concrete bounded step and verify it before anything else'
    ;;
  esac
}

objective_for() { # slug cause corrective
  printf 'Respawn mission %s after a transient death (cause=%s). Corrective instruction (binding): %s' \
    "$1" "$2" "$3"
}

write_brief() { # slug sessid cause evidence corrective outfile
  local slug="$1" sess="$2" cause="$3" ev="$4" fix="$5" out="$6"
  # brief cap: the whole brief stays under ~1.5KB — it is one bounded
  # prompt, not a dossier. The context pack is pointed at, never inlined;
  # lib/launch-session.sh regenerates it fresh at launch (same path).
  {
    printf '# failure-informed respawn brief — %s\n\n' "$slug"
    printf 'objective: %s\n' "$(objective_for "$slug" "$cause" "$fix")"
    printf 'lane: %s\n' "$slug"
    printf 'budget-spent: not established\n'
    printf 'landed: not established\n'
    printf 'uncommitted: not established\n'
    printf 'failure-mode: %s (%.140s)\n' "$cause" "$ev"
    printf 'correction: %s\n' "$fix"
    # reorientation block (hngh docs/design/context-manager.md): the
    # reborn session orients from the same pack file the dead one used —
    # pack pointer + death cause + corrective, nothing more.
    printf 'reorientation: read the context pack at %s (regenerated fresh at launch) before re-deriving any repo fact; you were respawned after cause=%s — apply the correction above first\n' \
      "$AUTOMATION_ROOT/prompts/overnight/respawn-$slug.context.txt" "$cause"
    printf 'replacement: jobs/agent-respawn.sh %s (replaces %s)\n\n' \
      "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$sess"
    cat <<'RULE'
## Autonomy rule (binding for this session)

Governance — certificates and green gates — is the only barrier. Do not
wait for or ask for human approval. hngh-automation commits are free.
hngh changes land via the certificate ceremony ONLY with a green
`make test`. Never touch provider or credential configuration, systemd
unit state, or secrets. If blocked, write what blocked you into the
ledger and stop; other work always exists.
RULE
  } >"$out"
}

register() { # kind slug sessid detail — one disposition row per dead row
  printf '%s | %s | %s|%s | %s\n' \
    "$1" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$2" "$3" "$4" >>"$HANDOFFS"
}

main() {
  [ -f "$HANDOFFS" ] || return 0
  local count_today
  # guard 3 (day cap): respawns already executed today
  count_today="$(grep -c "^respawn | $(date -u +%Y-%m-%d)" "$HANDOFFS" 2>/dev/null || true)"
  local now_day
  now_day="$(date -u +%Y-%m-%d)"
  local budget_today
  budget_today="$(grep "overnight|" "$BUDGET_LEDGER" 2>/dev/null |
    grep -c "$now_day" || true)"

  local kind ts slug sess cause ev fix prev
  local -A deaths=()
  while IFS=$'\t' read -r kind ts slug sess cause ev; do
    [ -n "${slug:-}" ] || continue
    prev="${deaths[$slug]:-0}"
    deaths[$slug]=$((prev + 1))

    # already dispositioned? (exactly one disposition row per dead row)
    if grep -E "^respawn(-refused)? \| " "$HANDOFFS" 2>/dev/null |
      grep -qF " | $slug|$sess | "; then
      continue
    fi

    # --- guard 1: steer-don't-kill --------------------------------------
    case "$cause" in
    bad-execution | model-outage) ;;
    missing-knowledge | missing-design)
      append_research_subject "$slug" "What $(
        [ "$cause" = missing-design ] && printf design || printf knowledge
      ) was missing for $slug?"
      register respawn-refused "$slug" "$sess" \
        "reason=$cause-not-respawnable research-subject-queued cause=$cause"
      log_line "refused" "$slug|$sess cause=$cause -> research subject queued (never respawn)"
      breadcrumb "agent-respawn" "refused" "$slug|$sess cause=$cause research-queued"
      continue
      ;;
    missing-authority)
      register respawn-refused "$slug" "$sess" \
        "reason=missing-authority-operator-packet-exists cause=$cause"
      log_line "refused" "$slug|$sess cause=$cause -> operator packet exists (never respawn)"
      breadcrumb "agent-respawn" "refused" "$slug|$sess cause=$cause operator"
      continue
      ;;
    *)
      register respawn-refused "$slug" "$sess" \
        "reason=non-transient-cause cause=$cause"
      log_line "refused" "$slug|$sess cause=$cause -> non-transient, no respawn"
      breadcrumb "agent-respawn" "refused" "$slug|$sess cause=$cause non-transient"
      continue
      ;;
    esac

    # --- guard 2: loop-break --------------------------------------------
    if [ "$prev" -ge "$MAX_ATTEMPTS" ]; then
      register respawn-refused "$slug" "$sess" \
        "reason=attempts-exhausted previous-deaths=$prev max=$MAX_ATTEMPTS cause=$cause"
      log_line "refused" \
        "$slug|$sess cause=$cause -> $prev previous deaths >= max $MAX_ATTEMPTS; no respawn"
      breadcrumb "agent-respawn" "refused" "$slug|$sess attempts-exhausted prev=$prev"
      continue
    fi
    if grep -qE "^respawn \| $now_day" "$HANDOFFS" 2>/dev/null &&
      grep "^respawn | $now_day" "$HANDOFFS" 2>/dev/null |
      grep -qF "| $slug|"; then
      register respawn-refused "$slug" "$sess" \
        "reason=mission-already-respawned-today cause=$cause"
      log_line "refused" "$slug|$sess -> already respawned today; once per mission per day"
      breadcrumb "agent-respawn" "refused" "$slug|$sess daily-once"
      continue
    fi

    # --- guard 3: budget -------------------------------------------------
    if [ "$count_today" -ge "$DAILY_CAP" ]; then
      register respawn-refused "$slug" "$sess" \
        "reason=daily-cap respawns-today=$count_today cap=$DAILY_CAP cause=$cause"
      log_line "refused" \
        "$slug|$sess -> respawn daily cap reached ($count_today >= $DAILY_CAP)"
      breadcrumb "agent-respawn" "refused" "$slug|$sess daily-cap"
      continue
    fi
    if [ "${budget_today:-0}" -ge "$MAX_SESSIONS_DAY" ]; then
      register respawn-refused "$slug" "$sess" \
        "reason=day-budget-spent sessions-today=$budget_today cap=$MAX_SESSIONS_DAY cause=$cause"
      log_line "refused" \
        "$slug|$sess -> day budget spent ($budget_today >= $MAX_SESSIONS_DAY sessions)"
      breadcrumb "agent-respawn" "refused" "$slug|$sess budget-spent"
      continue
    fi

    # --- brief + gated launch (guard 4: the one launcher) ----------------
    fix="$(corrective "$cause" "$ev")"
    mkdir -p "$AUTOMATION_ROOT/prompts/respawn" "$AUTOMATION_ROOT/logs"
    brief="prompts/respawn/$slug-$(date +%Y%m%dT%H%M%S).md"
    write_brief "$slug" "$sess" "$cause" "$ev" "$fix" "$AUTOMATION_ROOT/$brief"
    log_line "brief" "$brief (cause=$cause)"
    launch_session "respawn-$slug" "$(objective_for "$slug" "$cause" "$fix")" \
      "$AUTOMATION_ROOT/$brief"
    if [ "$LAUNCH_RC" -eq 75 ]; then
      register respawn-refused "$slug" "$sess" \
        "reason=bridge-refused cause=$cause msg=${LAUNCH_BRIDGE_MSG:0:120}"
      log_line "refused" "$slug|$sess -> bridge refused: $LAUNCH_BRIDGE_MSG"
      breadcrumb "agent-respawn" "refused" "$slug|$sess bridge-refused"
      continue
    fi
    register respawn "$slug" "$sess" \
      "prev-cause=$cause brief=$brief run=$LAUNCH_RUN_ID rc=$LAUNCH_RC disposition=$LAUNCH_DISPOSITION"
    log_line "respawn" \
      "$slug|$sess -> run=$LAUNCH_RUN_ID rc=$LAUNCH_RC $LAUNCH_DISPOSITION cause=$LAUNCH_CAUSE brief=$brief model=$SESSION_MODEL"
    breadcrumb "agent-respawn" "respawn" \
      "$slug|$sess run=$LAUNCH_RUN_ID rc=$LAUNCH_RC cause=$cause brief=$brief"
    count_today=$((count_today + 1))
    budget_today=$((budget_today + 1))
  done < <(dead_rows)
  return 0
}

main
exit 0
