#!/usr/bin/env bash
# cadence/hour/42-dashboard-introspect — the dashboard metacyclic feedback
# loop (docs/design/dashboard-intent.md, docs/records/
# 2026-09-27-dashboard-metacycle.md): evaluates the operator-intent probes
# at file/JSON level, files unmet gaps as research arcs (the 33-research-
# beat chews them like any other subject), alerts on met->unmet
# regressions via the report-queue (the 10-router-feed consumes alerts),
# and writes a grade row + breadcrumb every hour. Thin wrapper pattern of
# 54-feedback-ingest.sh -> jobs/dashboard-introspect.py. No stamp gate:
# the hour tier already paces this; pacing inside is the
# introspect-min-gap-hours arc-filing window. Fail-open, exit 0 always.
root="$(cd "$(dirname "$0")/../.." && pwd)"
summary="$(python3 "$root/jobs/dashboard-introspect.py" 2>/dev/null || true)"
. "$root/lib/common.sh"
. "$root/lib/breadcrumbs.sh"
breadcrumb "$JOB_NAME" "introspect" "${summary:-run failed fail-open}" \
  >/dev/null 2>&1 || true
exit 0
