#!/usr/bin/env bash
# cadence/5m — read-only system probes:
#   jobs/system-awareness.sh  -> dashboard/system.json (resource headroom)
#   jobs/service-state.py     -> dashboard/service-state.json (allowlisted
#                                unit states + serving-port recognition,
#                                incl. the once-per-day unsloth-down alert)
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/jobs/system-awareness.sh" || true
python3 "$ROOT/jobs/service-state.py" || true
exit 0
