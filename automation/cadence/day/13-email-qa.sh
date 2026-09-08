#!/usr/bin/env bash
# 13-email-qa — day-tier digest QA beat (cadence-continuum).
# The operator asked for cyclical routines that regularly optimize the
# notifications: once per day this scores YESTERDAY's digest
# (logs/email-digest-<yesterday>.md) against a fixed rubric — TL;DR
# head present, long sections carry summaries, no empty sections,
# headline/alerts consistency, <120 lines, redaction duty (no value
# matching the conf password). Procedural, no LLM call. The verdict is
# appended to logs/email-qa.log for trend; findings file ONE
# optimization report row per day (identity-deduped, max one/day).
# Fail-closed: exits 0 on every expected path.
#
# usage: cadence/day/13-email-qa.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
day="$(printf '%s' "${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}" | cut -c1-10)"
yesterday="$(date -u -d "$day - 1 day" +%F 2>/dev/null || true)"
[ -n "$yesterday" ] || yesterday="$(date -u -d '1 day ago' +%F)"
digest="$AUTOMATION_ROOT/logs/email-digest-$yesterday.md"
mkdir -p "$AUTOMATION_ROOT/logs"

verdict="$(python3 "$AUTOMATION_ROOT/scripts/email-qa.py" \
  --digest "$digest" 2>/dev/null ||
  printf 'email-qa %s: scorer failed' "$yesterday")"

printf '%s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$verdict" \
  >>"$AUTOMATION_ROOT/logs/email-qa.log" 2>/dev/null || true

# trend read: the log exists for the trend, so the daily row carries it
# (last 7 verdicts; PASS lines over the window)
trend="$(tail -n 7 "$AUTOMATION_ROOT/logs/email-qa.log" 2>/dev/null |
  grep -c ': PASS' || true)"
verdict="$verdict (7-day passes: ${trend:-0}/7)"

case "$verdict" in
*FINDINGS*)
  HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
    "$KERNEL/scripts/report-queue" --add optimization "$verdict" \
    --identity "email-qa-$day" --window 86400 >/dev/null 2>&1 || true
  ;;
esac
breadcrumb "$JOB_NAME" "email-qa" "$verdict"
exit 0
