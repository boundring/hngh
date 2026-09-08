#!/usr/bin/env bash
# cadence/30m — readout spine refresh between morning reports: keeps
# queue/timeline/roster fresh for the dashboards (dashboard-self-review
# flags readout.json stale beyond 3x this tier otherwise). Pure reader,
# fails closed; the digest itself stays morning-gated by design.
HNGH="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -x "$HNGH/scripts/dashboard-readout" ]; then
  # per-PID tmp: the 30m tier and refresh-dashboard.sh (morning-report
  # ExecStartPost) collide daily at 11:30Z; a shared tmp name let one
  # writer's fd keep writing into the other's renamed readout.json
  # (2026-09-01 feed-valid:readout unparsable alert).
  tmp="$root/dashboard/.readout.json.$$.tmp"
  if (cd "$HNGH" && python3 scripts/dashboard-readout --json \
    >"$tmp" 2>/dev/null); then
    mv "$tmp" "$root/dashboard/readout.json"
    echo "readout.json refreshed"
  else
    rm -f "$tmp"
  fi
fi
exit 0
