#!/usr/bin/env bash
# 02-ledger-prune — day-tier self-improvement drop-in: keep the hngh report
# ledger from re-bloating. Prunes alert rows older than 48h (archived first),
# reports the count, and files ONE honest alert when the prune left tracked
# body deletions (deletions cannot pass hngh verify-candidate; an operator
# ceremony must commit them). Prune commits stay out of automation's hands.
# Fail-closed: exits 0 in every expected path.
#
# usage: cadence/day/02-ledger-prune.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

# file_report KIND TEXT [IDENTITY] [WINDOW] — one report row + body +
# breadcrumb. A failed write is a breadcrumb, never a crash (fail-closed 0).
file_report() {
  local kind="$1" text="$2" ident="${3:-}" win="${4:-86400}"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
    ${ident:+--identity "$ident"} --window "$win" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$text"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
  fi
}

before="$(date -u -d '48 hours ago' +%Y-%m-%dT%H:%M:%SZ)"
archive_rel="docs/project/report-bodies/prune-archive-$(date -u +%Y-%m-%d).md"

out="$(cd "$KERNEL" && HNGH_REPORT_ROOT="$KERNEL" $REPORT --prune \
  --before "$before" --kinds alert --archive "$archive_rel" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  file_report alert "ledger prune failed rc=$rc: $(printf '%s' "$out" | tail -n 1)"
  exit 0
fi

n="$(printf '%s' "$out" | sed -n 's/^pruned \([0-9][0-9]*\) rows.*/\1/p')"
n="${n:-0}"
if [ "$n" -gt 0 ]; then
  file_report progress "ledger prune: pruned $n alert rows (48h retention, archived to $archive_rel)"
fi

# tracked body deletions cannot ride an automation commit (verify-candidate
# refuses deletions) — surface them honestly for an operator ceremony.
if git -C "$KERNEL" status --porcelain -- docs/project/report-bodies 2>/dev/null |
  grep -qE '^( D|D )'; then
  file_report alert \
    "prune left tracked body deletions — operator ceremony needed" \
    "ledger-prune:deletions" 604800
fi

breadcrumb "$JOB_NAME" "prune-done" "ledger prune finished (pruned $n alert rows)"
exit 0
