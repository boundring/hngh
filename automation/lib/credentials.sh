# credentials.sh — the `op` CLI seam (contract:
# hngh docs/design/credentials-posture.md §2). One consumer-visible
# function: cred_get REF -> secret on stdout, nonzero + empty on any
# failure (the CALLER falls back to its file path). op_ready() is the
# cheap pre-check so a caller can detect a locked/signed-out vault
# BEFORE committing to a path. Values are never logged, echoed to
# stderr, or written anywhere: stdout exists for command substitution
# only. One breadcrumb per UTC day max on failure — a locked vault is
# an operator setup item, never an alert (§4, lib/notify-email.sh).
# Service-account-only (2026-09-13): the token is the ONLY auth path for
# agent `op` usage on this host. When neither env is set we fail soft
# (breadcrumb + nonzero) and never invoke `op` at all — an unset token
# must never fall through to the desktop-app integration, whose locked
# vault demands an interactive password prompt (forbidden for agents).
# Requires lib/common.sh + lib/breadcrumbs.sh sourced first.
set -u
OP_BIN="${HNGH_OP_BIN:-op}"
CRED_STATE_DIR="${CRED_STATE_DIR:-$AUTOMATION_ROOT/logs}"

# Keyed entry (2026-09-12): map the operator's service key onto op's
# service-account env so every consumer is prompt-free and headless —
# the desktop-app integration (which is what demands interactive
# /bin/bash CLI-access grants) is never consulted when the token is set
# (docs/records/2026-09-12-privilege-model.md). Only a non-empty token
# is mapped: an empty export must not shadow the desktop path.
if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] && [ -n "${ONEPASSWORD_SERVICE_KEY:-}" ]; then
  export OP_SERVICE_ACCOUNT_TOKEN="$ONEPASSWORD_SERVICE_KEY"
fi

op_ready() { # -> 0 iff the CLI has a live session
  # Service-account-only: a live token IS a live session. The old
  # whoami/account-list probes are gone — they lied under desktop-app
  # integration and can wedge on a prompt when no token is present
  # (docs/records/2026-09-09-1password-service-account-interface.md).
  [ -n "${OP_SERVICE_ACCOUNT_TOKEN:-}" ] || {
    cred_fallback_crumb "op_ready: no service token"
    return 1
  }
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
  if [ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]; then
    cred_fallback_crumb "$ref"
    return 1
  fi
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
