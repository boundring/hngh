#!/usr/bin/env bash
# vip-gate.sh — midnight gate + defer guard for heavy Unsloth runs
# (hngh-vip: model-bench.sh, night-research.sh).
#
# Two checks, in order:
#   1. Midnight gate: heavy runs proceed only inside the overnight window
#      (default 00:00-05:00 local). Outside it -> defer (breadcrumb, exit 0
#      at the caller). Keeps daytime GPU/host free for sessions.
#   2. Defer guard: consume the wired beat-skip verdict file written by the
#      Jev beat-skip gate (lib/model.sh writes $AUTOMATION_ROOT/tmp-beatskip.txt
#      with "skip" or "keep", 30s cache). Verdict "skip" -> defer even inside
#      the window (operator is active). Missing/stale/unreadable file is
#      fail-open: the midnight gate alone decides, never this guard.
#
# Usage in a job (after common.sh + breadcrumbs.sh):
#   . "$AUTOMATION_ROOT/lib/vip-gate.sh"
#   if ! vip_gate; then exit 0; fi   # deferred: breadcrumb already written
#
# Test seams (env overrides): VIP_BEATSKIP_FILE, VIP_WINDOW_START/END
# ("HHMM"), VIP_NOW_HHMM (default: current local time), VIP_STATE_FILE.
# Requires: AUTOMATION_ROOT (lib/common.sh), breadcrumb() (lib/breadcrumbs.sh).
set -u

VIP_BEATSKIP_FILE="${VIP_BEATSKIP_FILE:-$AUTOMATION_ROOT/tmp-beatskip.txt}"
VIP_WINDOW_START="${VIP_WINDOW_START:-0000}"
VIP_WINDOW_END="${VIP_WINDOW_END:-0500}"

vip_now_hhmm() { # -> HHMM, seam VIP_NOW_HHMM
  if [ -n "${VIP_NOW_HHMM:-}" ]; then
    printf '%s' "$VIP_NOW_HHMM"
  else
    date +%H%M
  fi
}

vip_in_window() { # -> 0 inside the midnight window
  local now="${1:-$(vip_now_hhmm)}"
  if [ "$VIP_WINDOW_START" -le "$VIP_WINDOW_END" ]; then
    [ "$now" -ge "$VIP_WINDOW_START" ] && [ "$now" -lt "$VIP_WINDOW_END" ]
  else
    # wraps midnight, e.g. 2300-0500
    [ "$now" -ge "$VIP_WINDOW_START" ] || [ "$now" -lt "$VIP_WINDOW_END" ]
  fi
}

vip_skip_verdict() { # -> 0 when the verdict file says "skip"
  local f="${1:-$VIP_BEATSKIP_FILE}" v
  [ -r "$f" ] || return 1
  v="$(cat "$f" 2>/dev/null)" || return 1
  [ "$v" = "skip" ]
}

vip_gate() { # [job] -> 0 proceed, 1 defer (breadcrumb written on defer)
  local job="${1:-${JOB_NAME:-vip}}" now
  now="$(vip_now_hhmm)"
  if ! vip_in_window "$now"; then
    breadcrumb "$job" "vip-defer" \
      "midnight gate: now $now outside $VIP_WINDOW_START-$VIP_WINDOW_END — heavy run deferred"
    return 1
  fi
  if vip_skip_verdict; then
    breadcrumb "$job" "vip-defer" \
      "defer guard: beat-skip verdict is skip ($VIP_BEATSKIP_FILE) — heavy run deferred"
    return 1
  fi
  return 0
}
