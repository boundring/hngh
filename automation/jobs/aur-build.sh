#!/usr/bin/env bash
# aur-build.sh <pkg> — the user-session AUR build lane (the `# aur`
# manifest escape hatch, automated). NEVER root, NEVER sudo here:
# (1) AUR RPC v5 info (search fallback with exact-Name rescue +
#     near-miss report on failure); (2) repo-dep gate: `pacman -T
#     <deps>` output must be EMPTY — missing repo deps belong in the
#     phase-1 manifest/wicket lane, not this lane; (3) git clone
#     https://aur.archlinux.org/<pkg>.git into
#     $HNGH_HOME_DIR/db/omarchy/aur/<pkg> (fresh, or verified-origin
#     reuse); (4) `makepkg --noconfirm` in the clone (NEVER
#     -s/--syncdeps — the dep closure is the wicket lane's job);
# (5) stage the built pkg.tar.zst via lib/privileged.sh wicket stage
#     (its rc 3 "wicket not armed:" propagates, stderr verbatim);
# (6) print the staged name + the exact operator follow-up command
#     (privileged.sh wicket install-file <name>).
# Exit: 0 ok; 2 usage; 3 AUR has no such pkg / wicket not armed
#       (propagated); 4 refused (unmet deps, wrong origin, no
#       artifact); git/makepkg rc propagate.
# Seams (hermetic tests): AUR_RPC_URL, GIT_BIN, MAKEPKG_BIN, PACMAN_BIN,
# PRIVILEGED_SH, HNGH_HOME_DIR (curl stubbed via PATH).
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

AUR_RPC_URL="${AUR_RPC_URL:-https://aur.archlinux.org/rpc}"
GIT_BIN="${GIT_BIN:-git}"
MAKEPKG_BIN="${MAKEPKG_BIN:-makepkg}"
PACMAN_BIN="${PACMAN_BIN:-pacman}"
PRIVILEGED_SH="${PRIVILEGED_SH:-$AUTOMATION_ROOT/lib/privileged.sh}"
AUR_DB="${HNGH_HOME_DIR%/}/db/omarchy/aur"

usage() { echo "usage: aur-build.sh <pkg>" >&2; }
[ $# -eq 1 ] || {
  usage
  exit 2
}
PKG="$1"
if ! [[ "$PKG" =~ ^[a-z0-9][a-z0-9._-]*$ ]]; then
  echo "aur-build: bad pkg name: $PKG" >&2
  exit 2
fi

# fetch TYPE — AUR RPC v5 body on stdout; nonzero on transport failure.
fetch() { # TYPE
  local q
  case "$1" in
  search) q="arg=${PKG}" ;;
  *) q="arg[]=${PKG}" ;;
  esac
  curl -fsS --max-time 30 "${AUR_RPC_URL}?v=5&type=$1&${q}"
}

# aur_lookup — sets INFO_JSON (multiinfo body) or exits 3 fail-closed,
# naming near misses (possible renames) on the way out.
aur_lookup() {
  local body count verdict
  body="$(fetch info)" || {
    echo "aur-build: AUR RPC failed for $PKG" >&2
    exit 1
  }
  count="$(printf '%s\n' "$body" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("resultcount", 0))')" ||
    {
      echo "aur-build: unparseable AUR RPC reply for $PKG" >&2
      exit 1
    }
  if [ "$count" -gt 0 ]; then
    INFO_JSON="$body"
    return 0
  fi
  body="$(fetch search)" || {
    echo "aur-build: AUR search failed for $PKG" >&2
    exit 1
  }
  verdict="$(printf '%s\n' "$body" | python3 -c '
import json, sys
pkg = sys.argv[1]
names = [r.get("Name", "") for r in json.load(sys.stdin).get("results") or []]
if pkg in names:
    print("exact")
else:
    print("miss")
    for n in [x for x in names if x][:10]:
        print(n)
' "$PKG")" || {
    echo "aur-build: unparseable AUR search reply for $PKG" >&2
    exit 1
  }
  if [ "$verdict" = "exact" ]; then
    body="$(fetch info)" || {
      echo "aur-build: AUR RPC failed for $PKG" >&2
      exit 1
    }
    INFO_JSON="$body"
    return 0
  fi
  {
    echo "aur-build: AUR has no package '$PKG'"
    echo "aur-build: near misses (check for renames):"
    printf '%s\n' "${verdict#*$'\n'}"
  } >&2
  exit 3
}

# repo-dep gate: every Depends entry must already be satisfied. `-T`
# prints exactly the unsatisfiable ones; output MUST be empty.
aur_check_deps() {
  local deps missing
  deps="$(printf '%s\n' "$INFO_JSON" | python3 -c '
import json, sys
r = (json.load(sys.stdin).get("results") or [{}])[0]
for dep in r.get("Depends") or []:
    print(dep)
')"
  [ -n "$deps" ] || return 0
  missing="$(
    set -f
    "$PACMAN_BIN" -T $deps 2>/dev/null
  )"
  [ -z "$missing" ] || {
    echo "aur-build: unmet repo deps for $PKG (add them to the phase-1 manifest / wicket lane):" >&2
    printf '%s\n' "$missing" >&2
    exit 4
  }
}

# aur_clone — fresh clone, or reuse ONLY when the existing dir's origin
# is exactly this package's AUR repo (anything else fails closed).
aur_clone() {
  local dir="$AUR_DB/$PKG" url="https://aur.archlinux.org/$PKG.git" origin
  if [ -d "$dir" ]; then
    origin="$("$GIT_BIN" -C "$dir" remote get-url origin 2>/dev/null)" || origin=""
    if [ "$origin" != "$url" ]; then
      echo "aur-build: refusing $dir (origin '$origin' != '$url'; wipe it or fix origin)" >&2
      exit 4
    fi
    log "reusing verified clone $dir"
  else
    mkdir -p -- "$AUR_DB" || {
      echo "aur-build: cannot create $AUR_DB" >&2
      exit 4
    }
    "$GIT_BIN" clone "$url" "$dir" || exit $?
  fi
  CLONE_DIR="$dir"
}

aur_build() {
  (cd "$CLONE_DIR" && "$MAKEPKG_BIN" --noconfirm) || exit $?
}

# newest built artifact wins (multi-output builds may emit -debug etc.)
aur_pick_artifact() {
  local f
  BUILT=""
  for f in "$CLONE_DIR"/*.pkg.tar.zst; do
    [ -f "$f" ] || continue
    if [ -z "$BUILT" ] || [ "$f" -nt "$BUILT" ]; then BUILT="$f"; fi
  done
  [ -n "$BUILT" ] || {
    echo "aur-build: no *.pkg.tar.zst in $CLONE_DIR (build produced nothing)" >&2
    exit 4
  }
}

aur_lookup
aur_check_deps
aur_clone
aur_build
aur_pick_artifact

[ -f "$PRIVILEGED_SH" ] || {
  echo "aur-build: privileged seam missing: $PRIVILEGED_SH" >&2
  exit 4
}
"$PRIVILEGED_SH" wicket stage "$BUILT" || exit $?

log "staged $(basename -- "$BUILT")"
printf 'aur-build: staged %s\n' "$(basename -- "$BUILT")"
printf 'aur-build: follow-up: %s wicket install-file %s\n' \
  "$PRIVILEGED_SH" "$(basename -- "$BUILT")"
