#!/usr/bin/env bash
# refresh-dashboard — regenerate dashboard/data.json from current artifacts
# (digests + morning report + STATE breadcrumbs). Used by the morning-report
# service after the 07:30 agent session exits. Fail-closed: exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

update_dashboard "${1:-manual}" "$(date +%F)" "$(date +%H%M)"

# live spine for the webapp panels (timeline/queue/lanes/roster/reports) —
# pure reader over the hngh repo + stores; fails closed (exits 0 even if
# the reader is unavailable).
if [ -x "$HNGH_HOME/scripts/dashboard-readout" ]; then
  # per-PID tmp — never share with the 30m 05-readout.sh writer (rename
  # breaks a sibling's open fd; see 2026-09-01 feed-valid:readout alert)
  tmp="$AUTOMATION_ROOT/dashboard/.readout.json.$$.tmp"
  if (cd "$HNGH_HOME" && python3 scripts/dashboard-readout --json \
    >"$tmp" 2>/dev/null) && mv "$tmp" "$AUTOMATION_ROOT/dashboard/readout.json"; then
    breadcrumb "refresh-dashboard.sh" "spine" "readout.json refreshed ($(wc -c <"$AUTOMATION_ROOT/dashboard/readout.json" 2>/dev/null) bytes)"
  else
    rm -f "$tmp"
    breadcrumb "refresh-dashboard.sh" "spine" "reader failed; leaving prior readout.json"
  fi
fi

# live session observatory feed — roster rows + per-session transcript tails
# (jobs/sessions-feed.py). Fail-closed: enrichment failure degrades rows to
# detail:null; a missing readout leaves the prior sessions.json untouched.
if python3 "$AUTOMATION_ROOT/jobs/sessions-feed.py" 2>/dev/null; then
  breadcrumb "refresh-dashboard.sh" "sessions-feed" "sessions.json refreshed ($(wc -c <"$AUTOMATION_ROOT/dashboard/sessions.json" 2>/dev/null) bytes)"
else
  breadcrumb "refresh-dashboard.sh" "sessions-feed" "feed failed; leaving prior sessions.json"
fi

# operator-item lifecycle feed (open -> handled) — jobs/operator-items-feed.py.
# Fail-closed: a failure leaves the prior operator-items.json untouched.
if python3 "$AUTOMATION_ROOT/jobs/operator-items-feed.py" 2>/dev/null; then
  breadcrumb "refresh-dashboard.sh" "operator-items-feed" "operator-items.json refreshed ($(wc -c <"$AUTOMATION_ROOT/dashboard/operator-items.json" 2>/dev/null) bytes)"
else
  breadcrumb "refresh-dashboard.sh" "operator-items-feed" "feed failed; leaving prior operator-items.json"
fi

# knowledge-base snapshot feed — jobs/kb-feed.py. Snapshots
# ~/.llm-wiki/wiki/sources into dashboard/kb/ for the KB tab. Fail-closed per
# file; a feed failure leaves the prior kb/ snapshot untouched.
if python3 "$AUTOMATION_ROOT/jobs/kb-feed.py" 2>/dev/null; then
  breadcrumb "refresh-dashboard.sh" "kb-feed" "kb snapshot refreshed ($(wc -c <"$AUTOMATION_ROOT/dashboard/kb/index.json" 2>/dev/null) bytes index)"
else
  breadcrumb "refresh-dashboard.sh" "kb-feed" "feed failed; leaving prior kb/ snapshot"
fi
exit 0
