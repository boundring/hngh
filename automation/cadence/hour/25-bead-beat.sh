#!/usr/bin/env bash
# 25-bead-beat — hour-tier bead intake (plan 2026-09-22-federal-branches-occupancy
# step 3): polls bd for open beads and drives ng/cadence.beat — Jev triage,
# deferred/attempt caps and dispatch ceilings are internal to the beat. The
# beat emits judgment records only (slice.proposed / bead.close / escalation.filed);
# work dispatch itself stays gated (dispatch-day-max, legs). Escalations
# surface to the operator ledger (scripts/report-queue) in the same beat —
# SLA: reports.md row, identity escalation:<bead>:<reason>, 7-day window,
# re-fires bump the same row. Halt condition is internal to the beat: the
# per-bead attempt cap (cadence.py STATE.exhausted) drops a bead from the
# loop after one final attempts-exhausted escalation. Drop-in fails
# closed: exit 0 always, beat outcome in the breadcrumb.
#
# usage: cadence/hour/25-bead-beat.sh   (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

out="$(python3 "$AUTOMATION_ROOT/ng/cadence.py" 2>&1)" || true
printf '%s\n' "$out" | python3 "$AUTOMATION_ROOT/ng/surface_escalations.py" \
    "$(cd "$AUTOMATION_ROOT/.." && pwd)/scripts/report-queue" >/dev/null 2>&1 || true
breadcrumb "$JOB_NAME" "bead-beat" "${out:-beat produced no output}"
breadcrumb "$JOB_NAME" "escalations-surfaced" "routed to reports.md where filed"
exit 0
