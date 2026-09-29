#!/usr/bin/env bash
# 12-parked-care — parked items automated care: jobs/parked-care.py
# groups the report queue's parked rows into kin clusters (2+ rows
# sharing a [a-z0-9]{4,} token, park* excluded) and files one `needs`
# breadcrumb per cluster so the disposition sweep sees combined debt,
# not scattered singles. Read-only: the queue is never mutated. Repeat
# rows dedup against the crumbs journal (same protocol as the curator
# beat). Fail-closed: exit 0 on every expected path.
#
# usage: cadence/calendar/daily/12-parked-care.sh   (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

out="$(python3 "$AUTOMATION_ROOT/jobs/parked-care.py" 2>/dev/null)" || {
  breadcrumb "$JOB_NAME" parked-care "refused: parked-care.py failed (rc=$?)"
  exit 0
}
norm='s/ disposed=[^ ]* / disposed=X /'
norm_state=""
crumbs_out="$(python3 "$AUTOMATION_ROOT/lib/crumbs-db.py" export --db "${HNGH_CRUMBS_DB:-$AUTOMATION_ROOT/state/crumbs.db}" 2>/dev/null)"
[ -n "$crumbs_out" ] && norm_state="$(printf '%s\n' "$crumbs_out" | sed "$norm")"
while IFS=$'\t' read -r verb detail; do
  [ -n "$verb" ] && [ -n "$detail" ] || continue
  probe="$(printf '%s' "$detail" | sed "$norm")"
  if [ -n "$norm_state" ] && grep -Fq "$probe" <<<"$norm_state"; then
    continue
  fi
  breadcrumb "$JOB_NAME" "$verb" "$detail"
done <<<"$out"
exit 0
