#!/usr/bin/env bash
# 06-remote-posture — day-tier remote-access drop-in (cadence-continuum).
# Bounded daily probe of tailnet reachability to the Steamdeck: one
# `tailscale ping` exchange within a hard 15s bound. A pong is the ok
# signal; missing binary, daemon-down, or no pong within the bound is
# degraded.
#
# Read-only boundary: the ONLY write is one report row via report-queue
# when degraded (identity-deduped per day, so re-runs are idempotent).
# Fail-closed: exits 0 in every expected path; a failed report write is
# a breadcrumb, never a crash.
#
# usage: cadence/day/06-remote-posture.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
# machine profile: host identity (deck IP, tailnet, dashboard bind) lives in
# config/machine.env (gitignored; example: config/machine.env.example) -
# peer-review finding 1: machine defaults never bake into job code. The
# profile path is env-selectable (HNGH_MACHINE_PROFILE) for tests.
MACHINE_PROFILE="${HNGH_MACHINE_PROFILE:-$AUTOMATION_ROOT/config/machine.env}"
[ -f "$MACHINE_PROFILE" ] && . "$MACHINE_PROFILE"
DECK_IP="${DECK_IP:-}" # steamdeck tailnet addr; machine profile or exported env

day_of() { # YYYY-MM-DD date from HNGH_TICK_TS (tests) or today UTC
  printf '%s' "${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"
}

# fail-closed: without a machine profile (and no env DECK_IP) there is no
# host identity to probe - skip, never fall back to a baked-in address.
if [ -z "$DECK_IP" ]; then
  breadcrumb "$JOB_NAME" "remote-posture" \
    "no DECK_IP (config/machine.env missing - see config/machine.env.example): skipped"
  exit 0
fi

# file_report TEXT — one report row + breadcrumb. A failed write is a
# breadcrumb, never a crash (fail-closed to exit 0).
file_report() {
  local text="$1"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add progress \
    "$text" --identity "remote-posture-degraded-$(day_of)" --window 86400 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "progress" "$text"
    return 0
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file progress: $text"
    return 1
  fi
}

# ok iff one ping exchange succeeds within the bound; the outer timeout
# is the hard wall regardless of flags/binary state.
if command -v tailscale >/dev/null 2>&1 &&
  timeout 15 tailscale ping --timeout=10s --c=1 "$DECK_IP" 2>/dev/null | grep -q 'pong from'; then
  breadcrumb "$JOB_NAME" "remote-posture" "ok: deck $DECK_IP reachable"
else
  file_report "remote posture degraded $(day_of): tailscale ping $DECK_IP (deck) unreachable" || true
fi
exit 0
