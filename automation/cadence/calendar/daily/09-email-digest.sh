#!/usr/bin/env bash
# 09-email-digest — day-tier digest composer (cadence-continuum).
# Composes the daily digest (commits both repos, live plan progress,
# crystallized research docs, lessons, budget) ALWAYS to
# logs/email-digest-<day>.md/.html — the durable artifacts. This
# drop-in NEVER sends (2026-09-27 three-digests-a-day doctrine:
# scheduled transport lives in cadence/subhour/57-digest-send.sh,
# on-event email is off via HNGH_NOTIFY_IMMEDIATE=0).
# Fail-closed: exits 0 on every expected path.
#
# usage: cadence/calendar/daily/09-email-digest.sh   (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
day="$(printf '%s' "${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}")"
out="$AUTOMATION_ROOT/logs/email-digest-$day.md"
mkdir -p "$AUTOMATION_ROOT/logs"

# live gathers (composer reads env seams; tests substitute fixtures)
# one repo since the 2026-09-07 subtree import: split by pathspec so
# the kernel and automation commit lists never overlap.
HNGH_DIGEST_KERNEL_COMMITS="$(
  git -C "$KERNEL" log --since='24 hours ago' --oneline --no-decorate -- . ':(exclude)automation' 2>/dev/null || true
)"
HNGH_DIGEST_AUTO_COMMITS="$(
  git -C "$KERNEL" log --since='24 hours ago' --oneline --no-decorate -- automation 2>/dev/null || true
)"
HNGH_DIGEST_RESEARCH="$(
  git -C "$AUTOMATION_ROOT" status --porcelain 2>/dev/null | grep '/docs/' || true
)"
export HNGH_DIGEST_KERNEL_COMMITS HNGH_DIGEST_AUTO_COMMITS HNGH_DIGEST_RESEARCH

python3 "$AUTOMATION_ROOT/scripts/email-digest.py" >"$out" 2>/dev/null || true
# HTML alternative part: same digest text plus the feedback form feeding
# POST /api/feedback (same capture endpoint as the dashboard pips).
outh="$AUTOMATION_ROOT/logs/email-digest-$day.html"
python3 "$AUTOMATION_ROOT/scripts/email-digest.py" --html >"$outh" 2>/dev/null || true

sent="compose-only" # transport is 57-digest-send's job, never this tier's
HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress \
  "daily email digest $day: logs/email-digest-$day.md (sent=$sent)" \
  --identity "email-digest-$day" --window 86400 >/dev/null 2>&1 || true
breadcrumb "$JOB_NAME" "email-digest" "$out sent=$sent"
exit 0
