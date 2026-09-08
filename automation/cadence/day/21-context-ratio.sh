#!/usr/bin/env bash
# 21-context-ratio — day-tier wrapper: the context manager's weekly vital
# sign (hngh docs/design/context-manager.md, measurement loop).
#
# Producer: jobs/context-ratio.py — model-free, deterministic. It reads
# the last 7 days of telemetry kind=session-cost rows (tokens_in/out per
# session, captured hourly by cadence/hour/25-session-cost.sh) and files
# ONE identity-deduped report-queue progress row (identity
# context-ratio:<date>): sessions counted, median in:out ratio paid vs
# local, worst session, trend vs the previous row. Targets: paid <=10:1,
# local <=50:1, measured weekly.
#
# Fail-closed: exit 0 always; a failed run is a breadcrumb, never a crash.
#
# usage: cadence/day/21-context-ratio.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

out="$(python3 "$AUTOMATION_ROOT/jobs/context-ratio.py" 2>&1)" || true
breadcrumb "$JOB_NAME" "context-ratio" "${out:-producer produced no output}"
exit 0
