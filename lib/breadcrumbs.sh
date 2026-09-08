# breadcrumbs.sh — append structured lines to STATE.md.
# Format: ISO timestamp | job | event | detail  (pipes in detail escaped).
# Requires AUTOMATION_ROOT (set by lib/common.sh, sourced first everywhere).
set -u

STATE_FILE="${STATE_FILE:-$AUTOMATION_ROOT/STATE.md}"

breadcrumb() {
  local job="${1:-}" event="${2:-}" detail="${3:-}"
  detail="${detail//|/¦}"   # keep the 4-field structure intact
  printf '%s | %s | %s | %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$job" "$event" "$detail" >> "$STATE_FILE"
}