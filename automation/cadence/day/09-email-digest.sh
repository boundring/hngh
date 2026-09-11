#!/usr/bin/env bash
# 09-email-digest — day-tier operator email report (cadence-continuum).
# Composes the daily digest (commits both repos, live plan progress,
# crystallized research docs, lessons, budget via the existing
# telemetry-report tooling) and emails it through notify-email.py when
# the operator's config exists; the digest is ALWAYS written to
# logs/email-digest-<day>.md — the durable artifact; email is transport.
# Fail-closed: exits 0 on every expected path (missing config = dormant).
#
# usage: cadence/day/09-email-digest.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/notify-email.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
day="$(printf '%s' "${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}")"
out="$AUTOMATION_ROOT/logs/email-digest-$day.md"
mkdir -p "$AUTOMATION_ROOT/logs"

# live gathers (composer reads env seams; tests substitute fixtures)
HNGH_DIGEST_KERNEL_COMMITS="$(
  git -C "$KERNEL" log --since='24 hours ago' --oneline --no-decorate 2>/dev/null || true
)"
HNGH_DIGEST_AUTO_COMMITS="$(
  git -C "$AUTOMATION_ROOT" log --since='24 hours ago' --oneline --no-decorate 2>/dev/null || true
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

# transport: send only when the operator config exists (dormant otherwise)
sent="dormant"
if [ -f "$(email_conf_path)" ]; then
  if timeout 60 python3 "$AUTOMATION_ROOT/scripts/notify-email.py" send \
    --subject "hngh daily digest $day" --body-file "$out" \
    --html-file "$outh" \
    >>"$EMAIL_LOG" 2>&1; then
    sent="yes"
  else
    sent="no"
  fi
fi

HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
  "$KERNEL/scripts/report-queue" --add progress \
  "daily email digest $day: logs/email-digest-$day.md (sent=$sent)" \
  --identity "email-digest-$day" --window 86400 >/dev/null 2>&1 || true
breadcrumb "$JOB_NAME" "email-digest" "$out sent=$sent"
exit 0
