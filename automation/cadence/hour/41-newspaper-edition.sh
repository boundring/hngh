#!/usr/bin/env bash
# 41-newspaper-edition -- one overnight edition, zero paid model calls.
# Operator cost directive 2026-09-13: the hourly article lane converted
# to a single overnight build (procedural digest + token-limited local
# model sessions only). The job gates itself on the sleep window
# (cadence-params row newspaper-sleep-window, default 01:30-06:30
# local), builds at most one edition per UTC date, and is fail-closed:
# window outside / chain down / no digest = breadcrumb + exit 0, the
# next hour tick retries. GDELT fetch (40-) stays hourly and procedural.
#
# usage: cadence/hour/41-newspaper-edition.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
mkdir -p "$AUTOMATION_ROOT/logs"
python3 "$AUTOMATION_ROOT/jobs/newspaper-edition.py" "$(date -u +%F)" \
  2>>"$AUTOMATION_ROOT/logs/newspaper-edition.err" || true
exit 0
