#!/usr/bin/env bash
# cadence/1m — crumbs-mirror tick: byte-offset sync of the STATE.md crumb
# journal into state/crumbs.db (lib/crumbs-db.py; read-only wrt STATE.md),
# then --verify: on mirror mismatch file ONE report-queue alert row
# (identity crumbs-mirror:<kind>, --window 0 + evidence-gated dedup: the
# same evidence token never re-alerts; only an evolved mismatch bumps).
# Fail-open: exit 0 always (the lib itself is fail-open).
# Seams (hermetic tests): HNGH_CRUMBS_DB (mirror path), HNGH_STATE_FILE
# (journal path; lib/crumbs-db.py), HNGH_HOME / HNGH_REPORT_ROOT
# (report-queue location + filing root).
set -u
root="$(cd "$(dirname "$0")/../.." && pwd)"
db="${HNGH_CRUMBS_DB:-$root/state/crumbs.db}"
"$root/lib/crumbs-db.py" sync --db "$db"
out="$("$root/lib/crumbs-db.py" sync --verify --db "$db" 2>/dev/null)"
case "$out" in
*verdict=mismatch:*)
  kind="$(printf '%s\n' "$out" | sed -n 's/^verdict=mismatch:\([a-z]*\).*/\1/p')"
  evidence="$(printf '%s\n' "$out" | sed -n 's/^.*evidence=//p')"
  KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
  HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" \
    python3 "$KERNEL/scripts/report-queue" --add alert \
    "crumbs mirror mismatch: ${out//$'\n'/; }" \
    --identity "crumbs-mirror:$kind" --evidence "$evidence" --window 0 \
    >/dev/null 2>&1 || true
  ;;
esac
exit 0
