#!/usr/bin/env bash
# lesson-harvest.sh — the observe→reflect→improve routine (multi-cadence).
#
# Broader than "check and learn": every agent run leaves behind transferable
# experience. This routine observes at three beats and folds what transfers
# into the guardrails/design so the next run starts smarter:
#   1. RUN-COMPLETION (`lesson-harvest run`) — call when any agent run
#      closes (bridge seam / watchdog on session-drop): scan the just-
#      closed session + handoff ledger for NEW death signals since the
#      last harvest; the freshest lesson surfaces immediately.
#   2. PERIODIC (`lesson-harvest periodic`) — cheap, mid-run, on the
#      5m oversight tick: any NEW record / NEW handoff line is a
#      lesson candidate; surfaced as a crumb.
#   3. DAILY (`lesson-harvest daily`, default) — consolidate: scan all
#      new records + handoffs + guardrail cross-ref into
#      lessons-<date>.md, the digest for operator review.
#
# Idempotent + deterministic: mtime marker (.lesson-harvest-last) + line
# marker (.lesson-harvest-handoffs) pin what was seen; re-runs never
# duplicate. Fail-open: read errors are crumbs, never crashes.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export AUTOMATION_ROOT="$ROOT"
# shellcheck disable=SC1091
. "$ROOT/lib/breadcrumbs.sh" 2>/dev/null || true

HNGH_REPO="${HNGH_REPO:-/home/bricker/Projects/etc/hngh}"
RECORDS="$HNGH_REPO/docs/records"
LESSONS_DIR="$HNGH_REPO/docs/project"
MARKER="${LESSON_HARVEST_MARKER:-$ROOT/.lesson-harvest-last}"
HANDOFFS="${WATCHDOG_HANDOFFS:-$ROOT/agent-handoffs.md}"
GUARDRAILS="$HNGH_REPO/docs/project/agent-guardrails.md"

MODE="${1:-daily}"
today=$(date +%F)
last=0
[ -f "$MARKER" ] && last=$(cat "$MARKER" 2>/dev/null || echo 0)

# --- new records (mtime > last harvest) ------------------------------------
new_records=""
new_count=0
for r in "$RECORDS"/*.md; do
  [ -f "$r" ] || continue
  mt=$(stat -c %Y "$r" 2>/dev/null || echo 0)
  if [ "$mt" -gt "$last" ]; then
    new_records="$new_records $r"
    new_count=$((new_count + 1))
  fi
done

# --- new handoff lines since last run-complete -----------------------------
handoff_seen=0
[ -f "$HANDOFFS" ] && handoff_seen=$(wc -l <"$HANDOFFS" 2>/dev/null || echo 0)
handoff_last=0
[ -f "$ROOT/.lesson-harvest-handoffs" ] && handoff_last=$(cat "$ROOT/.lesson-harvest-handoffs" 2>/dev/null || echo 0)
handoff_new=$((handoff_seen - handoff_last))
[ "$handoff_new" -lt 0 ] && handoff_new=0

found=""
if [ "$new_count" -gt 0 ]; then
  # shellcheck disable=SC2086
  found=$(grep -lEi "lesson|provenance|failure class|class:|guardrail|roguelike" $new_records 2>/dev/null | head -20)
fi

advance_markers() {
  echo "$handoff_seen" >"$ROOT/.lesson-harvest-handoffs" 2>/dev/null || true
  newest=0
  for r in "$RECORDS"/*.md; do
    [ -f "$r" ] || continue
    mt=$(stat -c %Y "$r" 2>/dev/null || echo 0)
    [ "$mt" -gt "$newest" ] && newest=$mt
  done
  echo "$newest" >"$MARKER" 2>/dev/null || true
}

case "$MODE" in
run)
  # run-completion: surface the freshest death-lessons immediately
  if [ "$handoff_new" -gt 0 ]; then
    tail -n "$handoff_new" "$HANDOFFS" 2>/dev/null | while IFS= read -r line; do
      breadcrumb "lesson-harvest" "run-lesson" "$line"
    done
  fi
  advance_markers
  ;;
periodic)
  # mid-run cheap: new handoff or new record = candidate, crumb only
  if [ "$handoff_new" -gt 0 ]; then
    breadcrumb "lesson-harvest" "candidate" "$handoff_new new handoff line(s)"
  fi
  if [ "$new_count" -gt 0 ]; then
    breadcrumb "lesson-harvest" "candidate" "$new_count new record(s)"
  fi
  advance_markers
  ;;
daily)
  digest="$LESSONS_DIR/lessons-$today.md"
  if [ -n "$found" ] || [ "$handoff_new" -gt 0 ]; then
    # MERGE semantics, never clobber (2026-08-27: overwrote the curated
    # lessons-2026-08-26.md with a stub): rewrite only our own harvest
    # files (they carry the harvest marker); a day-file with any other
    # content is refused, the operator owns it.
    if [ -f "$digest" ] && ! grep -q "Harvested by lesson-harvest.sh" "$digest"; then
      breadcrumb "lesson-harvest" "refuse" \
        "$digest has non-harvest content; not overwritten"
    elif [ ! -f "$digest" ] || [ "$new_count" -gt 0 ] || [ "$handoff_new" -gt 0 ]; then
      {
        echo "# Lessons — $today (automatic harvest)"
        echo
        echo "Harvested by lesson-harvest.sh (observe→reflect→improve) at $(date -u +%H:%MZ)."
        echo
        echo "## Sources scanned"
        echo "- Records newer than last harvest: $new_count"
        echo "- Watchdog handoff ledger: $handoff_seen lines ($handoff_new new)"
        echo "- Guardrails: $GUARDRAILS"
        echo
        if [ -n "$found" ]; then
          echo "## New lesson-bearing records"
          for f in $found; do echo "- $(basename "$f")"; done
        fi
        if [ "$handoff_new" -gt 0 ]; then
          echo
          echo "## New watchdog session-drops"
          tail -n "$handoff_new" "$HANDOFFS" 2>/dev/null | sed 's/^/- /'
        fi
        echo
        echo "## Guardrail cross-check"
        echo "Does any new record extend a guardrail class or add a new one?"
        echo "Fold it into agent-guardrails.md — that is the improvement leg."
      } >"$digest"
      breadcrumb "lesson-harvest" "digest" "wrote $digest ($new_count records, $handoff_new new handoffs)"
    else
      breadcrumb "lesson-harvest" "skip" "digest exists, nothing newer"
    fi
  else
    breadcrumb "lesson-harvest" "nothing-new" "no new lessons since last harvest"
  fi
  advance_markers
  ;;
*)
  echo "usage: lesson-harvest [daily|run|periodic]" >&2
  exit 2
  ;;
esac
exit 0
