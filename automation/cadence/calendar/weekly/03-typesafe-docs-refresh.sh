#!/usr/bin/env bash
# 03-typesafe-docs-refresh — week-tier knowledge-base refresh (slice 3).
# Re-runs typesafe-docs-ingest.py: llms.txt index -> markdown cache at
# <home>/db/typesafe-docs/ + nodes/edges/FTS5 in
# <home>/db/hngh-knowledge.db (see docs/design/ts-kb-playbook.md).
# Network is allowed here by design (weekly, one run, UA-pinned);
# fail-closed: a failed run files one report row and exits 0 — the
# previous DB stays in place and consumers keep working.
#
# usage: cadence/calendar/weekly/03-typesafe-docs-refresh.sh   (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
rc=0
summary="$(python3 "$AUTOMATION_ROOT/scripts/typesafe-docs-ingest.py" 2>&1)" || rc=$?

state="ok"
if [ "$rc" -ne 0 ]; then
  state="failed"
fi
HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress \
  "typesafe docs refresh $state: $summary" \
  --identity "ts-docs-refresh" --window 604800 >/dev/null 2>&1 || true
breadcrumb "$JOB_NAME" "ts-docs-refresh" "$state $summary"
exit 0
