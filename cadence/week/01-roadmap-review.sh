#!/usr/bin/env bash
# 01-roadmap-review — week-tier activity drop-in (cadence-continuum).
# Reads the hngh activity matrix week rows (roadmap review, planning,
# outward comms) and performs-or-files the roadmap-review increment:
# appraise the real roadmap.md `## Now` frontier + `## Next` list and file
# a dated row naming the frontier and the highest-value next candidate.
# Read-only on the hngh repo: the ONLY write is the report ledger.
# Fail-closed: exits 0; files the skip-condition report when unchanged.
#
# usage: cadence/week/01-roadmap-review.sh   (via cadence-tick.sh TIER=week)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
ROADMAP="$KERNEL/docs/project/roadmap.md"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

file_report() {
  local kind="$1" text="$2"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$text"
    return 0
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
    return 1
  fi
}

[ -f "$ROADMAP" ] || {
  breadcrumb "$JOB_NAME" "no-roadmap" "roadmap.md missing"
  exit 0
}

today="${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"

# the #1 `## Next` candidate: first `N. **name**` line after `## Next`
frontier="$(sed -n '/^## Next/,/^## /p' "$ROADMAP" | grep -m1 '^1\.' | tr -d '1.*#`' | xargs)"
next_candidates="$(sed -n '/^## Next/,/^## /p' "$ROADMAP" | grep -E '^[0-9]+\.' | grep -oE '\*\*[^*]+\*\*' | tr -d '*')"
highest="$(printf '%s\n' "$next_candidates" | head -1)"

if [ -n "$frontier" ] || [ -n "$highest" ]; then
  file_report "progress" "roadmap-review: $today frontier=$frontier highest-next=$highest"
else
  file_report "scheduled" "roadmap-review: $today no change since last review (unchanged)"
fi

# planning row — queue.md Next block names the active planning candidate
QUEUE="$KERNEL/docs/project/queue.md"
if [ -f "$QUEUE" ]; then
  plan_next="$(sed -n '/^## Next/,/^## /p' "$QUEUE" | grep -m1 -oE '\*\*[^*]+\*\*' | tr -d '*')"
  if [ -n "$plan_next" ]; then
    file_report "progress" "planning: $today in-flight candidate $plan_next (queue Next)"
  else
    file_report "scheduled" "planning: $today no lane wants a new candidate (nothing to draft)"
  fi
fi

# outward comms row — a dated market/outreach observation (pull from digest)
DIGEST_DIR="$AUTOMATION_ROOT/digest"
if [ -d "$DIGEST_DIR" ]; then
  newest="$(ls "$DIGEST_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md 2>/dev/null | tail -1)"
  if [ -n "$newest" ]; then
    file_report "progress" "outward: $today digest $(basename "$newest") market signal surfaced"
  fi
fi

breadcrumb "$JOB_NAME" "roadmap-review-done" "week $today review performed-or-filed"
exit 0
