#!/usr/bin/env bash
# test-omarchy-aur-build.sh — jobs/aur-build.sh, hermetic: the AUR RPC is
# stubbed by a curl seam over fixture JSON (info found / not-found /
# near-miss / search exact-name rescue), git + makepkg + pacman +
# privileged.sh are PATH seams; asserts clone path, EXACT
# `makepkg --noconfirm` argv (no -s/--syncdeps), stage invocation, exit
# codes (0 / 2 / 3 / 4 / transport-failure 1), missing-deps exit 4
# listing. No network, no system mutations, never the real sudo.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
fails=0
ok() { echo "ok: $*"; }
bad() {
 echo "BAD: $*"
 fails=$((fails + 1))
}

JOB="$ROOT/jobs/aur-build.sh"

# --- sandbox seams -------------------------------------------------------------
mkdir -p "$SANDBOX/core" "$SANDBOX/bin" "$SANDBOX/rpc"
for t in bash dirname basename mkdir sed date cat; do
 p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$SANDBOX/core/$t"
done
ln -sf "$(command -v python3)" "$SANDBOX/core/python3"

CORE="$SANDBOX/core"
BIN="$SANDBOX/bin"
RPC_DIR="$SANDBOX/rpc"
HOME_DIR="$SANDBOX/home"

# curl stub: maps the RPC url to RPC_DIR/<type>-<pkg>.json
cat >"$BIN/curl" <<'STUB'
#!/usr/bin/env bash
url=""
for a in "$@"; do
 case "$a" in *type=*) url="$a" ;; esac
done
case "$url" in
 *type=search*) pkg="$(printf '%s' "$url" | sed -n 's/.*[?&]arg=\([^&]*\).*/\1/p')" type=search ;;
 *) pkg="$(printf '%s' "$url" | sed -n 's/.*arg\[\]=\([^&]*\).*/\1/p')" type=info ;;
esac
printf '%s\n' "curl $*" >>"$CURL_LOG"
f="$RPC_DIR/$type-$pkg.json"
[ -f "$f" ] || {
 echo "curl-stub: no fixture: $f" >&2
 exit 22
}
cat "$f"
STUB

# git stub: records argv; clone materializes a minimal repo dir
cat >"$BIN/git" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "git $*" >>"$GIT_LOG"
if [ "$1" = "clone" ]; then
 mkdir -p "$3"
 printf '%s\n' "$2" >"$3/.origin"
 printf 'PKGBUILD placeholder\n' >"$3/PKGBUILD"
 exit 0
fi
if [ "$1" = "-C" ] && [ "${3:-}" = "remote" ]; then
 [ -f "$2/.origin" ] && {
  cat "$2/.origin"
  exit 0
 }
 exit 128
fi
exit 1
STUB

# makepkg stub: records argv + cwd, drops a fake artifact in the cwd
cat >"$BIN/makepkg" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "makepkg $* cwd=$PWD" >>"$MAKEPKG_LOG"
: >"${MAKEPKG_STUB_NAME:-fake-1.0-1-x86_64.pkg.tar.zst}"
exit "${MAKEPKG_RC:-0}"
STUB

# pacman stub: records argv; PACMAN_T_MISSING lists unsatisfied deps
cat >"$BIN/pacman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "pacman $*" >>"$PACMAN_LOG"
[ -n "${PACMAN_T_MISSING:-}" ] && printf '%s\n' ${PACMAN_T_MISSING}
exit 0
STUB

# privileged.sh stub: records argv; PRIV_STUB_RC simulates not-armed
cat >"$BIN/privileged-stub" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "priv $*" >>"$PRIV_LOG"
if [ "${PRIV_STUB_RC:-0}" -ne 0 ]; then
 echo "wicket not armed: stub-seam has no grant" >&2
 exit "$PRIV_STUB_RC"
fi
exit 0
STUB
chmod +x "$BIN/curl" "$BIN/git" "$BIN/makepkg" "$BIN/pacman" "$BIN/privileged-stub"

