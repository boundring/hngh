#!/usr/bin/env bash
# 14-plan-ledger-sync — day-tier plan-ledger versioning beat.
# The hngh plan ledger (docs/project/plans/) is what scripts/overnight-cycle.sh
# executes from; router-tick writes routed candidates untracked and nothing
# committed them, so the ledger drifted unversioned. Once per day: when the
# kernel repo has changes under docs/project/plans/, commit them as one sync
# commit. No push. Refuses (exit 0) when the kernel repo already has staged
# changes — never entangles an operator's staged work. Skips silently when
# the ledger is clean.
# Fail-closed: exits 0 on every expected path.
#
# usage: cadence/day/14-plan-ledger-sync.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
[ -d "$KERNEL/.git" ] || exit 0

# operator staged work in flight -> hands off entirely
if ! git -C "$KERNEL" diff --cached --quiet 2>/dev/null; then
  breadcrumb "$JOB_NAME" "plan-ledger-sync" \
    "refused: kernel repo has staged changes"
  exit 0
fi

count="$(git -C "$KERNEL" status --porcelain -- docs/project/plans/ 2>/dev/null |
  grep -c . || true)"
count="${count//[!0-9]/}"
if [ -z "$count" ] || [ "$count" -eq 0 ]; then
  exit 0
fi

git -C "$KERNEL" add -- docs/project/plans/ || {
  breadcrumb "$JOB_NAME" "plan-ledger-sync" "refused: git add failed"
  exit 0
}
msg="automation: plan-ledger sync — $count changed file(s) ($(date -u +%F))"
if git -C "$KERNEL" commit -q -m "$msg"; then
  breadcrumb "$JOB_NAME" "plan-ledger-sync" "committed: $msg"
else
  breadcrumb "$JOB_NAME" "plan-ledger-sync" "commit failed (tree changed mid-sync)"
fi
exit 0
