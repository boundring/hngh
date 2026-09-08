#!/usr/bin/env bash
# 25-session-cost — hour-tier capture producer: one telemetry row per
# finished omp session (spec: ledger-and-records-spec.md §3). The producer
# itself is fail-closed (exit 0 always); this drop-in only breadcrumbs.
#
# usage: cadence/hour/25-session-cost.sh   (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

out="$(python3 "$AUTOMATION_ROOT/jobs/session-cost.py" 2>&1)" || true
breadcrumb "$JOB_NAME" "session-cost" "${out:-producer produced no output}"
exit 0
