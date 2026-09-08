#!/usr/bin/env bash
# 30-kernel-ledger-sync — hour-tier kernel doc-ledger sweep.
# The hngh doc ledgers (reports.md, queue.md, ui-grades.md, journals,
# report-bodies, ui-evolve overlays, research docs) are machine-appended,
# and since the last candidate ceremony (2026-08-31) nothing committed
# them: the kernel tree stays dirty for days (oversight tree-skew x240),
# which starves every clean-tree precondition — schedule-heartbeat
# postpones, so the queue rotation never turns. Once per hour, mirror of
# the automation sweep and of the day-tier plan-ledger-sync: when the
# kernel repo has changes under the machine-managed doc surfaces, commit
# them as one dated sync commit. No push. Refuses (exit 0) when the
# kernel repo has staged changes (never entangles operator work). Only
# docs/ paths are staged by explicit path — kernel code surfaces (src/,
# tests/, scripts/, Makefile, hngh.asd) ride the certificate loop and are
# never touched here. Fail-closed: exits 0 on every expected path.
#
# usage: cadence/hour/30-kernel-ledger-sync.sh  (via cadence-tick.sh TIER=hour)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
[ -d "$KERNEL/.git" ] || exit 0

# operator staged work in flight -> hands off entirely
if ! git -C "$KERNEL" diff --cached --quiet 2>/dev/null; then
  breadcrumb "$JOB_NAME" "kernel-ledger-sync" \
    "refused: kernel repo has staged changes"
  exit 0
fi

# docs surfaces only, explicit paths; plans keep their day-tier owner
surfaces=(docs/journal docs/project docs/design docs/research)
count=0
for s in "${surfaces[@]}"; do
  n="$(git -C "$KERNEL" status --porcelain -- "$s" 2>/dev/null | grep -c . || true)"
  n="${n//[!0-9]/}"
  [ -n "$n" ] && [ "$n" -gt 0 ] || continue
  git -C "$KERNEL" add -- "$s" || continue
  count=$((count + n))
done
[ "$count" -gt 0 ] || exit 0

msg="docs: machine ledger sync — $count changed file(s) ($(date -u +%F))"
if git -C "$KERNEL" commit -q -m "$msg"; then
  breadcrumb "$JOB_NAME" "kernel-ledger-sync" "committed: $msg"
else
  breadcrumb "$JOB_NAME" "kernel-ledger-sync" "commit failed (tree changed mid-sync)"
fi
exit 0
