# prereqs.sh — the one prerequisite validator. bootstrap.sh and
# scripts/hngh-omp-update.sh both source this (peer-review finding 1: one
# env-contract validation, no copy-paste). Never installs anything; never
# touches secrets.
set -u

# tool -> system package name (different only where it differs).
prereq_pkg() { # tool -> pkg
  case "$1" in
  flock) echo util-linux ;;
  sqlite3) echo sqlite ;;
  python3) echo python ;;
  *) echo "$1" ;;
  esac
}

# missing_bins TOOL... -> one missing tool name per line on stdout
# (empty iff all present).
missing_bins() {
  local t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || printf '%s\n' "$t"
  done
}

# require_bins TOOL... -> prints each missing tool with its system package;
# return 0 iff nothing missing. Guidance goes to stderr, "ok:" to stdout.
require_bins() {
  local t m=0
  for t in "$@"; do
    if command -v "$t" >/dev/null 2>&1; then
      echo "ok: $t"
    else
      echo "missing: $t  (system package: $(prereq_pkg "$t"))" >&2
      m=1
    fi
  done
  if [ "$m" -ne 0 ]; then
    echo "install the missing ones with your system package manager, e.g.:" >&2
    echo "  pacman -S <pkg>... | apt install <pkg>... | dnf install <pkg>..." >&2
    return 1
  fi
  return 0
}
