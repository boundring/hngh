#!/usr/bin/env bash
# cadence/subhour — research feed refresh (hngh research queue -> dashboard
# research.json for the Research tab). Read-only probe, fail-closed; 30m
# cadence keeps the tab fresh without hammering the kernel repo.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-25-research-feed-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/research-feed.py"
