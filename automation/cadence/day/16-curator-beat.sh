#!/usr/bin/env bash
# 16-curator-beat — rehearsal-lane plan step 3: the curator beat.
# Dry, read-only curation: jobs/curator-beat.py reads the work graph
# (dashboard/plans.json from the feed layer + disk re-reads of every
# plan it would act on) and emits two machine actions (priority flag,
# duplicate-scope merge proposal) and two report verbs (deck handoff,
# enabling-work staging) as TSV. This wrapper files each row as a
# STATE.md breadcrumb — operator-item events (flagged/needs) feed the
# operator panel; `context` rows stay ledger-only. Repeat rows dedup
# against STATE.md so the daily beat never spams. It NEVER edits plan
# files: mutations land only through scripts/ceremony-drive with a
# green gate (kernel gate red = beat stays dry, by design).
# Fail-closed: exit 0 on every expected path.
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
[ -d "$KERNEL/docs/project/plans" ] || exit 0
[ -f "$AUTOMATION_ROOT/dashboard/plans.json" ] || exit 0

out="$(python3 "$AUTOMATION_ROOT/jobs/curator-beat.py" 2>/dev/null)" || {
  breadcrumb "$JOB_NAME" curator "refused: curator-beat.py failed (rc=$?)"
  exit 0
}
while IFS=$'\t' read -r verb detail; do
  [ -n "$verb" ] && [ -n "$detail" ] || continue
  if [ -s "$STATE_FILE" ] && grep -Fq "$detail" "$STATE_FILE"; then
    continue
  fi
  breadcrumb "$JOB_NAME" "$verb" "$detail"
done <<< "$out"
exit 0
