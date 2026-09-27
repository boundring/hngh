#!/usr/bin/env bash
# 25-newspaper-compose -- broadsheet front-page rebuild (2026-09-27).
# Refreshes the fleet snapshot then reruns newspaper-compose.py so
# automation/dashboard/newspaper.json tracks every subhour tick (1m tier
# heritage). Local-only: no network in the composer (news/weather/
# this-day land via the hour news-ingest beat); fail-open per input
# (missing file = stderr note + skip); exits 0 on every expected path.
#
# usage: cadence/subhour/25-newspaper-compose.sh  (via cadence-tick.sh
# TIER=subhour)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
AUTOMATION_ROOT="${HNGH_AUTOMATION_ROOT:-$ROOT}"
# shellcheck disable=SC1091
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh" 2>/dev/null || true

# fleet snapshot for the masthead system block: best-effort refresh
# (fail-soft -- a stale fleet.json keeps serving; the composer fail-opens
# when the file is absent entirely)
DASH="${HNGH_DASHBOARD_DIR:-$AUTOMATION_ROOT/dashboard}"
mkdir -p "$DASH" 2>/dev/null || true
FLEET_BIN="${HNGH_FLEET_MANAGER:-$KERNEL/scripts/fleet-manager}"
if [ -x "$FLEET_BIN" ]; then
  "$FLEET_BIN" --json >"$DASH/fleet.json" 2>/dev/null || true
fi

rc=0
summary="$(python3 "$AUTOMATION_ROOT/scripts/newspaper-compose.py" 2>&1)" || rc=$?
state="ok"
if [ "$rc" -ne 0 ]; then
  state="failed"
fi
HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress \
  "newspaper compose $state: $summary" \
  --identity "newspaper-compose" --window 86400 >/dev/null 2>&1 || true
[ "$(type -t breadcrumb)" = "function" ] &&
  breadcrumb "newspaper-compose" "compose" "$state $summary"
exit 0
