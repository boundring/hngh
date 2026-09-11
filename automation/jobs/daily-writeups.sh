#!/usr/bin/env bash
# daily-writeups — run the hngh kernel's publication generators every
# morning: --daily (today's journal; refuses if it exists — correct),
# --ebook, --site. Best-effort: every generator failure is a breadcrumb,
# never fatal. Fail-closed: always exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

# kernel root: config.env HNGH_HOME (defaults to the hngh kernel checkout)
KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
GEN="$KERNEL/scripts/generate-publication"

[ -x "$GEN" ] || {
  breadcrumb "$JOB_NAME" "writeups" "generator CLI missing ($GEN) — skipped"
  exit 0
}
cd "$KERNEL" || {
  breadcrumb "$JOB_NAME" "writeups" "cannot cd $KERNEL"
  exit 0
}

# Drift refresh: a machine-generated journal whose counters no longer
# match the record is regenerated. Root cause fixed here: run-autonomous
# (hngh-autonomy.timer, hourly) writes the journal on the first tick of
# the UTC day (00:00Z = 20:00 EDT), snapshotting zero counters, and the
# morning --daily then refuses (journal exists) — the false journal
# freezes all day (2026-08-27.md: "0 commits" vs ~15 real ones).
# Guard: only files with the machine ledger header ("- **N** commits")
# are eligible; operator-authored journals are never touched.
for day in "$(date -u -d yesterday +%F)" "$(date -u +%F)"; do
  j="$KERNEL/docs/journal/$day.md"
  [ -f "$j" ] || continue
  grep -q '^- \*\*[0-9][0-9]*\*\* commits' "$j" || continue
  "$GEN" --check "$day" >/dev/null 2>&1 && continue
  if "$GEN" --daily "$day" --force >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "writeups" "--daily refreshed drifted journal $day (--force)"
  else
    breadcrumb "$JOB_NAME" "writeups" "--daily refresh failed for $day (data, not fatal)"
  fi
done

if ! "$GEN" --daily >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "writeups" "--daily refused (journal exists or counts drift; expected when present) or failed"
else
  breadcrumb "$JOB_NAME" "writeups" "--daily journal generated"
fi

# daily dispatch: the public README's sentinel-bounded headline table
# (machine-owned like the STATE-OF-PROJECT torch sentinels) plus the
# journal's DISPATCH lead section, both fed by --daily/--readme above.
if "$GEN" --readme "$KERNEL/README.md" >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "dispatch" "README dispatch table rewritten"
else
  breadcrumb "$JOB_NAME" "dispatch" "README dispatch table not rewritten (sentinels missing or feeds unreadable)"
fi

if ! "$GEN" --ebook >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "writeups" "--ebook failed (data, not fatal)"
else
  breadcrumb "$JOB_NAME" "writeups" "--ebook refreshed"
fi

if ! "$GEN" --site >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "writeups" "--site failed (data, not fatal)"
else
  breadcrumb "$JOB_NAME" "writeups" "--site refreshed"
fi

exit 0
