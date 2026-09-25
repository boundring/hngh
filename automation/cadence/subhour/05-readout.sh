#!/usr/bin/env bash
# cadence/subhour — readout spine refresh between morning reports: keeps
# queue/timeline/roster fresh for the dashboards (dashboard-self-review
# flags readout.json stale beyond 3x this tier otherwise). Pure reader,
# fails closed; the digest itself stays morning-gated by design.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-05-readout-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

HNGH="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ -x "$HNGH/scripts/dashboard-readout" ]; then
  # per-PID tmp: the subhour tier and refresh-dashboard.sh (morning-report
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
