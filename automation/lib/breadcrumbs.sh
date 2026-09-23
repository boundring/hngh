# breadcrumbs.sh — append structured lines to STATE.md.
# Format: ISO timestamp | job | event | detail  (pipes in detail escaped).
# AUTOMATION_ROOT: set by lib/common.sh when sourced first; self-locate
# from this file otherwise (2026-09-23 defect cleanup: an order-dependent
# caller reached here without common.sh and died on set -u).
set -u

AUTOMATION_ROOT="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STATE_FILE="${STATE_FILE:-$AUTOMATION_ROOT/STATE.md}"
# the single writer (lib/crumbs.py); overridable for hermetic tests
CRUMBS_WRITER="${CRUMBS_WRITER:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/crumbs.py}"

breadcrumb() {
  local job="${1:-}" event="${2:-}" detail="${3:-}"
  detail="${detail//|/¦}"     # keep the 4-field structure intact
  detail="${detail//$'\n'/ }" # one line per event: fold newlines (2026-09-20 gate-red multiline leak)
  detail="${detail//$'\r'/ }"
  if [ -f "$CRUMBS_WRITER" ]; then
    STATE_FILE="$STATE_FILE" python3 "$CRUMBS_WRITER" "$job" "$event" "$detail" >/dev/null
  else
    # ponytail: standalone-source fallback (this file may be copied alone);
    # upgrade only if a second line implementation ever survives
    printf '%s | %s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$job" "$event" "$detail" >>"$STATE_FILE"
  fi
}
