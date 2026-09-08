# credentials.sh — the `op` CLI seam (contract:
# hngh docs/design/credentials-posture.md §2). One consumer-visible
# function: cred_get REF -> secret on stdout, nonzero + empty on any
# failure (the CALLER falls back to its file path). op_ready() is the
# cheap pre-check so a caller can detect a locked/signed-out vault
# BEFORE committing to a path. Values are never logged, echoed to
# stderr, or written anywhere: stdout exists for command substitution
# only. One breadcrumb per UTC day max on failure — a locked vault is
# an operator setup item, never an alert (§4, lib/notify-email.sh).
# Requires lib/common.sh + lib/breadcrumbs.sh sourced first.
set -u
OP_BIN="${HNGH_OP_BIN:-op}"
CRED_STATE_DIR="${CRED_STATE_DIR:-$AUTOMATION_ROOT/logs}"

op_ready() { # -> 0 iff the CLI has a live session
  "$OP_BIN" whoami >/dev/null 2>&1
}

cred_fallback_crumb() { # ref — one per UTC day max
  local stamp="$CRED_STATE_DIR/.cred-fallback-$(date -u +%F)"
  [ -e "$stamp" ] && return 0
  : >"$stamp" 2>/dev/null || return 0
  breadcrumb credentials fallback "1password unavailable for $1; file fallback"
}

cred_get() { # ref -> secret on stdout; 1 + empty stdout on any failure
  local ref="$1" val
  [ -n "$ref" ] || return 1
  val="$(timeout 45 "$OP_BIN" read "$ref" 2>/dev/null)" || {
    cred_fallback_crumb "$ref"
    return 1
  }
  [ -n "$val" ] || {
    cred_fallback_crumb "$ref"
    return 1
  }
  printf '%s\n' "$val"
}
