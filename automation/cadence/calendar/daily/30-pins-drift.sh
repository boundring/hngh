#!/usr/bin/env bash
# 30-pins-drift -- day-tier pins-vs-pacman drift check (2026-09-27,
# design docs/research/2026-09-26-arc-20260925-os-package-pairing.md).
#
# Runs automation/jobs/pins-drift.py (pure comparator: pins file
# config/hngh-pins.tsv x read-only `pacman -Q`; never installs, never
# auto-updates). drift>0 files ONE identity-deduped alert row
# (identity pins-drift:summary, 7d window) with counts + up to 5
# package names; a fail-closed module error (exit 2: pins file
# unreadable, pacman missing/failing) files pins-drift:error with the
# exception repr one-liner; a clean match files nothing. Every path
# exits 0; on success only breadcrumbs escape.
#
# Pins path note: config/hngh-pins.tsv, NOT hngh-packages.tsv -- that
# path is the collected-repositories registry (test-hngh-packages.py).
#
# usage: cadence/calendar/daily/30-pins-drift.sh (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
MODULE="$AUTOMATION_ROOT/jobs/pins-drift.py"
WEEK_S=604800 # identity window (summary + error alerts)
JOB_NAME="30-pins-drift"

file_report() { # kind text ident window
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  ${3:+--identity "$3"} --window "${4:-$WEEK_S}" >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

[ -f "$MODULE" ] || exit 0

errf="$(mktemp)"
out="$(python3 -B "$MODULE" --check --json 2>"$errf")"
rc=$?
errmsg="$(head -n 1 "$errf")"
rm -f "$errf"
if [ "$rc" -ne 0 ]; then
 [ -n "$errmsg" ] || errmsg="rc=$rc (no stderr)"
 file_report alert "pins-drift check failed: $errmsg" \
  "pins-drift:error" "$WEEK_S"
 exit 0
fi
# clean-or-drift verdict from the module's own JSON (single parse)
text="$(printf '%s' "$out" | python3 -c '
import json, sys
d = json.load(sys.stdin)
if len(d["drift"]) == 0:
    print("CLEAN")
else:
    names = ", ".join(r["name"] for r in d["drift"][:5])
    print(str(len(d["drift"])) + " drifted, " + str(d["unpinned_count"])
          + " unpinned" + (": " + names if names else ""))
')"
[ "$text" = "CLEAN" ] && exit 0
file_report alert "pins drift: $text" "pins-drift:summary" "$WEEK_S"
exit 0
