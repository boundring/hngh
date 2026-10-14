#!/usr/bin/env bash
# night-session — one budget-capped GLM-5.3 wake session, run by systemd
# timers (or by hand for bring-up tests).
# usage: night-session.sh <prompt-file> <label>
# Fail-closed: always exits 0 (systemd oneshot must not retry).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROMPT_ARG="${1:-prompts/night-check.md}"
LABEL="${2:-night-agent}"
MAX_SESSIONS=6
LOGS="$ROOT/logs"
BUDGET="$LOGS/budget.md"

. "$ROOT/lib/common.sh"
. "$ROOT/lib/hngh-record.sh"
. "$ROOT/lib/breadcrumbs.sh"

case "$PROMPT_ARG" in
/*) PROMPT_FILE="$PROMPT_ARG" ;;
*) PROMPT_FILE="$ROOT/$PROMPT_ARG" ;;
esac

mkdir -p "$LOGS"

if [ ! -f "$PROMPT_FILE" ]; then
  breadcrumb "night-session.sh" "refuse" "prompt file missing: $PROMPT_FILE"
  exit 0
fi

# Budget ceiling guard: at most MAX_SESSIONS paid sessions (≈ $30 zai credit)
# PER UTC DAY, counting only this job's own label.
#
# 2026-10-14: the count was `grep -c 'session-run' "$BUDGET"` over the WHOLE
# ledger, which every delegated session writes to. That file holds 803 rows
# (night-agent's own rows are 0 — it has never run), so `count` was always
# >= MAX_SESSIONS and this guard would have refused unconditionally, right
# after the prompt-file guard. Two of three guards in this script were
# fail-closed into permanent refusal and nobody noticed because both exit 0
# and the timers journal success either way.
#
# The per-day shape mirrors the sibling job (scripts/overnight-cycle.sh:107):
# filter to today's UTC date first, then to this label.
today="$(date -u +%Y-%m-%d)"
count="$(grep -F "$today" "$BUDGET" 2>/dev/null | grep -cF " | $LABEL | session-run" || true)"
[ -z "$count" ] && count=0
if [ "$count" -ge "$MAX_SESSIONS" ]; then
  breadcrumb "night-session.sh" "budget-cap" \
    "refusing: $count $LABEL session-run entries today >= $MAX_SESSIONS"
  exit 0
fi

OMP_BIN="$(command -v omp || true)"
[ -z "$OMP_BIN" ] && OMP_BIN="$HOME/.bun/bin/omp"

TS="$(date +%Y%m%dT%H%M%S)"
LOG="$LOGS/night-$LABEL-$TS.log"

cd "$ROOT" || exit 0
timeout 900 "$OMP_BIN" -p --model zai/glm-5.3 "$(cat "$PROMPT_FILE")" \
  >"$LOG" 2>&1
rc=$?

printf '%s | %s | session-run\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$LABEL" >>"$BUDGET"
breadcrumb "night-session.sh" "session" \
  "$LABEL finished rc=$rc log=logs/$(basename "$LOG")"
# Beacon: reflect this scheduled wake in the session store (best-effort).
case "$LABEL" in
night-agent) record_hngh_run "night agent check" ;;
morning-report) record_hngh_run "morning report" ;;
*) record_hngh_run "$LABEL wake" ;;
esac
exit 0
