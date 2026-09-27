#!/usr/bin/env bash
# cadence/subhour — digest-send (2026-09-27 course-correction slice 2,
# three-digests-a-day email doctrine). The ONLY scheduled digest sender:
# composes the digest (durable artifacts logs/email-digest-<ny-day>.md +
# .html) and sends it at the operator's New York slots 0730, 1530, 2200
# (+-3 min tolerance; the subhour tier's tick cadence covers the window).
# Exactly-once per slot per NY day via a stamp file written BEFORE the
# action — a failed send files an alert row and does NOT retry within the
# slot. A missing notify-email.conf is dormant (artifacts still written,
# no send). All alerts continue to land in report-queue + dashboard; no
# on-event email anywhere (HNGH_NOTIFY_IMMEDIATE=0 in config.env).
# Operator/demo escape: HNGH_DIGEST_FORCE_SLOT=<HHMM>, honored ONLY when
# HNGH_DIGEST_TEST=1 is also set (live-safety interlock); ignored on live
# runs. Seams follow the drop-in convention (56-imap-poll pattern):
# HNGH_AUTOMATION_ROOT / HNGH_HOME / HNGH_NOTIFY_EMAIL_CONF /
# HNGH_CRUMBS_DB / HNGH_DIGEST_BIN / HNGH_DIGEST_STAMP_DIR.
# Fail-closed: exits 0 on every expected path.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
AUTOMATION_ROOT="${HNGH_AUTOMATION_ROOT:-$ROOT}"
STAMP_DIR="${HNGH_DIGEST_STAMP_DIR:-/tmp}"
CONF="${HNGH_NOTIFY_EMAIL_CONF:-$HOME/.hngh-automation/notify-email.conf}"
# shellcheck disable=SC1091
. "$ROOT/lib/breadcrumbs.sh" 2>/dev/null || true

nyd="$(TZ=America/New_York date +%Y-%m-%d)"
slot=""
if [ "${HNGH_DIGEST_TEST:-0}" = "1" ] &&
 [ -n "${HNGH_DIGEST_FORCE_SLOT:-}" ]; then
 case "$HNGH_DIGEST_FORCE_SLOT" in
 [0-2][0-9][0-5][0-9]) slot="$HNGH_DIGEST_FORCE_SLOT" ;;
 *) exit 0 ;; # malformed force slot: fail closed, do nothing
 esac
else
 ny="${HNGH_DIGEST_NOW_HHMM:-$(TZ=America/New_York date +%H%M)}"
 case "$ny" in [0-9][0-9][0-9][0-9]) : ;; *) exit 0 ;; esac
 for s in 0730 1530 2200; do
  d=$((10#$ny - 10#$s))
  [ "${d#-}" -le 3 ] && {
   slot="$s"
   break
  }
 done
fi
[ -n "$slot" ] || exit 0 # outside every slot window: silent no-op

stamp="$STAMP_DIR/.hngh-digest-$slot"
if [ "$(cat "$stamp" 2>/dev/null)" = "$nyd" ]; then
 exit 0 # this slot already fired today (exactly-once, no retry)
fi
{ printf '%s\n' "$nyd" >"$stamp"; } 2>/dev/null || true

out="$AUTOMATION_ROOT/logs/email-digest-$nyd.md"
outh="$AUTOMATION_ROOT/logs/email-digest-$nyd.html"
mkdir -p "$AUTOMATION_ROOT/logs" 2>/dev/null || true
if [ -n "${HNGH_DIGEST_BIN:-}" ]; then
 # test/demo seam: stand-in composer
 "$HNGH_DIGEST_BIN" >"$out" 2>/dev/null || true
 "$HNGH_DIGEST_BIN" --html >"$outh" 2>/dev/null || true
else
 python3 "$AUTOMATION_ROOT/scripts/email-digest.py" >"$out" 2>/dev/null || true
 python3 "$AUTOMATION_ROOT/scripts/email-digest.py" --html >"$outh" 2>/dev/null || true
fi

sent="dormant"
if [ -f "$CONF" ]; then
 if timeout 60 python3 "$AUTOMATION_ROOT/scripts/notify-email.py" send \
  --subject "hngh digest $nyd $slot" \
  --body-file "$out" --html-file "$outh" \
  >>"${HNGH_NOTIFY_EMAIL_LOG:-$AUTOMATION_ROOT/logs/notify-email.log}" 2>&1; then
  sent="yes"
 else
  sent="no"
  HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
   "$KERNEL/scripts/report-queue" --add alert \
   "digest send failed rc!=0 (slot $slot, NY day $nyd); durable artifacts: logs/email-digest-$nyd.md; no retry within the slot — next attempt is tomorrow's same slot" \
   --identity "digest-send-fail:$slot:$nyd" --window 86400 \
   >/dev/null 2>&1 || true
 fi
fi

HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}" python3 \
 "$KERNEL/scripts/report-queue" --add progress \
 "digest $nyd $slot: logs/email-digest-$nyd.md (sent=$sent)" \
 --identity "digest-send-$slot-$nyd" --window 86400 >/dev/null 2>&1 || true
[ "$(type -t breadcrumb)" = "function" ] &&
 breadcrumb "digest-send" "digest" "$nyd $slot sent=$sent"
exit 0
