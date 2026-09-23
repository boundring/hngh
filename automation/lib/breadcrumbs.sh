# breadcrumbs.sh — append structured lines to STATE.md.
# Format: ISO timestamp | job | event | detail  (pipes in detail escaped).
# AUTOMATION_ROOT: set by lib/common.sh when sourced first; self-locate
# from this file otherwise (2026-09-23 defect cleanup: an order-dependent
# caller reached here without common.sh and died on set -u).
set -u

AUTOMATION_ROOT="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_FILE="${STATE_FILE:-$AUTOMATION_ROOT/STATE.md}"

breadcrumb() {
  local job="${1:-}" event="${2:-}" detail="${3:-}"
  detail="${detail//|/¦}"     # keep the 4-field structure intact
  detail="${detail//$'\n'/ }" # one line per event: fold newlines (2026-09-20 gate-red multiline leak)
  detail="${detail//$'\r'/ }"
  printf '%s | %s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$job" "$event" "$detail" >>"$STATE_FILE"
}
