#!/usr/bin/env bash
# test-gate-refusals.sh — R8 (refoundation P3c): every gate refusal is a
# state change. A blocked pacer must (1) keep its stdout protocol exactly
# "used cap" (pacers run inside command substitution), (2) write one
# gate-refusal crumb to the spine journal, (3) append one report row with
# identity gate-refusal:<gate> and window 604800 (dedup keys passed; the
# ledger's own dedup is report-queue's tested contract), and (4) stay
# fail-open/silent when the report queue is missing. Hermetic: fake
# report-queue records invocations; sandbox crumbs db; no network.
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

export AUTOMATION_ROOT="$root"
export HNGH_REPORT_QUEUE="$sb/fake-report-queue"
export HNGH_CRUMBS_DB="$sb/crumbs.db"
: >"$HNGH_REPORT_QUEUE.calls"

# fake report-queue: record argv, exit 0
cat >"$HNGH_REPORT_QUEUE" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${HNGH_REPORT_QUEUE}.calls"
exit 0
EOF
chmod +x "$HNGH_REPORT_QUEUE"

. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"

# telemetry db: schema + one row so "used" parses; cap 0 forces blocked
export HNGH_TELEMETRY_DB="$sb/telemetry.db"
sqlite3 "$HNGH_TELEMETRY_DB" \
  "create table events(ts text, kind text, source text); insert into events values('2026-09-25T00:00:00Z','model','kimi');"

# 1. stdout protocol intact under blockage (nothing leaks from reporting)
out="$(quota_pace_blocked kimi 0 2>"$sb/stderr")" || true
ck "protocol stdout" "1 0" "$out"
ck "silent stderr" "" "$(cat "$sb/stderr")"

# 2. one report row: kind alert, identity, window 604800
row="$(grep -c 'add alert --identity gate-refusal:pace-quota_pace_blocked --window 604800' "$HNGH_REPORT_QUEUE.calls")"
ck "report row appended" "1" "$row"

# 3. crumb landed on the spine journal
crumb_line="$(python3 "$AUTOMATION_ROOT/lib/crumbs-db.py" --db "$HNGH_CRUMBS_DB" export --tail 1 2>/dev/null)"
case "$crumb_line" in
*"gate | gate-refusal | pace-quota_pace_blocked"*)
  echo "ok: spine crumb written"
  ;;
*)
  echo "FAIL: spine crumb written (got [$crumb_line])"
  fails=$((fails + 1))
  ;;
esac

# 4. every paced gate reports its own identity (cap 0 blocks each)
: >"$HNGH_REPORT_QUEUE.calls"
for pacer in quota_pace_blocked quota_pace_blocked_5h \
  quota_pace_blocked_window quota_pace_blocked_week gemini_burst_blocked; do
  case "$pacer" in
  quota_pace_blocked) quota_pace_blocked kimi 0 >/dev/null ;;
  quota_pace_blocked_5h) quota_pace_blocked_5h kimi 0 >/dev/null ;;
  quota_pace_blocked_window) quota_pace_blocked_window kimi 0 3600 3600 >/dev/null ;;
  quota_pace_blocked_week) quota_pace_blocked_week kimi 0 1 >/dev/null ;;
  gemini_burst_blocked) GEMINI_BURST_MAX_CALLS=0 gemini_burst_blocked >/dev/null ;;
  esac
done
for pacer in quota_pace_blocked quota_pace_blocked_5h \
  quota_pace_blocked_window quota_pace_blocked_week gemini_burst_blocked; do
  ck "identity pace-$pacer" "1" \
    "$(grep -c "gate-refusal:pace-$pacer " "$HNGH_REPORT_QUEUE.calls")"
done

# 5. fail-open: missing report queue changes nothing observable
rm -f "$HNGH_REPORT_QUEUE"
out="$(HNGH_REPORT_QUEUE="$sb/nonexistent" quota_pace_blocked kimi 0 2>/dev/null)" || true
ck "fail-open protocol" "1 0" "$out"

if [ "$fails" -eq 0 ]; then echo "ALL OK"; else
  echo "$fails FAILURES"
  exit 1
fi
