#!/usr/bin/env bash
# 35-news-ingest -- dashboard weather lane (2026-09-27; the RSS and
# on-this-day legs retired 2026-10-03 with the wire lane cut): current
# weather (open-meteo) into the per-day cache file the newspaper
# composer reads. Network is allowed here by design (hourly, UA-pinned,
# conditional GET); fail-closed per leg: any failure files ONE progress
# row and exits 0 -- the composer fail-opens on stale caches, consumers
# keep working.
#
# usage: cadence/hour/35-news-ingest.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
state="ok"
wsummary="$(python3 "$AUTOMATION_ROOT/scripts/weather-ingest.py" 2>&1)" || state="failed"

HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress \
  "news ingest $state: $wsummary" \
  --identity "news-ingest" --window 86400 >/dev/null 2>&1 || true
breadcrumb "$JOB_NAME" "news-ingest" "$state $wsummary"
exit 0