# --- fixtures (AUR RPC v5 shapes; no invented fields) ---------------------------
printf '%s\n' '{"version":5,"type":"multiinfo","resultcount":1,"results":[{"Name":"owe","Depends":["mpv","ffmpeg","libglvnd"]}]}' >"$RPC_DIR/info-owe.json"
printf '%s\n' '{"version":5,"type":"multiinfo","resultcount":0,"results":[]}' >"$RPC_DIR/info-zed.json"
printf '%s\n' '{"version":5,"type":"search","resultcount":2,"results":[{"Name":"owe-wallpaper"},{"Name":"owe-git"}]}' >"$RPC_DIR/search-zed.json"
printf '%s\n' '{"version":5,"type":"multiinfo","resultcount":0,"results":[]}' >"$RPC_DIR/info-renamed.json"
printf '%s\n' '{"version":5,"type":"search","resultcount":2,"results":[{"Name":"owf"},{"Name":"renamed"}]}' >"$RPC_DIR/search-renamed.json"

# --- runner: fresh logs per case, err/out captured ------------------------------
job_run() {
 : >"$SANDBOX/curl.log"
 : >"$SANDBOX/git.log"
 : >"$SANDBOX/makepkg.log"
 : >"$SANDBOX/pacman.log"
 : >"$SANDBOX/priv.log"
 HNGH_HOME_DIR="$HOME_DIR" PRIVILEGED_SH="$BIN/privileged-stub" \
  GIT_LOG="$SANDBOX/git.log" CURL_LOG="$SANDBOX/curl.log" \
  MAKEPKG_LOG="$SANDBOX/makepkg.log" PACMAN_LOG="$SANDBOX/pacman.log" \
  PRIV_LOG="$SANDBOX/priv.log" RPC_DIR="$RPC_DIR" \
  PATH="$CORE:$BIN" \
  "$JOB" "$1" >"$SANDBOX/out" 2>"$SANDBOX/err"
}

# --- (a) happy path: info hit, deps ok, clone, build, stage --------------------
job_run owe
rc=$?
CLONE="$HOME_DIR/db/omarchy/aur/owe"
if [ "$rc" -eq 0 ]; then
 ok "happy: exit 0"
else
 bad "happy rc=$rc; err: $(cat "$SANDBOX/err")"
fi
[ "$(cat "$SANDBOX/git.log")" = "git clone https://aur.archlinux.org/owe.git $CLONE" ] &&
 ok "happy: fresh clone into db/omarchy/aur/owe" ||
 bad "clone got: $(cat "$SANDBOX/git.log")"
[ "$(cat "$SANDBOX/makepkg.log")" = "makepkg --noconfirm cwd=$CLONE" ] &&
 ok "happy: EXACT makepkg argv (no -s/--syncdeps, no sudo)" ||
 bad "makepkg got: $(cat "$SANDBOX/makepkg.log")"
[ "$(cat "$SANDBOX/priv.log")" = "priv wicket stage $CLONE/fake-1.0-1-x86_64.pkg.tar.zst" ] &&
 ok "happy: staged built artifact via privileged seam" ||
 bad "stage got: $(cat "$SANDBOX/priv.log")"
[ -f "$CLONE/PKGBUILD" ] &&
 ok "happy: clone dir materialized" ||
 bad "clone dir missing PKGBUILD"
grep -q "aur-build: staged fake-1.0-1-x86_64.pkg.tar.zst" "$SANDBOX/out" &&
 grep -q "aur-build: follow-up: $BIN/privileged-stub wicket install-file fake-1.0-1-x86_64.pkg.tar.zst" "$SANDBOX/out" &&
 ok "happy: staged name + follow-up command printed" ||
 bad "operator output got: $(cat "$SANDBOX/out")"

# --- (b) not found + near-miss names in failure, no clone/build ----------------
job_run zed
rc=$?
if [ "$rc" -eq 3 ]; then
 ok "near-miss: exit 3 fail-closed"
else
 bad "near-miss rc=$rc"
fi
grep -q "AUR has no package 'zed'" "$SANDBOX/err" &&
 ok "near-miss: failure names the package" ||
 bad "near-miss err: $(cat "$SANDBOX/err")"
grep -q "owe-wallpaper" "$SANDBOX/err" &&
 grep -q "owe-git" "$SANDBOX/err" &&
 ok "near-miss: search fallback surfaces close names" ||
 bad "near-miss list: $(cat "$SANDBOX/err")"
