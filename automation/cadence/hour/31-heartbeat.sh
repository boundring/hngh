#!/usr/bin/env bash
# 31-heartbeat — the queue-rotation clock, mounted at last.
# queue.md's scheduling section documents the intended cadence: one
# schedule-heartbeat tick per heartbeat-minutes (Inventory; default 60,
# was hardcoded 3h through the Tier 1 acceleration of 2026-09-07). The
# tick is self-gating (clean
# tree, reachable reviewer route, mounted action card; postponed or
# refused conditions are recorded, never crashed) and commits its own
# telemetry. This drop-in gates to >=3h between real ticks via a stamp
# file in /tmp — ephemeral on purpose: the worst case after a reboot is
# one extra tick. Runs right after 30-kernel-ledger-sync so the tree it
# probes is freshly swept. The periodic invocation lives here, in the
# operator's cadence — the tick never backgrounds itself (no-daemon
# boundary). Fail-closed: exits 0 on every expected path.
#
# usage: cadence/hour/31-heartbeat.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
[ -x "$KERNEL/scripts/schedule-heartbeat" ] || exit 0

STAMP="/tmp/.hngh-heartbeat-last"
heartbeat_min="${HEARTBEAT_MINUTES:-$(get_param heartbeat-minutes 60)}"
now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"
last="${last//[!0-9]/}"
last="${last:-0}"
[ $((now - last)) -ge $((heartbeat_min * 60)) ] || exit 0

rc=0
out="$(timeout 1800 python3 "$KERNEL/scripts/schedule-heartbeat" 2>&1)" || rc=$?
[ "$rc" -eq 0 ] || out="$out (tick rc=$rc)"
# rc=1 is a postpone (dirty tree, no route): the slot is not consumed --
# the next hour retries. Any other outcome stamps the cadence.
[ "$rc" -eq 1 ] || printf '%s\n' "$now" >"$STAMP" 2>/dev/null || true
breadcrumb "$JOB_NAME" "heartbeat" \
  "$(printf '%s\n' "$out" | tail -n 1 | cut -c1-200)"
exit 0
