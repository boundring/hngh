#!/usr/bin/env bash
# wicket.sh — the hngh privileged-action dispatcher (the wicket). ONE
# exact-command sudoers grant PER ACTION points here
# (config/wicket.sudoers.example); this script is the ONLY thing root
# runs. Actions: install-base (allowlisted against the root-owned
# package manifest WICKET_MANIFEST, default
# /usr/local/lib/hngh/omarchy-base.packages), stage <path> (copy one
# user-owned artifact into the root-owned WICKET_STAGING_DIR, default
# /var/lib/hngh/staging), install-file <name> (one sanitized staged
# file via pacman -U). Fail-closed throughout: unknown argv -> usage
# rc 2; missing/unreadable/empty-transaction manifest, staging
# refusals, pacman absent -> rc 4; pacman rc propagates. Every
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
WICKET_STAGING_DIR="${WICKET_STAGING_DIR:-/var/lib/hngh/staging}"
WICKET_PACMAN_CONF="${WICKET_PACMAN_CONF:-/etc/pacman.conf}"

usage() {
  echo "usage: wicket.sh install-base | wicket.sh stage <path> | wicket.sh install-file <name> | wicket.sh version" >&2
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

# _wicket_run_transaction LABEL CMD ARGS... — run one pacman
# transaction, pass its full output through to the operator, and set
# WICKET_UPGRADES / WICKET_UPGRADE_LIST from `^upgrading <pkg>` lines.
# That is the partial-upgrade drift signal the operator reviews before
# treating the transaction as settled
# (docs/design/omarchy-gap-registry.md partial-upgrade caveat).
_wicket_run_transaction() { # LABEL CMD ARGS...
  local line pkg rc=0 out
  shift
  WICKET_UPGRADES=0
  WICKET_UPGRADE_LIST=""
  out="$("$@" 2>&1)" || rc=$?
  [ -n "$out" ] && printf '%s\n' "$out"
  while IFS= read -r line; do
    case "$line" in
    upgrading\ *)
      pkg="${line#upgrading }"
      pkg="${pkg%%[!a-z0-9._+-]*}" # name runs to the first other char
      pkg="${pkg%%...}"
      pkg="${pkg%.}"
      [ -n "$pkg" ] || continue
      WICKET_UPGRADE_LIST="${WICKET_UPGRADE_LIST:+$WICKET_UPGRADE_LIST,}$pkg"
      WICKET_UPGRADES=$((WICKET_UPGRADES + 1))
      ;;
    esac
  done <<<"$out"
  return "$rc"
}

_wicket_install_base() {
  if [ ! -f "$WICKET_MANIFEST" ] || [ ! -r "$WICKET_MANIFEST" ]; then
    echo "wicket: manifest missing or unreadable: $WICKET_MANIFEST" >&2
    exit 4
  fi
  # Inline parse — NOT a $(...) subshell: skip counts must survive into
  # this shell (the rc=4 refusal reports them). Blank lines and #comment
  # lines skipped. A `# aur` tail is SKIPPED AND COUNTED (AUR builds are
  # a user-session concern, never root). A `# omarchy-repo` tail ships
  # from the signed [omarchy] repo: INCLUDED once that repo is actually
  # configured — WICKET_PACMAN_CONF (default /etc/pacman.conf) exists
  # and carries an uncommented `[omarchy]` section line — because
  # including it earlier (repo absent) would make pacman refuse the
  # WHOLE transaction on target-not-found. Until then: SKIP AND COUNT.
  local line pkg rest pkgs=() n
  WICKET_AUR_SKIPPED=0
  WICKET_OMARCHY_SKIPPED=0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    read -r pkg rest <<<"$line" || true
    case "$pkg" in '' | '#'*) continue ;; esac # blank line, or # comment
    if [ "${rest:-}" = '# aur' ]; then
      WICKET_AUR_SKIPPED=$((WICKET_AUR_SKIPPED + 1))
      continue
    fi
    if [ "${rest:-}" = '# omarchy-repo' ]; then
      if [ -f "$WICKET_PACMAN_CONF" ] &&
        grep -q '^[[:space:]]*\[omarchy\]' "$WICKET_PACMAN_CONF"; then
        pkgs+=("$pkg") # repo live: the line joins the transaction
      else
        WICKET_OMARCHY_SKIPPED=$((WICKET_OMARCHY_SKIPPED + 1))
      fi
      continue
    fi
    pkgs+=("$pkg")
  done <"$WICKET_MANIFEST"
  n=${#pkgs[@]}
  if [ "$n" -eq 0 ]; then
    echo "wicket: manifest admits no installable packages (aur skipped: $WICKET_AUR_SKIPPED, omarchy-repo deferred: $WICKET_OMARCHY_SKIPPED); refusing empty transaction: $WICKET_MANIFEST" >&2
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
  _wicket_run_transaction install-base \
    "$pacman_bin" -Sy --needed --noconfirm "${pkgs[@]}" || rc=$?
  _wicket_log "install-base rc=$rc upgrades=$WICKET_UPGRADES${WICKET_UPGRADE_LIST:+ list=$WICKET_UPGRADE_LIST}"
  exit "$rc"
}

