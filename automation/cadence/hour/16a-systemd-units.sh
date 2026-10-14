#!/usr/bin/env bash
# 16a-systemd-units — backstop for jobs/systemd-units.sh apply.
#
# The unit files in automation/systemd/ are the source of truth for
# ~/.config/systemd/user/hngh-*.service and *.timer. Before this job existed
# they were hand-copied, which is the mechanism behind the drift handoff
# §3.7a documents: seven cadence tiers were consolidated out of the repo and
# kept running on the box for twenty days, looking live and hard-failing on
# every tick.
#
# This is the backstop only. The primary path is the developer running
# `jobs/systemd-units.sh apply` after a unit change, which lands in seconds.
# The hour tick exists so a unit edit that was committed without that step
# still reaches the box, rather than leaving repo and box disagreeing until
# someone notices.
#
# Fail-closed: exits 0 whatever happens, and never fails the tick. A unit
# directory this job cannot write is an operator problem to read in the log,
# not a reason to stall every other hour-tier drop-in.
#
# usage: cadence/hour/16a-systemd-units.sh   (jobs/cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

JOB="$AUTOMATION_ROOT/jobs/systemd-units.sh"

# Nothing to reconcile is the common case and must not leave a crumb: a crumb
# per hour for a clean tree is 8760 rows of noise, and breadcrumbs are a
# signal channel, not an audit log.
if out="$("$JOB" status 2>&1)" && ! printf '%s' "$out" | grep -q 'new-or-changed=0  orphans=0  live-skipped=0'; then
  if applied="$("$JOB" apply 2>&1)"; then
    breadcrumb "16a-systemd-units.sh" "reconcile" \
      "$(printf '%s' "$applied" | grep -E '^(copied|removed|skipped)=' | tr '\n' ' ')"
  else
    breadcrumb "16a-systemd-units.sh" "refuse" "apply failed: $(printf '%s' "$applied" | tail -1)"
  fi
fi

exit 0
