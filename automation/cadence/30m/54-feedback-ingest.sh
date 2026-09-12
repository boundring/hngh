#!/usr/bin/env bash
# cadence/30m — feedback ingest (operator interactivity, capture->ledger
# wiring 2026-09-12): standardizes dashboard/feedback/*.json into
# operator-items (jobs/feedback-ingest.py, capped 20/tick oldest-first)
# and moves them to feedback/processed/. Numbered before
# 55-feedback-apply.sh: cadence-tick runs drop-ins in lexical order, so
# ingest files the items this same tick's apply beat then acts on.
root="$(cd "$(dirname "$0")/../.." && pwd)"
exec python3 "$root/jobs/feedback-ingest.py"
