#!/usr/bin/env bash
# cadence/subhour — feedback ingest (operator interactivity, capture->ledger
# wiring 2026-09-12): standardizes dashboard/feedback/*.json into
# operator-items (jobs/feedback-ingest.py, capped 20/tick oldest-first)
# and moves them to feedback/processed/. Numbered before
# 55-feedback-apply.sh: cadence-tick runs drop-ins in lexical order, so
# ingest files the items this same tick's apply beat then acts on.
# self-gate (31-heartbeat stamp pattern): one real run per 1800s - the
# former 30m beat, paced by stamp since the 2026-09-24 tier collapse.
STAMP="/tmp/.hngh-cadence-54-feedback-ingest-last"; now="$(date +%s)"
last="$(cat "$STAMP" 2>/dev/null || printf '0')"; last="${last//[!0-9]/}"; last="${last:-0}"
[ $((now - last)) -ge 1800 ] || exit 0
printf '%s\n' "$now" >"$STAMP"

root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/jobs/feedback-ingest.py"
