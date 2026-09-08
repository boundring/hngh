#!/usr/bin/env bash
# 10-bench-fresh — day-tier freshness hook for the local-model cost lever.
# scripts/overnight-cycle.sh runs delegated sessions on the best local
# model ONLY when a bench result is fresh (<24h); otherwise it pays.
# The 01:10 systemd timer owns the bench; this catch-up re-runs
# jobs/model-bench.sh when no result landed in the last 24h (bench is
# fail-closed: a failed run just leaves the paid fallback in charge).
#
# usage: cadence/day/10-bench-fresh.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

newest="$(ls -t "$AUTOMATION_ROOT"/stats/model-bench-*.jsonl 2>/dev/null | head -n1)"
age="$(($(date +%s) - $(stat -c %Y "$newest" 2>/dev/null || echo 0)))"
if [ "$age" -gt 86400 ]; then
  breadcrumb "$JOB_NAME" "bench-fresh" "stale ($age s) — re-running jobs/model-bench.sh"
  bash "$AUTOMATION_ROOT/jobs/model-bench.sh" || true
else
  breadcrumb "$JOB_NAME" "bench-fresh" "fresh: $(basename "$newest" 2>/dev/null || echo none) ($age s)"
fi
exit 0
