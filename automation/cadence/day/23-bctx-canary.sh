#!/usr/bin/env bash
# 23-bctx-canary — config-drift canary for the billion-context proxy
# budget (model-free, deterministic, fail-closed).
#
# The operator's context-budget posture lives in
# ~/.config/billion-context/billion-context.json (compress.maxContextLimit);
# the decision is on record at hngh
# docs/records/2026-08-24-context-budget-and-toolchain.md (40% chosen; live
# drifted to 44%, adopted 2026-09-07 pending operator confirm). This canary
# reads the live config and compares against the Inventory row
# bctx-max-context-limit (cadence-params.tsv; env BCTX_MAX_CONTEXT overrides):
#   drift   -> ONE identity-deduped report-queue alert row
#              (identity bctx-config-drift, expected vs found) + breadcrumb
#   match   -> silent ok row once per window (identity bctx-canary-ok, 86400)
#   missing -> alert 'bctx config missing' (identity bctx-config-missing)
# emergencyThresholdPercent + nudgeGrowthTokens are carried in the row text
# for observability. Proxy token feed note: billion-context's verbose
# per-session token log is disabled and nothing was enabled; no readable
# per-session token record exists, so the ratio vital
# (cadence/day/21-context-ratio.sh) stays transcript-derived.
#
# Fail-closed: exit 0 on every path; a failed run is a breadcrumb, never a
# job failure.
#
# usage: cadence/day/23-bctx-canary.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
CFG="${BCTX_CONFIG:-$HOME/.config/billion-context/billion-context.json}"
JOB_NAME="${JOB_NAME:-23-bctx-canary}"

file_report() { # kind text identity
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
    --identity "$3" --window 86400 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$1" "$3"
  else
    breadcrumb "$JOB_NAME" "report-failed" "$3 (row failed, data not failure)"
  fi
}

vals="$(BCTX_CFG="$CFG" python3 -c '
import json, os
try:
    c = json.load(open(os.environ["BCTX_CFG"]))["compress"]
    print(c.get("maxContextLimit", ""), c.get("emergencyThresholdPercent", ""),
          c.get("nudgeGrowthTokens", ""))
except Exception:
    pass' 2>/dev/null)"

if [ -z "$vals" ]; then
  file_report alert "bctx config missing: $CFG (drift canary blind — budget unasserted)" \
    "bctx-config-missing"
  exit 0
fi
# shellcheck disable=SC2086 # three whitespace-separated config values
set -- $vals
found="${1:-}" emergency="${2:-}" nudge="${3:-}"
expected="${BCTX_MAX_CONTEXT:-$(get_param bctx-max-context-limit 44%)}"
obs="bctx context budget: expected $expected found $found (emergencyThresholdPercent=$emergency nudgeGrowthTokens=$nudge)"

if [ "$found" = "$expected" ]; then
  file_report progress "$obs — ok (proxy token feed: no readable log found; ratio vital stays transcript-derived)" \
    "bctx-canary-ok"
else
  file_report alert "$obs — DRIFT (record 2026-08-24 chose 40%; Inventory adopted live 2026-09-07 pending operator confirm)" \
    "bctx-config-drift"
fi
exit 0
