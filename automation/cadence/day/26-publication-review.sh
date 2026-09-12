#!/usr/bin/env bash
# 26-publication-review -- day-tier standing review cycle (operator
# directive, 2026-09-12, docs/research/2026-09-12-publication-review-01.md):
# every UTC day the latest manga draft and the latest dispatch edition get
# the two-pass supportive/adversarial review (jobs/publication-review.py,
# deterministic checklists; a cheap-leg model commentary may attach only
# when idle -- the deterministic passes never depend on it). Red findings
# become report-queue alert rows and escalate through the blocker ledger
# at scope publication:<artifact>: a same-cause failure on the second
# consecutive review parks the artifact (PUBLICATION_ESCALATE_N, default
# 2); a green review clears the row; parked rows auto-unpark on the
# shared cooldown. Fail-closed: exits 0 in every expected path.
#
# usage: cadence/day/26-publication-review.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/beat-blockers.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
out="$(python3 "$AUTOMATION_ROOT/jobs/publication-review.py" --repo "$KERNEL" \
  --report-root "$report_root" 2>&1)"
rc=$?
if [ "$rc" -ne 0 ]; then
  HNGH_REPORT_ROOT="$report_root" $REPORT --add alert \
    "publication-review beat failed (rc=$rc): $(printf '%s' "$out" | tail -n 3)" \
    --identity publication-review --window 86400 >/dev/null 2>&1
  breadcrumb "$JOB_NAME" "publication-review-error" "rc=$rc"
  exit 0
fi

# escalation: map printed FAIL lines onto blocker scopes
# publication:<artifact basename>. block_escalate = record + park at N;
# a scope with no FAIL this run is cleared (success clears outright).
block_escalate() { # scope cause
  local attempts
  attempts="$(blocker_record "$1" "$2")"
  [ "$attempts" -ge "${PUBLICATION_ESCALATE_N:-2}" ] 2>/dev/null &&
    blocker_park "$1"
  return 0
}
failed_scopes="$(printf '%s\n' "$out" | awk '/^FAIL /{n=split($2,p,"/"); print "publication:" p[n], $3}' | sort -u)"
while read -r scope cause; do
  [ -n "$scope" ] || continue
  block_escalate "$scope" "${cause:-review-red}"
done <<EOF
$failed_scopes
EOF
awk -F'\t' '$2 ~ /^publication:/ { print $2 }' "$BEAT_BLOCKERS_FILE" 2>/dev/null |
  while IFS= read -r scope; do
    printf '%s\n' "$failed_scopes" | grep -q "^$scope " || blocker_clear "$scope"
  done
breadcrumb "$JOB_NAME" "publication-review-done" "$(printf '%s' "$out" | grep -c '^FAIL') red"
exit 0
