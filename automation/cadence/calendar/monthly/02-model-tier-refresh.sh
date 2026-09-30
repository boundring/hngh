#!/usr/bin/env bash
# 02-model-tier-refresh — month-tier route-review cadence (slice E,
# governed-fleet.md:248 "model-tier refresh cadence": when the newest
# bench digest ages past model-tier-refresh-ola, ONE identity-deduped
# operator alert files the route-review item (workhorse / runner-ups /
# dropped verdicts stay the operator's digest read; the delta risk stays
# the 0/5-twice drop rule per cadence-params). Verdict on the newest
# DIGEST_DIR/BENCH-*.md mtime. A clean verdict files nothing.
# Fail-closed: every path exits 0; on success only breadcrumbs escape.
#
# Digest dir falls back to the daily UI's digest dir when
# HNGH_HOME_DIR is set: the bench computes DIGEST_DIR from
# lib/common.sh (digests under the userspace data home since the
# 2026-09-13 operator directive).
#
# usage: cadence/calendar/monthly/02-model-tier-refresh.sh   (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
IDENT="model-tier-refresh:summary"
WEEK_S=604800 # identity window (the OLA is monthly; the row re-fires when the receipt changes)
JOB_NAME="02-model-tier-refresh"

file_report() { # kind text ident window
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
    --identity "$3" --window "$4" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$1" "$2"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
  fi
}

# OLA: seconds the newest bench digest may be old and still route-tolerated.
# cadence-params row `model-tier-refresh-ola` (slice E row, default 90d);
# env MODEL_TIER_REFRESH_OLA overrides; a malformed OLA fail-opens to the
# designed 90d rather than alert-storming.
OLA_S="${MODEL_TIER_REFRESH_OLA:-$(get_param model-tier-refresh-ola 7776000)}"
case "$OLA_S" in
'' | *[!0-9]*) OLA_S=7776000 ;;
esac

newest="$(ls -t "$DIGEST_DIR"/BENCH-*.md 2>/dev/null | head -n 1)"
if [ -z "$newest" ]; then
  # No digest at all: the bench lanes own first-bench onboarding (the
  # bench-trigger verbs). Scope-statement, not an alert.
  breadcrumb "$JOB_NAME" "scoped" "no bench digest yet; bench-trigger verbs own first-bench onboarding (slice E scope is the refresh OLA only)"
  exit 0
fi

age_s=$(($(date +%s) - $(stat -c %Y "$newest" 2>/dev/null || echo 0)))
if [ "$age_s" -lt "$OLA_S" ]; then
  breadcrumb "$JOB_NAME" "fresh" \
    "newest bench digest $(basename "$newest") is ${age_s}s old < model-tier-refresh-ola ${OLA_S}s — route review not pending"
  exit 0
fi

days=$((age_s / 86400))
file_report alert \
  "model-tier refresh OLA exceeded: newest bench digest $(basename "$newest") is ${days}d old (OLA $((OLA_S / 86400))d) — schedule the route review (workhorse / runner-ups / dropped; 0/5-twice drop rule stands)" \
  "$IDENT" "$WEEK_S"
exit 0
