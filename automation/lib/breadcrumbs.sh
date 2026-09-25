# breadcrumbs.sh — append structured crumbs to the journal db.
# Format: ISO timestamp | job | event | detail  (pipes in detail escaped).
# AUTOMATION_ROOT: set by lib/common.sh when sourced first; self-locate
# from this file otherwise (2026-09-23 defect cleanup: an order-dependent
# caller reached here without common.sh and died on set -u).
set -u

AUTOMATION_ROOT="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_FILE="${STATE_FILE:-$AUTOMATION_ROOT/STATE.md}"
# the single writer (lib/crumbs.py); overridable for hermetic tests
CRUMBS_WRITER="${CRUMBS_WRITER:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/crumbs.py}"
CRUMBS_DB="${HNGH_CRUMBS_DB:-$AUTOMATION_ROOT/state/crumbs.db}"

breadcrumb() {
  local job="${1:-}" event="${2:-}" detail="${3:-}"
  detail="${detail//|/¦}"     # keep the 4-field structure intact
  detail="${detail//$'\n'/ }" # one line per event: fold newlines (2026-09-20 gate-red multiline leak)
  detail="${detail//$'\r'/ }"
  if [ ! -f "$CRUMBS_WRITER" ]; then
    echo "breadcrumbs: writer missing: $CRUMBS_WRITER" >&2
    return 1
  fi
  python3 "$CRUMBS_WRITER" --db "$CRUMBS_DB" "$job" "$event" "$detail" >/dev/null
}

# gate_refusal — R8 (refoundation P3c): a gate refusal is a state change.
# Every gate that blocks a session writes the spine (one crumb) plus one
# deduped report row (identity gate-refusal:<gate>, 7d window; same
# identity+cause rings once, not x79) naming the cheaper tier it defers
# to. Fail-open and SILENT: reporting must never block the gate, and no
# output may escape (pacers run inside command substitution where stdout
# is the "used cap" protocol). HNGH_REPORT_QUEUE overrides the
# report-queue path for hermetic tests. Optional lane=<id> 4th arg lets
# run-autonomous's course picker schedule the refused lane first.
gate_refusal() { # gate detail tier [lane]
  local gate="${1:-}" detail="${2:-}" tier="${3:-}" lane="${4:-}" rq
  [ -n "$gate" ] || return 0
  breadcrumb gate "gate-refusal" \
    "$gate: $detail -- defers to $tier${lane:+ (lane=$lane)}" >/dev/null 2>&1 || true
  rq="${HNGH_REPORT_QUEUE:-$(cd "$AUTOMATION_ROOT/.." && pwd)/scripts/report-queue}"
  [ -x "$rq" ] || return 0
  "$rq" --add alert --identity "gate-refusal:$gate" --window 604800 \
    "gate refusal: $gate: $detail; defers to $tier${lane:+; lane=$lane}" \
    >/dev/null 2>&1 || true
}
