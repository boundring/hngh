#!/usr/bin/env bash
# setup-notify-email — the ONE command that stands up the operator email
# channel. Two modes:
#   interactive: prompts for SMTP settings (password hidden);
#   --from-1password "op://<vault>/<item>/<field>": builds the conf from
#     the vault — the password NEVER touches disk (the conf carries the
#     op ref; notify-email.py reads it at send time). username must exist
#     as an item field; host/port default to Gmail (smtp.gmail.com:587)
#     unless item fields host/port exist.
# Both write notify-email.conf chmod 600 (the operator never hand-edits
# files), send a test email via scripts/notify-email.py, and print
# PASS/FAIL. The config is written ONLY here — no other path may create
# or read it (kernel constraint, 2026-09-01).
#
# Idempotent: refuses to overwrite an existing config without --force.
#
# usage: bash scripts/setup-notify-email.sh [--force]
#        bash scripts/setup-notify-email.sh --from-1password "op://<vault>/<item>/<field>"
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONF="${HNGH_NOTIFY_EMAIL_CONF:-$HOME/.hngh-automation/notify-email.conf}"
NOTIFY="$ROOT/scripts/notify-email.py"
OP_BIN="${HNGH_OP_BIN:-op}"
FORCE="${FORCE:-0}"

# --- config writer (the only function other paths may call; sourced in
# tests with the HNGH_NOTIFY_EMAIL_CONF seam pointed at a temp file) ----
write_conf() { # host port user pass from to [opref] -> 0 written / 1 refused
  local host="$1" port="$2" user="$3" pass="$4" from="$5" to="$6" opref="${7:-}"
  if [ -e "$CONF" ] && [ "$FORCE" != "1" ]; then
    printf 'setup-notify-email: %s already exists — rerun with --force to overwrite\n' \
      "$CONF" >&2
    return 1
  fi
  mkdir -p "$(dirname "$CONF")"
  umask 077
  cat >"$CONF" <<EOF
[smtp]
host = $host
port = $port
user = $user
from = $from
to = $to
EOF
  if [ -n "$opref" ]; then
    printf '[1password]\nitem = %s\n' "$opref" >>"$CONF" # pass never on disk
  else
    printf 'pass = %s\n' "$pass" >>"$CONF"
  fi
  chmod 600 "$CONF"
}

ask() { # prompt default -> REPLY (default when empty)
  local r
  read -r -p "$1 [$2]: " r
  REPLY="${r:-$2}"
}

main() {
  [ "${1:-}" = "--force" ] && FORCE=1
  if [ "${1:-}" = "--from-1password" ]; then
    [ -n "${2:-}" ] || {
      printf 'usage: setup-notify-email.sh --from-1password "op://<vault>/<item>/<field>"\n' >&2
      exit 2
    }
    from_1password "$2"
    return
  fi
  if [ -e "$CONF" ] && [ "$FORCE" != "1" ]; then
    printf 'setup-notify-email: %s already exists — rerun with --force to overwrite\n' \
      "$CONF" >&2
    exit 1
  fi
  local host port user pass from to
  ask "SMTP host" "smtp.gmail.com"
  host="$REPLY"
  ask "SMTP port" "587"
  port="$REPLY"
  ask "SMTP user" ""
  user="$REPLY"
  read -rs -p "App password (input hidden): " pass
  printf '\n'
  ask "From address" "$user"
  from="$REPLY"
  ask "To address" "$user"
  to="$REPLY"
  write_conf "$host" "$port" "$user" "$pass" "$from" "$to" || exit 1
  printf 'config written to %s (chmod 600)\n' "$CONF"

  if python3 "$NOTIFY" send \
    --subject "hngh notify-email setup test" \
    --body-text "Setup test from setup-notify-email.sh — if you read this, the email channel works." 2>&1; then
    printf 'PASS: test email sent to %s\n' "$to"
  else
    printf 'FAIL: test email did not send — check host/port/user/app password above\n'
    exit 1
  fi
  case "$host" in
  *gmail*)
    printf 'Gmail: use an app password (myaccount.google.com/apppasswords; requires 2FA), not your login password.\n'
    ;;
  esac
}

from_1password() { # ref -> conf written + test-send; never prompts
  local ref="$1" base user host port
  case "$ref" in
  op://*/*/*) ;;
  *)
    printf 'setup-notify-email: ref must be op://<vault>/<item>/<field>\n' >&2
    exit 2
    ;;
  esac
  if [ -e "$CONF" ] && [ "$FORCE" != "1" ]; then
    printf 'setup-notify-email: %s already exists — rerun with --force to overwrite\n' "$CONF" >&2
    exit 1
  fi
  "$OP_BIN" whoami >/dev/null 2>&1 || {
    printf 'setup-notify-email: 1Password locked or signed out — unlock the 1Password desktop app / run "op signin"\n' >&2
    exit 1
  }
  base="${ref%/*}" # op://<vault>/<item> — username/host/port are sibling fields
  user="$("$OP_BIN" read "$base/username" 2>/dev/null)" || {
    printf 'setup-notify-email: missing piece — item has no readable "username" field (%s/username)\n' "$base" >&2
    exit 1
  }
  host="$("$OP_BIN" read "$base/host" 2>/dev/null)" || host=smtp.gmail.com
  port="$("$OP_BIN" read "$base/port" 2>/dev/null)" || port=587
  # user/from/to all come from the item's username field — nothing guessed
  write_conf "$host" "$port" "$user" "" "$user" "$user" "$ref" || exit 1
  printf 'config written to %s (chmod 600; password sourced from 1Password at send time)\n' "$CONF"
  if python3 "$NOTIFY" send \
    --subject "hngh notify-email setup test" \
    --body-text "Setup test from setup-notify-email.sh — if you read this, the email channel works." 2>&1; then
    printf 'PASS: test email sent to %s\n' "$user"
  else
    printf 'FAIL: test email did not send — Gmail note: use an APP password (myaccount.google.com/apppasswords; requires 2FA), never the account login password\n'
    exit 1
  fi
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then main "$@"; fi
