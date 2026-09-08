#!/usr/bin/env bash
# resume-pass — the boot/cold-resume pass. The operator currently
# hand-prompts session starts and restarts; this pass makes the recovery
# moment machinery: it reads the recovery surface (agent-handoffs.md tail,
# STATE.md crumbs, dashboard/operator-items.json, kernel plan ledger) and
# writes logs/resume-<date>.md — dead sessions with cause, plans held
# overnight, beats that did not fire while the box was down, open operator
# items — and dispositions what is machine-dispositionable:
#   - held plans whose designs landed: re-proposal happens by itself on the
#     next accept-plans run (scripts/accept-plans.py, mounted every
#     overnight tick) — the log only notes it;
#   - stale parked operator items: counted, left for the operator;
#   - missed day-tier beats: cadence-tick has NO catch-up mechanism by
#     design (no scheduler is invented here) — they are listed as
#     "run these next" with the exact one-line command.
# Dead-session respawns are NOT done here: jobs/agent-respawn.sh owns that
# (bounded, guard-laden) and runs on the 30m tier.
#
# Modes:
#   --boot   operator login / @reboot-style manual hook (one-liner:
#            bash "$AUTOMATION_ROOT"/jobs/resume-pass.sh --boot
#            — no systemd unit; see docs/NIGHT-OPS.md resume protocol)
#   --sweep  cadence/day/15-resume-pass.sh wrapper; runs only when the
#            last non-tick STATE.md crumb is older than resume-gap-hours
#            (the machine was down)
# Fail-closed: exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/causes.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

# hermetic test seam: re-root runtime artifacts without touching lib
# resolution; the kernel ledger follows HNGH_KERNEL.
AUTOMATION_ROOT="${RESUME_ROOT:-$AUTOMATION_ROOT}"
STATE_FILE="$AUTOMATION_ROOT/STATE.md" # breadcrumbs.sh pinned it at source

KERNEL="${HNGH_KERNEL:-${HNGH_HOME:-$HOME/Projects/etc/hngh}}"
MODE="${1:---sweep}"
case "$MODE" in
--boot | --sweep) ;;
*)
  echo "usage: resume-pass.sh [--boot|--sweep]" >&2
  exit 2
  ;;
esac
GAP_HOURS="${RESUME_GAP_HOURS:-$(get_param resume-gap-hours 6)}"
LOG="logs/resume-$(date -u +%F).md"

# age of the last crumb NOT written by the tick machinery itself
# (cadence-tick crumbs fire every tier tick, so they say nothing about
# downtime; the freshest real job crumb does — healthy ceiling ~1h)
last_crumb_age_h() {
  local ts
  ts="$(awk -F' \\| ' '$2 != "cadence-tick" {ts = $1} END {print ts}' \
    "$AUTOMATION_ROOT/STATE.md" 2>/dev/null)"
  [ -n "$ts" ] || {
    printf 999
    return 0
  }
  local age_s
  age_s=$(($(date -u +%s) - $(date -u -d "$ts" +%s 2>/dev/null || echo 0)))
  [ "$age_s" -lt 0 ] && age_s=0
  printf '%d' $((age_s / 3600))
}

DOWN_H="${DOWN_H:-$(last_crumb_age_h)}"
if [ "$MODE" = "--sweep" ] && [ "$DOWN_H" -lt "$GAP_HOURS" ]; then
  breadcrumb "resume-pass" "sweep-skip" "last crumb ${DOWN_H}h old < gap ${GAP_HOURS}h; machine was up"
  exit 0
fi

