#!/usr/bin/env bash
# wicket.sh — the hngh privileged-action dispatcher (the wicket). ONE
# exact-command sudoers grant points here (config/wicket.sudoers.example);
# this script is the ONLY thing root runs, and it allowlists actions
# against a root-owned package manifest (WICKET_MANIFEST, default
# /usr/local/lib/hngh/omarchy-base.packages). Fail-closed throughout:
# unknown argv -> usage rc 2; missing/unreadable/empty-transaction
# manifest -> rc 4; pacman absent -> rc 4; pacman rc propagates. Every
# execution is logged (logger -t hngh-wicket, best-effort; WICKET_LOG
# file sink overrides for hermetic tests).
#
# ponytail: the root-owned manifest pins the package SET, but Arch
# packages may carry install scripts, so this channel is
# trust-on-manifest — upgrade later by pinning hashes/keywords in the
# manifest if the operator asks.
#
# Designed to run as root via sudo in production; must also behave under
# the hermetic suite as a plain user (stubs via PATH + env). No prompts
# ever: --noconfirm is mandatory in the exec'd pacman line.
set -u

WICKET_MANIFEST="${WICKET_MANIFEST:-/usr/local/lib/hngh/omarchy-base.packages}"

usage() {
  echo "usage: wicket.sh install-base | wicket.sh version" >&2
}

# _wicket_log MSG — one audit line per execution. Sink: WICKET_LOG file
# when set (hermetic tests), else syslog via logger. Best-effort either
# way: logging must never block the action.
_wicket_log() {
  if [ -n "${WICKET_LOG:-}" ]; then
    printf '%s\n' "$1" >>"$WICKET_LOG" 2>/dev/null || true
  else
    logger -t hngh-wicket "$1" 2>/dev/null || true
  fi
}

# _wicket_parse FILE — prints installable packages one per line; sets
# WICKET_AUR_SKIPPED. Blank lines and # comments skipped; a line whose
# tail is `# aur` is SKIPPED AND COUNTED (AUR builds are a user-session
# concern, never root).
_wicket_parse() { # FILE
  WICKET_AUR_SKIPPED=0
  local line pkg rest
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    read -r pkg rest <<<"$line" || true
    case "$pkg" in '' | '#'*) continue ;; esac # blank line, or # comment
    if [ "${rest:-}" = '# aur' ]; then
      WICKET_AUR_SKIPPED=$((WICKET_AUR_SKIPPED + 1))
      continue
    fi
    printf '%s\n' "$pkg"
  done <"$1"
}

_wicket_install_base() {
  if [ ! -f "$WICKET_MANIFEST" ] || [ ! -r "$WICKET_MANIFEST" ]; then
    echo "wicket: manifest missing or unreadable: $WICKET_MANIFEST" >&2
    exit 4
  fi
  local parsed pkgs=() n=0
  WICKET_AUR_SKIPPED=0 # set inside the parse subshell; init for set -u
  parsed="$(_wicket_parse "$WICKET_MANIFEST")"
  if [ -n "$parsed" ]; then
    while IFS= read -r n; do pkgs+=("$n"); done <<<"$parsed"
  fi
  n=${#pkgs[@]}
  if [ "$n" -eq 0 ]; then
    echo "wicket: manifest admits no installable packages (aur skipped: $WICKET_AUR_SKIPPED); refusing empty transaction: $WICKET_MANIFEST" >&2
    exit 4
  fi
  local pacman_bin
  pacman_bin="$(command -v pacman 2>/dev/null)" || {
    echo "wicket: pacman not found" >&2
    exit 4
  }
  _wicket_log "install-base pkgs=$n manifest=$WICKET_MANIFEST"
  # single transaction: one -Sy pass with --needed only — never a bare
  # -Sy per package (partial-upgrade hazard)
  local rc=0
  "$pacman_bin" -Sy --needed --noconfirm "${pkgs[@]}" || rc=$?
  _wicket_log "install-base rc=$rc"
  exit "$rc"
}

main() {
  if [ $# -ne 1 ]; then
    usage
    exit 2
  fi
  case "$1" in
  version) echo "hngh-wicket 1" ;;
  install-base) _wicket_install_base ;;
  *)
    usage
    exit 2
    ;;
  esac
}

main "$@"
