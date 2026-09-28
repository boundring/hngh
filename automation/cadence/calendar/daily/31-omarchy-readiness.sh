#!/usr/bin/env bash
# 31-omarchy-readiness -- day-tier omarchy-on-CachyOS phase-readiness
# beat (2026-09-27). Pure read-only reporting for the dashboard's
# future installation desk: files ONE identity-deduped progress row
# (omarchy-readiness:<UTC-date>, 7d window) summarizing phase-1
# readiness as booleans, and ONE alert row (omarchy-ready:phase1-pending)
# only when hyprland is installed but no omarchy session desktop file
# is staged ("packages in, session not staged"). This beat reports,
# never acts: no other alert conditions, no remediation.
#
# Boolean layout in the row text:
#   phase1 a=<clone> b=<manifest>(<n>) c=<hyprland> d=<session> e=<pins>
#     a: upstream clone at $OMARCHY_UPSTREAM_DIR (default
#        ~/Projects/etc/omarchy-upstream) has a .git
#     b: $AUTOMATION_ROOT/config/omarchy-base.packages present and
#        non-empty; n = uncommented line count
#     c: `pacman -Q hyprland` exits 0
#     d: session desktop file in $OMARCHY_SESSIONS_DIR (default
#        /usr/share/wayland-sessions): hyprland-omarchy.desktop or
#        hyprland.desktop
#     e: pins-drift module available and reported ok:true (ok) /
#        ok:false (drift) / module missing or any error (unknown —
#        never coerced to false)
#
# Fail-closed: every path exits 0; on success only breadcrumbs escape.
#
# usage: cadence/calendar/daily/31-omarchy-readiness.sh (via
#        cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
UPSTREAM_DIR="${OMARCHY_UPSTREAM_DIR:-$HOME/Projects/etc/omarchy-upstream}"
SESSIONS_DIR="${OMARCHY_SESSIONS_DIR:-/usr/share/wayland-sessions}"
MANIFEST="$AUTOMATION_ROOT/config/omarchy-base.packages"
PINS_MODULE="$AUTOMATION_ROOT/jobs/pins-drift.py"
WEEK_S=604800 # identity window (progress + pending alert)
JOB_NAME="31-omarchy-readiness"

file_report() { # kind text ident window [evidence]
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  ${3:+--identity "$3"} --window "${4:-$WEEK_S}" \
  ${5:+--evidence "$5"} >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

day="$(date -u +%Y-%m-%d)"

# a) upstream clone
a=no
[ -d "$UPSTREAM_DIR/.git" ] && a=yes

# b) manifest present and non-empty (uncommented lines)
b=no
count=0
if [ -s "$MANIFEST" ]; then
 count="$(grep -cv -e '^[[:space:]]*#' -e '^[[:space:]]*$' "$MANIFEST" 2>/dev/null)" || count=0
 [ "$count" -gt 0 ] 2>/dev/null && b=yes
fi

# c) hyprland installed
c=no
pacman -Q hyprland >/dev/null 2>&1 && c=yes

# d) session desktop file staged
d=no
sess="$SESSIONS_DIR/hyprland-omarchy.desktop"
[ -f "$sess" ] || sess="$SESSIONS_DIR/hyprland.desktop"
[ -f "$sess" ] && d=yes

# e) pins-drift module: ok:true / ok:false / unknown (errors stay unknown)
e=unknown
if [ -f "$PINS_MODULE" ]; then
 pins_out="$(python3 -B "$PINS_MODULE" --json 2>/dev/null)" || pins_out=""
 case "$pins_out" in
 *'"ok": true'* | *'"ok":true'*) e=ok ;;
 *'"ok": false'* | *'"ok":false'*) e=drift ;;
 esac
fi

file_report progress \
 "omarchy phase1 a=$a b=$b($count) c=$c d=$d e=$e" \
 "omarchy-readiness:$day" "$WEEK_S" \
 "$UPSTREAM_DIR|$MANIFEST|$sess|$PINS_MODULE"

if [ "$c" = yes ] && [ "$d" = no ]; then
 file_report alert \
  "omarchy phase1: hyprland installed but session not staged (missing $sess)" \
  "omarchy-ready:phase1-pending" "$WEEK_S" "$sess"
fi
exit 0