mkdir -p "$AUTOMATION_ROOT/logs"
OUT="$AUTOMATION_ROOT/$LOG"
{
  printf '# cold-resume pass — %s (mode=%s, down-window ~%sh)\n\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$MODE" "$DOWN_H"

  # --- dead sessions with cause -----------------------------------------
  printf '## Dead sessions (cause column, lib/causes.sh bestiary)\n\n'
  local_rows="$(awk -F' \\| ' '
    ($1 == "overnight-lead" && $4 ~ / dead /) || ($1 == "session-drop") {
      if (match($4, / cause=[A-Za-z-]+/)) {
        printf "- %s | %s | %s | %s\n", $1, $2, $3, substr($4, RSTART + 1)
      } else {
        printf "- %s | %s | %s | (no cause column — pre-2026-09-06 row, not respawnable)\n", $1, $2, $3, $4
      }
    }' "$AUTOMATION_ROOT/agent-handoffs.md" 2>/dev/null | tail -n 25)"
  if [ -n "$local_rows" ]; then
    printf '%s\n' "$local_rows"
    printf '\nDisposition: transient causes (bad-execution, model-outage) are the\n30m respawn executor'"'"'s input (jobs/agent-respawn.sh, four guards);\nmissing-knowledge/missing-design already seeded research subjects;\nmissing-authority waits on the operator packet.\n'
  else
    printf 'none with a cause column.\n'
  fi

  # --- plans held / parked overnight ------------------------------------
  printf '\n## Plans held overnight (kernel plan ledger)\n\n'
  held=0
  for f in "$KERNEL"/docs/project/plans/*.plan.md; do
    [ -f "$f" ] || continue
    st="$(sed -n 's/.*status=\([a-z]*\).*/\1/p' "$f" | head -1)"
    case "$st" in
    proposed)
      held=$((held + 1))
      printf -- '- %s: status=proposed — re-proposed automatically; accept-plans accepts it on the next overnight tick when both repos'"'"' gates are green\n' "$(basename "$f")"
      ;;
    drafted)
      held=$((held + 1))
      printf -- '- %s: status=drafted — awaits operator review (never machine-executed)\n' "$(basename "$f")"
      ;;
    esac
  done
  [ "$held" -gt 0 ] || printf 'none held.\n'

  # --- beats that did not fire while down --------------------------------
  printf '\n## Beats that did not fire while down (day tier; no catch-up scheduler exists)\n\n'
  timing="$AUTOMATION_ROOT/logs/drop-in-timing.log"
  missed=0
  for f in "$AUTOMATION_ROOT"/cadence/day/*.sh; do
    [ -f "$f" ] || continue
    name="$(basename "$f")"
    last="$(awk -F'|' -v n="$name" '$2 == n {t = $1} END {print t}' \
      "$timing" 2>/dev/null)"
    if [ -z "$last" ] || [ $(($(date -u +%s) - $(date -u -d "$last" +%s 2>/dev/null || echo 0))) \
      -gt 86400 ]; then
      missed=$((missed + 1))
      printf -- '- %s (last run: %s)\n' "$name" "${last:-never}"
    fi
  done
  if [ "$missed" -gt 0 ]; then
    printf '\nRun these next (the existing one-line catch-up, no scheduler invented):\n\n    cd "$AUTOMATION_ROOT" && make adhoc TIER=day\n\n'
  else
    printf 'none — every day-tier beat fired within the last 24h.\n'
  fi

  # --- open operator items ----------------------------------------------
  printf '## Open operator items (dashboard/operator-items.json)\n\n'
  python3 - "$AUTOMATION_ROOT/dashboard/operator-items.json" <<'PY'
import json, sys, time
try:
    items = json.load(open(sys.argv[1])).get("items", [])
except Exception:
    items = []
now = time.time()
def age(s):
    try:
        return now - time.mktime(time.strptime(s, "%Y-%m-%dT%H:%M:%SZ"))
    except Exception:
        return 0
open_items = [i for i in items if i.get("status") == "open"]
stale = [i for i in open_items if age(i.get("first_seen", "")) > 48 * 3600]
print(f"{len(open_items)} open, {len(stale)} stale (>48h since first_seen).")
for i in open_items[:10]:
    mark = " [stale]" if i in stale else ""
    print(f"- {i.get('id','?')}{mark}: {i.get('text','')[:140]}")
PY
  printf '\nDisposition: open items are operator-owned; the machine does not\nresolve them (parked = parked).\n'
} >"$OUT"

breadcrumb "resume-pass" "$MODE" \
  "down~${DOWN_H}h dead-rows noted, held-plans=$held, missed-day-beats=$missed -> $LOG"
exit 0