[ ! -s "$SANDBOX/git.log" ] && [ ! -s "$SANDBOX/makepkg.log" ] &&
 ok "near-miss: no clone, no build attempted" ||
 bad "near-miss ran git/makepkg"

# --- (c) search exact-Name rescue (renamed package) ----------------------------
job_run renamed
rc=$?
[ "$rc" -eq 0 ] &&
 [ "$(cat "$SANDBOX/git.log")" = "git clone https://aur.archlinux.org/renamed.git $HOME_DIR/db/omarchy/aur/renamed" ] &&
 [ -s "$SANDBOX/makepkg.log" ] &&
 ok "rescue: info NOT FOUND but search exact-Name builds" ||
 bad "rescue rc=$rc git=$(cat "$SANDBOX/git.log")"

# --- (d) missing deps gate: exit 4, list, before clone/build -------------------
PACMAN_T_MISSING="mpv libglvnd" job_run owe
rc=$?
[ "$rc" -eq 4 ] &&
 ok "deps: unmet deps exit 4" ||
 bad "deps rc=$rc"
grep -q "unmet repo deps for owe" "$SANDBOX/err" &&
 grep -qx "mpv" "$SANDBOX/err" &&
 grep -qx "libglvnd" "$SANDBOX/err" &&
 ok "deps: missing list printed" ||
 bad "deps err: $(cat "$SANDBOX/err")"
[ ! -s "$SANDBOX/git.log" ] && [ ! -s "$SANDBOX/makepkg.log" ] &&
 ok "deps: gate fires before clone/build" ||
 bad "deps: git/makepkg ran"

# --- (e) privileged seam not armed: rc 3 + law stderr --------------------------
PRIV_STUB_RC=3 job_run owe
rc=$?
[ "$rc" -eq 3 ] &&
 ok "not armed: rc 3 propagated" ||
 bad "not-armed rc=$rc"
grep -q "^wicket not armed:" "$SANDBOX/err" &&
 ok "not armed: law stderr prefix" ||
 bad "not-armed err: $(cat "$SANDBOX/err")"

# --- (f) verified-origin reuse (no re-clone) -----------------------------------
mkdir -p "$CLONE"
printf '%s\n' "https://aur.archlinux.org/owe.git" >"$CLONE/.origin"
printf 'PKGBUILD placeholder\n' >"$CLONE/PKGBUILD"
job_run owe
rc=$?
[ "$rc" -eq 0 ] &&
 [ "$(cat "$SANDBOX/git.log")" = "git -C $CLONE remote get-url origin" ] &&
 ok "reuse: verified origin, no re-clone" ||
 bad "reuse rc=$rc git=$(cat "$SANDBOX/git.log")"

# --- (g) wrong-origin clone dir refused ----------------------------------------
printf '%s\n' "https://example.com/evil.git" >"$CLONE/.origin"
job_run owe
rc=$?
[ "$rc" -eq 4 ] &&
 grep -q "refusing $CLONE" "$SANDBOX/err" &&
 ok "reuse: wrong origin refused rc 4" ||
 bad "wrong-origin rc=$rc err=$(cat "$SANDBOX/err")"

# --- (h) usage / misuse / transport --------------------------------------------
PATH="$CORE:$BIN" HNGH_HOME_DIR="$HOME_DIR" RPC_DIR="$RPC_DIR" \
 "$JOB" >"$SANDBOX/out" 2>"$SANDBOX/err"
[ "$?" -eq 2 ] && ok "usage: no argv rc 2" || bad "usage rc"
job_run "../evil"
[ "$?" -eq 2 ] && ok "misuse: bad pkg name rc 2" || bad "badname rc"
job_run ghost # no fixture -> curl exit 22 -> transport failure
rc=$?
[ "$rc" -eq 1 ] &&
 grep -q "AUR RPC failed" "$SANDBOX/err" &&
 ok "transport: RPC failure -> exit 1" ||
 bad "transport rc=$rc err=$(cat "$SANDBOX/err")"

# --- summary -------------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
 echo "PASS: test-omarchy-aur-build"
 exit 0
fi
echo "FAIL: test-omarchy-aur-build ($fails)"
exit 1
