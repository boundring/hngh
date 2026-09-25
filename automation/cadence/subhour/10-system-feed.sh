#!/usr/bin/env bash
# cadence/subhour — system-ops feed refresh (CachyOS package/unit/disk/journal
# observability -> dashboard/system-ops.json for the System tab). Read-only
# probe, fail-closed per source; 30m cadence is ample for update/unit drift.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-10-system-feed-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/system-feed.py"
