#!/usr/bin/env bash
# 10-bench-fresh — day-tier bench staleness NOTE (catch-up retired).
# The 2026-09-10 bench-trigger lane retired the nightly full-fleet catch-up:
# benchmarks are event-driven now (cadence/week/02-bench-trigger.sh, plan
# docs/project/plans/2026-09-10-bench-trigger-lane.plan.md; the 01:10 timer
# disable is director-executed). This drop-in only notes staleness —
# re-benching belongs to the recalibrate verb.
# usage: cadence/day/10-bench-fresh.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

newest="$(ls -t "$AUTOMATION_ROOT"/stats/model-bench-*.jsonl 2>/dev/null | head -n1)"
age="$(($(date +%s) - $(stat -c %Y "$newest" 2>/dev/null || echo 0)))"
breadcrumb "$JOB_NAME" "bench-fresh" \
  "staleness note only (nightly catch-up retired): newest $(basename "$newest" 2>/dev/null || echo none) ${age}s old — recalibrate-check owns re-benching"
exit 0
