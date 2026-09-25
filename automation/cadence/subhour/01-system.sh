#!/usr/bin/env bash
# cadence/subhour — read-only system probes:
#   jobs/system-awareness.sh  -> dashboard/system.json (resource headroom)
#   jobs/service-state.py     -> dashboard/service-state.json (allowlisted
#                                unit states + serving-port recognition,
#                                incl. the once-per-day unsloth-down alert)
# self-gate (31-heartbeat stamp pattern): one real run per 300s - the
# former 5m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-01-system-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 300 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
bash "$ROOT/jobs/system-awareness.sh" || true
python3 "$ROOT/jobs/service-state.py" || true
exit 0
