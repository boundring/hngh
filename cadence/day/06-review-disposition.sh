#!/usr/bin/env bash
# 06-review-disposition — REVIEW sink: the fresh-eyes review digests
# (digest/REVIEW-<date>.md, written by 04-review-prep.sh ~09:00) have no
# consumer; this drop-in turns their P1/P2 findings into report-queue
# rows (identity review-finding:<digest-date>:<slug>, text + "fix or
# park with cause") so each finding gets a routing-loop disposition.
# nits are skipped (counted in one log line). Idempotent: report-queue
# dedups by identity+window (7d covers digest reuse across days).
# Fail-closed: missing digest -> breadcrumb + exit 0.
#
# usage: cadence/day/06-review-disposition.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

file_report() {
  local kind="$1" text="$2" ident="$3"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
    --identity "$ident" --window 604800 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$ident"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $ident"
  fi
}

day="$(date -u +%Y-%m-%d)"
file="$AUTOMATION_ROOT/digest/REVIEW-$day.md"
if [ ! -f "$file" ]; then
  file="$AUTOMATION_ROOT/digest/REVIEW-$(date -u -d yesterday +%Y-%m-%d).md"
fi
if [ ! -f "$file" ]; then
  breadcrumb "$JOB_NAME" "review-dispose-skip" "no REVIEW digest for $day or yesterday"
  exit 0
fi
digest_date="$(basename "$file" .md)"
digest_date="${digest_date#REVIEW-}"

nits="$(grep -c '^- nit:' "$file" 2>/dev/null || true)"
printf '%s [%s] %s nit finding(s) skipped\n' "$(date -u +%H:%M:%S)" \
  "$JOB_NAME" "${nits:-0}" >&2

# finding lines are markdown list items: "- P1: text" / "- P2: text"
grep '^- P[12]:' "$file" 2>/dev/null | while IFS= read -r finding; do
  text="${finding#- P[12]: }"
  slug="$(printf '%s' "$text" | tr -cs 'A-Za-z0-9' '-' | cut -c1-40 |
    sed 's/^-*//; s/-*$//')"
  [ -n "$slug" ] || slug="finding"
  file_report alert "$text fix or park with cause" \
    "review-finding:$digest_date:$slug"
done

breadcrumb "$JOB_NAME" "review-dispose-done" "$file sunk to report queue"
exit 0
