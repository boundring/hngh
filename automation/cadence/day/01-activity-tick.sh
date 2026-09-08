#!/usr/bin/env bash
# 01-activity-tick — day-tier activity drop-in (cadence-continuum).
# Reads the hngh activity matrix and, for each day-tier activity,
# performs-or-files its next increment. The day tier advances the daily
# activities: implementation, review, refactor, cleanup, inward comms.
#
# Read-only boundary (config.env, security-check): automation NEVER edits
# hngh source or governed state — the ONLY write is the report ledger via
# report-queue. "Performing" an increment here therefore means filing a
# dated report row derived from a REAL read of the artifact the activity
# advances; the row is the observable increment. Fail-closed: exits 0 in
# every expected path, files an alert on a genuine fault, and files the
# skip-condition report when an activity's increment is undefined.
#
# usage: cadence/day/01-activity-tick.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
MATRIX="$KERNEL/docs/project/activity-matrix.md"
REPORT="python3 $KERNEL/scripts/report-queue"
REPORT_KINDS="progress expense optimization scheduled alert"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

# file_report KIND TEXT — one report row + body + breadcrumb. A failed
# write is a breadcrumb, never a crash (fail-closed to exit 0).
file_report() {
  local kind="$1" text="$2"
  case " $REPORT_KINDS " in
  *" $kind "*) ;;
  *)
    breadcrumb "$JOB_NAME" "bad-kind" "refused kind $kind"
    return 1
    ;;
  esac
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$text"
    return 0
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
    return 1
  fi
}

day_of() { # YYYY-MM-DD date from HNGH_TICK_TS (tests) or today UTC
  printf '%s' "${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"
}

# adopted() — a peer-adoption row from fleet.md, or "".
# Adoption is recorded as a dated `fleet.md` line via the existing append
# pattern (`<activity> owned-by <peer>`). Fleet-scaling is display/ledger
# only, never a dispatch network: an adopted activity's row is filed as
# owned-by <peer> instead of acted on locally.
adopted() { # activity -> owner|""
  local f="$KERNEL/docs/project/fleet.md" activity="$1"
  [ -f "$f" ] || {
    printf ''
    return
  }
  local owner
  owner="$(grep -E " owned-by " "$f" | grep -F "$activity" | tail -1 |
    sed -E 's/.* owned-by ([^ ]+).*/\1/')"
  printf '%s' "$owner"
}

run_or_filed() { # activity function -> 0
  local activity="$1" fn="$2" owner
  owner="$(adopted "$activity")"
  if [ -n "$owner" ]; then
    file_report "scheduled" "$activity: owned-by $owner (peer adopted this row)"
  else
    "$fn"
  fi
}

# --- activity increments (each a REAL bounded read of the artifact) ---
# implementation -> active-work.md open lanes
implementation_inc() {
  local aw="$KERNEL/docs/project/active-work.md"
  [ -f "$aw" ] || {
    file_report "scheduled" "implementation: active-work.md absent (nothing due)"
    return 0
  }
  local lanes
  lanes="$(grep -c '^[0-9]' "$aw" 2>/dev/null || true)"
  local top
  top="$(grep -h '^[0-9]' "$aw" | head -1 | cut -c7-80)"
  if [ "${lanes:-0}" = "0" ]; then
    file_report "scheduled" "implementation: $(day_of) no open work lane (nothing due)"
  else
    file_report "progress" "implementation: $(day_of) $lanes open lane(s); next=$top"
  fi
}

# review -> latest report-queue row (nothing newly reported = skip)
review_inc() {
  local latest_id latest_first
  local latest
  latest="$(HNGH_REPORT_ROOT="$report_root" python3 "$KERNEL/scripts/report-queue" --list progress 2>/dev/null |
    grep -v 'review:' | head -1)"
  latest_id="$(printf '%s' "$latest" | cut -d'|' -f4 | tr -d ' ')"
  latest_first="$(printf '%s' "$latest" | cut -d'|' -f5 | tr -d ' ')"
  if [ -z "$latest_id" ]; then
    file_report "scheduled" "review: $(day_of) nothing new to review"
  else
    file_report "progress" "review: $(day_of) latest progress increment=$latest_id ($latest_first)"
  fi
}

# refactor -> a defined refactor step marker; none = skip
refactor_inc() {
  local aw="$KERNEL/docs/project/active-work.md"
  if [ -f "$aw" ] && grep -qi 'refactor' "$aw"; then
    file_report "progress" "refactor: $(day_of) refactor mentioned in active-work; step due"
  else
    file_report "scheduled" "refactor: $(day_of) no refactor step defined (none scheduled)"
  fi
}

# cleanup -> an obsolete/done marker; none = skip
cleanup_inc() {
  local aw="$KERNEL/docs/project/active-work.md"
  if [ -f "$aw" ] && grep -qiE 'done|complete|obsolete' "$aw"; then
    file_report "progress" "cleanup: $(day_of) done markers present; cleanup due"
  else
    file_report "scheduled" "cleanup: $(day_of) nothing obsolete (nothing to clean)"
  fi
}

# inward comms -> checkin.md; already dated today = skip
inward_inc() {
  local ci="$KERNEL/docs/project/checkin.md" today
  today="$(day_of)"
  if [ -f "$ci" ] && grep -q "$today" "$ci"; then
    file_report "scheduled" "inward: $today already noted in checkin.md"
  elif [ -f "$ci" ]; then
    local peek
    peek="$(head -1 "$ci")"
    file_report "progress" "inward: $today checkin awaits line (head: $peek)"
  else
    file_report "scheduled" "inward: checkin.md absent; nothing to note"
  fi
}

# --- run the day-tier activities (matrix is the source of truth) ---
[ -f "$MATRIX" ] || {
  breadcrumb "$JOB_NAME" "no-matrix" "activity matrix missing ($MATRIX)"
  exit 0
}

run_or_filed implementation implementation_inc
run_or_filed review review_inc
run_or_filed refactor refactor_inc
run_or_filed cleanup cleanup_inc
run_or_filed inward_comms inward_inc

breadcrumb "$JOB_NAME" "activity-tick-done" "day $(day_of) activity increments performed-or-filed"
exit 0
