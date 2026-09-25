#!/usr/bin/env bash
# cadence/subhour — time-ledger measurement tick. Runs before 01-oversight.sh
# (lexical drop-in order) so the delay check reads a fresh ledger.
# Wiring note: refresh-dashboard.sh is NOT a cadence drop-in (it is the
# hngh-morning-report.service ExecStartPost), so the subhour tier is where the
# ledger cadence lives alongside oversight. Timer units untouched.
# self-gate (31-heartbeat stamp pattern): one real run per 300s - the
# former 5m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-00-time-ledger-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 300 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/time-ledger.sh"
