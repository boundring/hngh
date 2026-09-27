#!/usr/bin/env bash
# 35-news-ingest -- broadsheet news lane (2026-09-27): external RSS/Atom
# into <home>/db/hngh-news.db plus current weather (open-meteo) and the
# Wikipedia "on this day" column into per-day cache files. Network is
# allowed here by design (hourly, UA-pinned, conditional GET);
# fail-closed per feed and fail-open per leg: any failure files ONE
# progress row and exits 0 -- the newspaper composer fail-opens on stale
# caches, consumers keep working.
#
# usage: cadence/hour/35-news-ingest.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
state="ok"
summary="$(python3 "$AUTOMATION_ROOT/scripts/news-ingest.py" 2>&1)" || state="failed"
wsummary="$(python3 "$AUTOMATION_ROOT/scripts/weather-ingest.py" 2>&1)" || state="failed"
tsummary="$(python3 "$AUTOMATION_ROOT/scripts/this-day-ingest.py" 2>&1)" || state="failed"

HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress \
  "news ingest $state: $summary; $wsummary; $tsummary" \
  --identity "news-ingest" --window 86400 >/dev/null 2>&1 || true
breadcrumb "$JOB_NAME" "news-ingest" "$state $summary"
exit 0
