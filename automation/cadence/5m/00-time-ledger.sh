#!/usr/bin/env bash
# cadence/5m — time-ledger measurement tick. Runs before 01-oversight.sh
# (lexical drop-in order) so the delay check reads a fresh ledger.
# Wiring note: refresh-dashboard.sh is NOT a cadence drop-in (it is the
# hngh-morning-report.service ExecStartPost), so the 5m tier is where the
# ledger cadence lives alongside oversight. Timer units untouched.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec "$root/jobs/time-ledger.sh"
