#!/usr/bin/env bash
# 02-bench-trigger — week-tier mount of the event-driven bench triggers
# (plan docs/project/plans/2026-09-10-bench-trigger-lane.plan.md: benchmarks
# become occasional and event-driven, never nightly). Runs both verbs; each
# defers or fires with its own breadcrumb and files an operator-item when a
# bench actually runs. The only bench path after the lane's step 3.
# usage: cadence/week/02-bench-trigger.sh   (via cadence-tick.sh TIER=week)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

breadcrumb "$JOB_NAME" "bench-trigger" "week tick: evaluating new-model + recalibrate verbs"
bash "$AUTOMATION_ROOT/jobs/bench-trigger.sh" new-model-check || true
bash "$AUTOMATION_ROOT/jobs/bench-trigger.sh" recalibrate-check || true
exit 0