# _wicket_stage PATH — copy one user-readable, user-owned artifact into
# the root-owned staging dir (created on demand, 0755). Staging is the
# ONLY place install-file installs from, so the copy — validated for
# regular-file, readability, non-root ownership, 64MiB cap, sanitized
# basename, no '..' traversal — defines what root may ever see.
# Refusals are rc 4.
_wicket_stage() {
  [ $# -eq 1 ] || {
    usage
    exit 2
  }
  local src="$1" rp owner size base
  case "$src" in
  .. | ../* | */.. | */../*)
    echo "wicket: refusing '..' traversal in path: $src" >&2
    exit 4
    ;;
  esac
  rp="$(realpath -e -- "$src" 2>/dev/null)" || {
    echo "wicket: cannot resolve staged file: $src" >&2
    exit 4
  }
  [ -f "$rp" ] || {
    echo "wicket: not a regular file: $rp" >&2
    exit 4
  }
  [ -r "$rp" ] || {
    echo "wicket: not readable: $rp" >&2
    exit 4
  }
  owner="$(stat -c %u -- "$rp" 2>/dev/null)" || {
    echo "wicket: cannot stat: $rp" >&2
    exit 4
  }
  [ "$owner" -ne 0 ] || {
    echo "wicket: refusing root-owned file: $rp" >&2
    exit 4
  }
  size="$(stat -c %s -- "$rp" 2>/dev/null)" || {
    echo "wicket: cannot stat: $rp" >&2
    exit 4
  }
  [ "$size" -le 67108864 ] || {
    echo "wicket: file exceeds the 64MiB staging cap ($size bytes): $rp" >&2
    exit 4
  }
  base="$(basename -- "$rp")"
  if ! [[ "$base" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
    echo "wicket: refusing unsanitized basename: $base" >&2
    exit 4
  fi
  mkdir -p -m 0755 -- "$WICKET_STAGING_DIR" 2>/dev/null || {
    echo "wicket: cannot create staging dir: $WICKET_STAGING_DIR" >&2
    exit 4
  }
  cp -p -- "$rp" "$WICKET_STAGING_DIR/$base" || {
    echo "wicket: staging copy failed: $rp -> $WICKET_STAGING_DIR/$base" >&2
    exit 4
  }
  _wicket_log "stage file=$base src=$rp"
  echo "staged: $WICKET_STAGING_DIR/$base"
}

# _wicket_install_file NAME — install exactly one staged package file:
# NAME must match the sanitized-basename pattern AND resolve to a real
# regular file INSIDE WICKET_STAGING_DIR (no traversal, no symlink
# escape), then a single `pacman -U --noconfirm --needed` transaction.
# rc 2 misuse (bad name); rc 4 refused (staging/file not resolvable).
_wicket_install_file() {
  [ $# -eq 1 ] || {
    usage
    exit 2
  }
  local name="$1" sd rp pacman_bin rc=0
  if ! [[ "$name" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
    echo "wicket: install-file: bad name (must match ^[a-z0-9][a-z0-9._-]*\$): $name" >&2
    exit 2
  fi
  sd="$(realpath -e -- "$WICKET_STAGING_DIR" 2>/dev/null)" || {
    echo "wicket: staging dir missing: $WICKET_STAGING_DIR" >&2
    exit 4
  }
  rp="$(realpath -e -- "$sd/$name" 2>/dev/null)" || {
    echo "wicket: staged file not found: $sd/$name" >&2
    exit 4
  }
  if [ "$rp" != "$sd/$name" ] || [ ! -f "$rp" ]; then
    echo "wicket: refusing file outside the staging dir: $name" >&2
    exit 4
  fi
  pacman_bin="$(command -v pacman 2>/dev/null)" || {
    echo "wicket: pacman not found" >&2
    exit 4
  }
  _wicket_log "install-file pkg=$name file=$rp"
  _wicket_run_transaction install-file \
    "$pacman_bin" -U --noconfirm --needed "$rp" || rc=$?
  _wicket_log "install-file pkg=$name rc=$rc upgrades=$WICKET_UPGRADES${WICKET_UPGRADE_LIST:+ list=$WICKET_UPGRADE_LIST}"
  exit "$rc"
}

main() {
  if [ $# -lt 1 ]; then
    usage
    exit 2
  fi
  case "$1" in
  version)
    [ $# -eq 1 ] || {
      usage
      exit 2
    }
    echo "hngh-wicket 1"
    ;;
  install-base)
    [ $# -eq 1 ] || {
      usage
      exit 2
    }
    _wicket_install_base
    ;;
  stage)
    shift
    _wicket_stage "$@"
    ;;
  install-file)
    shift
    _wicket_install_file "$@"
    ;;
  *)
    usage
    exit 2
    ;;
  esac
}

main "$@"
