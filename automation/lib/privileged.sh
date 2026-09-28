#!/usr/bin/env bash
# privileged.sh — the user-side seam to the wicket (privileged channel).
# Pinned contract: `privileged.sh wicket <action>`
#   exit 0          success;
#   exit 3          wicket not armed: stderr starts exactly
#                   `wicket not armed:` followed by the operator
#                   bootstrap block (copy-paste window);
#   other non-zero  refused/failed action; stderr carries the one-line
#                   reason (sudo's refusal or the dispatcher's).
# The armed check reads sudo's OWN view of the grant (never prompts,
# fail-soft on rc and timing); enforcement stays with sudoers. Nothing
# here is policy — this file only routes and reports.
# Bootstrap block single-sourced with config/wicket.sudoers.example by
# cross-reference: edit both or neither.
set -u

WICKET_BIN="${WICKET_BIN:-/usr/local/lib/hngh/wicket.sh}"

usage() {
  echo "usage: privileged.sh wicket <action>   # actions: install-base, stage <path>, install-file <name>, version" >&2
}

# _pv_armed — 0 iff sudo lists any exact wicket grant for this user.
# `sudo -n` NEVER prompts (rc != 0 when a password would be required ->
# not armed); timeout guards a hung sudoer. Fail-soft everywhere.
_pv_armed() {
  command -v sudo >/dev/null 2>&1 || return 1
  local out
  out="$(timeout 10 sudo -n -l -U "$(id -un)" 2>/dev/null)" || return 1
  printf '%s\n' "$out" | grep -qE 'wicket\.sh (install-base|stage|install-file)'
}

_pv_bootstrap_block() {
  cat <<'EOF'
  cd <hngh repo root>
  sudo install -D -o root -g root -m 0755 automation/lib/wicket.sh /usr/local/lib/hngh/wicket.sh
  sudo install -o root -g root -m 0444 automation/config/omarchy-base.packages /usr/local/lib/hngh/omarchy-base.packages
  visudo -cf automation/config/wicket.sudoers.example && \
    sudo install -m 0440 automation/config/wicket.sudoers.example /etc/sudoers.d/hngh-wicket
EOF
}

# _pv_crumb — best-effort journal crumb via lib/breadcrumbs.sh when it
# exists. Never blocks: a missing/failing journal is not a failed seam.
_pv_crumb() { # event detail
  local b="${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)}/lib/breadcrumbs.sh"
  [ -f "$b" ] || return 0
  # shellcheck disable=SC1090
  . "$b" >/dev/null 2>&1 || return 0
  breadcrumb wicket "$1" "$2" >/dev/null 2>&1 || true
}

if [ $# -lt 1 ] || [ "$1" != "wicket" ]; then
  usage
  exit 2
fi
shift
if [ $# -lt 1 ]; then
  usage
  exit 2
fi

if ! _pv_armed; then
  {
    echo "wicket not armed: no sudoers grant for $WICKET_BIN (install-base | stage | install-file)."
    echo "One-time operator bootstrap (repo root):"
    _pv_bootstrap_block
  } >&2
  exit 3
fi

rc=0
sudo -n "$WICKET_BIN" "$@" || rc=$?
_pv_crumb "wicket-run" "action=$1 rc=$rc"
exit "$rc"
