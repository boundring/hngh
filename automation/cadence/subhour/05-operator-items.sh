#!/usr/bin/env bash
# cadence/subhour — operator-items feed tick: keeps the handled/dismissed
# lifecycle fresh (dashboard-self-review flags operator-items.json stale
# beyond 3x the subhour tier otherwise). Fail-closed: exit 0 always.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/operator-items-feed.py"
