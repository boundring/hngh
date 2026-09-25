#!/usr/bin/env bash
# test-oversight-tick-alert-redact.sh — the oversight-tick alert() seam
# must redact /home/<user>/ and /tmp/ path prefixes before filing an
# alert row or a breadcrumb (2026-09-16 boundary redaction). Sources the
# job's real alert() seam against a fake report-queue; hermetic.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { rm -rf "$sb"; }
trap cleanup EXIT
fails=0
ck() {
 if [ "$2" = "$3" ]; then echo "ok: $1"; else
  echo "FAIL: $1 (want [$2] got [$3])"
  fails=$((fails + 1))
 fi
}

export FAKE_QUEUE_LOG="$sb/calls.log"
: >"$FAKE_QUEUE_LOG"
export AUTOMATION_ROOT="$root"
# crumbs seam: alert()'s breadcrumb lands in the sandbox journal db, not
# the real one; assertions read it via the export bridge
export HNGH_CRUMBS_DB="$sb/crumbs.db"
journal() { python3 "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }
export JOB_NAME="oversight-tick-test"
export ALERT_LAST="$sb/alert-last"
: >"$ALERT_LAST"
touch "$sb/attention"

# source only the job's alert() seam: from the top of the file through
# the end of the alert() definition (its closing brace at column 1 —
# the first such brace after `alert()`), so the probe sections never
# run and line drift above alert() cannot break the cut. Rewrite ROOT
# so the sourced header resolves without side effects.
awk '
  /^alert\(\)/ {in_alert = 1}
  in_alert && /^\}/ {print; exit}
  {print}
' "$root/jobs/oversight-tick.sh" |
 sed -e "s#^ROOT=.*#ROOT=\"$root\"#" >"$sb/job-head.sh"
# shellcheck disable=SC1090
. "$sb/job-head.sh" || exit 1
type alert >/dev/null 2>&1 || {
 echo "FAIL: alert() not sourced"
 exit 1
}

# fake report-queue: log argv, exit 0
cat >"$sb/rq" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_QUEUE_LOG"
exit 0
EOF
chmod +x "$sb/rq"
REPORT_QUEUE="$sb/rq"

# 1. home path in alert detail is redacted in the queue argv
: >"$FAKE_QUEUE_LOG"
alert "stale-store" "/home/aubergine/store record.lisp untouched 30min+" \
 "stale-store:/home/aubergine/store" 86400
case "$(cat "$FAKE_QUEUE_LOG")" in
*'~/store record.lisp'*) ck "alert row home-redacted" clean clean ;;
*) ck "alert row home-redacted" "~/store present" "leak: $(cat "$FAKE_QUEUE_LOG")" ;;
esac

# 2. breadcrumb carries the same redaction (present redacted, absent raw)
grep -q '/home/aubergine' <(journal) && got=leak || got=clean
ck "breadcrumb home-redacted" "clean" "$got"
ck "breadcrumb carries redacted form" "1" \
 "$(grep -c 'oversight-tick | alert | stale-store: ~/store' <(journal))"

# 3. /tmp path in alert detail is redacted
: >"$FAKE_QUEUE_LOG"
alert "stale-store" "/tmp/hngh-cer-a5520.store record.lisp untouched 30min+" \
 "stale-store:/tmp/hngh-cer-a5520.store" 86400
grep -q '/tmp/hngh-cer-a5520.store' "$FAKE_QUEUE_LOG" && got=leak || got=clean
ck "alert row tmp-redacted" "clean" "$got"
grep -q '~tmp/hngh-cer-a5520.store' "$FAKE_QUEUE_LOG" || fails=$((fails + 1))

# 4. suppression bookkeeping still keyed on the redacted key: the same
# redacted (kind, detail) within SUPPRESS_MIN must not queue again
alert "stale-store" "/tmp/hngh-cer-a5520.store record.lisp untouched 30min+" \
 "stale-store:/tmp/hngh-cer-a5520.store" 86400
lines=$(wc -l <"$FAKE_QUEUE_LOG")
ck "repeat within SUPPRESS_MIN not re-queued" "1" "$lines"

# 5. non-path detail passes through unharmed
: >"$FAKE_QUEUE_LOG"
rm -f "$ALERT_LAST"
alert "system-low-disk" "critical resource flag set" "system-low-disk" 86400
grep -q '\[oversight\] system-low-disk: critical resource flag set' \
 "$FAKE_QUEUE_LOG" || fails=$((fails + 1))

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
 echo "$fails FAILED"
 exit 1
}
