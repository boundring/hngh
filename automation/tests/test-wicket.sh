#!/usr/bin/env bash
# test-wicket.sh — the wicket privileged channel, hermetic (sandboxed
# manifest/pacman/logger/sudo via PATH + env; no network, no system
# mutations, NEVER the real sudo). Covers:
# (a) dispatcher CLI: version; usage rc 2 on unknown argv / no argv;
# (b) manifest law: happy path builds EXACTLY one `pacman -Sy --needed
#     --noconfirm <pkgs>` argv in manifest order; `# aur` lines skipped
#     and counted; `# omarchy-repo` lines join the transaction only when
#     WICKET_PACMAN_CONF carries an uncommented `[omarchy]` section,
#     else skipped+counted (deferred rc 4); aur-only / comment-only /
#     empty manifest refuse rc 4; missing / unreadable manifest rc 4;
# (c) tooling fail-closed: pacman absent rc 4;
# (d) audit sink: logger absent -> still success; logger stub -> pkgs
#     line; WICKET_LOG file sink -> pkgs + rc lines;
# (e) sudoers template: exactly three per-action grants (install-base,
#     stage, install-file) naming dispatcher+subcommand, no
#     NOPASSWD:ALL, visudo -cf parses;
# (f) privileged.sh seam: not armed -> stderr starts `wicket not armed:`
#     plus the bootstrap block, rc 3; armed -> stub sudo execed with the
#     exact dispatcher argv, best-effort crumb fires; action failure rc
#     propagates; armed via the stage grant alone; usage rc 2;
# (g) stage lane: happy copy (mode preserved, audit line), refusals
#     (dir-as-file, absent, root-owned, >64MiB, bad basename, '..'
#     traversal), rc 4 law;
# (h) install-file: EXACT `pacman -U --noconfirm --needed <staged>`
#     argv, happy audit lines, refusals (bad name rc 2, absent /
#     symlink-escape rc 4, no-arg usage rc 2);
# (i) upgrading-signal extraction: canned pacman output with
#     `upgrading foo` -> upgrades=1 list=foo; without -> upgrades=0;
#     pacman rc propagates through the captured-output path.
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

WICKET="$ROOT/lib/wicket.sh"
PV="$ROOT/lib/privileged.sh"
SUDOERS_TMPL="$ROOT/config/wicket.sudoers.example"

# --- sandbox: minimal core tools + stubs, composed per case ------------------
mkdir -p "$SANDBOX/core" "$SANDBOX/pac" "$SANDBOX/log" "$SANDBOX/sud"
for t in bash id timeout grep cat dirname visudo; do
 p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$SANDBOX/core/$t"
done
for t in realpath stat cp mkdir basename truncate; do
 p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$SANDBOX/core/$t"
done
ln -sf "$(command -v python3)" "$SANDBOX/core/python3" # crumbs writer needs it

# pacman stub: records full argv, configurable rc
cat >"$SANDBOX/pac/pacman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "pacman $*" >>"$PACMAN_LOG"
[ -n "${PACMAN_OUT:-}" ] && cat "$PACMAN_OUT"
exit "${PACMAN_RC:-0}"
STUB
chmod +x "$SANDBOX/pac/pacman"

# logger stub: records the argv it was handed
cat >"$SANDBOX/log/logger" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$LOGGER_LOG"
STUB
chmod +x "$SANDBOX/log/logger"

# sudo stub: `sudo -n -l -U ...` answers per SUDO_ARMED; the exec path
# records argv and exits SUDO_EXEC_RC
cat >"$SANDBOX/sud/sudo" <<'STUB'
#!/usr/bin/env bash
if [ "$1" = "-n" ] && [ "$2" = "-l" ]; then
  printf '%s\n' "sudo-list $*" >>"$SUDO_LOG"
  if [ "${SUDO_ARMED:-0}" = "1" ]; then
    printf '%s\n' "$SUDO_LIST_OUT"
    exit 0
  fi
  exit "${SUDO_LIST_RC:-1}"
fi
printf '%s\n' "sudo-exec $*" >>"$SUDO_EXEC_LOG"
exit "${SUDO_EXEC_RC:-0}"
STUB
chmod +x "$SANDBOX/sud/sudo"

# crumbs.py stub: breadcrumbs.sh runs `python3 CRUMBS_WRITER --db DB job event detail`
cat >"$SANDBOX/crumbstub.py" <<'STUB'
import sys
with open(sys.argv[2], "a") as f:
    f.write(" ".join(sys.argv[2:]) + "\n")
STUB

CORE="$SANDBOX/core"
PATH_NO_PAC="$CORE:$SANDBOX/log"
PATH_NO_LOG="$CORE:$SANDBOX/pac"
PATH_FULL="$CORE:$SANDBOX/pac:$SANDBOX/log"

# --- fixtures ----------------------------------------------------------------
MIXED="$SANDBOX/mixed.packages"
cat >"$MIXED" <<'EOF'
# sandbox fixture — comment lines are skipped
hyprland

uwsm # aur
grim
foot # aur
quickshell # omarchy-repo
EOF
AURONLY="$SANDBOX/auronly.packages"
printf 'owe # aur\nowe-lockfeed # aur\n' >"$AURONLY"
OMARCHYONLY="$SANDBOX/omarchyonly.packages"
printf 'hyprland-preview-share-picker # omarchy-repo\nowe # omarchy-repo\nowe-lockfeed # omarchy-repo\n' >"$OMARCHYONLY"
COMMENTSONLY="$SANDBOX/comments.packages"
printf '# a\n#b\n' >"$COMMENTSONLY"
EMPTY="$SANDBOX/empty.packages"
: >"$EMPTY"

wicket_run() { # MANIFEST PATHSPEC LOGFILE args... ; captures out/err
 : >"$SANDBOX/pacman.log"
 : >"$SANDBOX/logger.log" # fresh stub logs per case
 PACMAN_LOG="$SANDBOX/pacman.log" LOGGER_LOG="$SANDBOX/logger.log" \
  WICKET_MANIFEST="$1" PATH="$2" WICKET_LOG="${3:-}" \
  WICKET_PACMAN_CONF="${WICKET_PACMAN_CONF:-$SANDBOX/no-such-pacman.conf}" \
  "$WICKET" "${@:4}" >"$SANDBOX/out" 2>"$SANDBOX/err"
}

# --- (a) dispatcher CLI ------------------------------------------------------
wicket_run "$MIXED" "$PATH_FULL" "" version
rc=$?
if [ "$rc" -eq 0 ] && grep -q 'hngh-wicket' "$SANDBOX/out"; then
 ok "version: rc 0 + banner"
else
 bad "version rc=$rc banner=$(cat "$SANDBOX/out")"
fi

wicket_run "$MIXED" "$PATH_FULL" "" frobnicate
rc=$?
if [ "$rc" -eq 2 ] && grep -q 'usage' "$SANDBOX/err"; then
 ok "unknown action: rc 2 + usage"
else
 bad "unknown action rc=$rc"
fi

wicket_run "$MIXED" "$PATH_FULL" ""
rc=$?
if [ "$rc" -eq 2 ] && grep -q 'usage' "$SANDBOX/err"; then
 ok "no argv: rc 2 + usage"
else
 bad "no argv rc=$rc"
fi

# --- (b) manifest law --------------------------------------------------------
: >"$SANDBOX/pacman.log"
WLOG="$SANDBOX/wicket.log"
: >"$WLOG"
wicket_run "$MIXED" "$PATH_FULL" "$WLOG" install-base
rc=$?
want="pacman -Sy --needed --noconfirm hyprland grim"
[ "$rc" -eq 0 ] && ok "happy install-base: rc 0" || bad "happy install-base rc=$rc"
[ "$(cat "$SANDBOX/pacman.log")" = "$want" ] &&
 ok "pacman argv EXACT: $want" ||
 bad "pacman argv got: $(cat "$SANDBOX/pacman.log")"
grep -qx "install-base pkgs=2 manifest=$MIXED" "$WLOG" &&
 ok "pkgs line: count 2, aur lines skipped" ||
 bad "pkgs line got: $(cat "$WLOG")"
grep -qx "install-base rc=0 upgrades=0" "$WLOG" &&
 ok "rc line logged" ||
 bad "rc line missing"

wicket_run "$AURONLY" "$PATH_FULL" "" install-base
rc=$?
if [ "$rc" -eq 4 ] && [ ! -s "$SANDBOX/pacman.log" ] &&
 grep -q 'aur skipped: 2' "$SANDBOX/err"; then
 ok "aur-only manifest: rc 4, pacman never called"
else
 bad "aur-only rc=$rc pacmanlog=$(cat "$SANDBOX/pacman.log")"
fi

wicket_run "$OMARCHYONLY" "$PATH_FULL" "" install-base
rc=$?
if [ "$rc" -eq 4 ] && [ ! -s "$SANDBOX/pacman.log" ] &&
 grep -q 'omarchy-repo deferred: 3' "$SANDBOX/err"; then
 ok "omarchy-only manifest: rc 4, pacman never called (trio deferred)"
else
 bad "omarchy-only rc=$rc pacmanlog=$(cat "$SANDBOX/pacman.log")"
fi

# omarchy-repo conditional: trio joins the transaction ONLY when the
# conf named by WICKET_PACMAN_CONF has an uncommented `[omarchy]` line.
PACCONF_PRESENT="$SANDBOX/pacman-omarchy.conf"
cat >"$PACCONF_PRESENT" <<'EOF'
[omarchy]
Server = https://example/$repo/$arch
EOF
PACCONF_COMMENTED="$SANDBOX/pacman-commented.conf"
cat >"$PACCONF_COMMENTED" <<'EOF'
#[omarchy]
Server = https://example/$repo/$arch
EOF
OMARCHYMIXED="$SANDBOX/omarchy-mixed.packages"
cat >"$OMARCHYMIXED" <<'EOF'
# sandbox fixture — comment lines are skipped
hyprland
grim
foot # aur
hyprland-preview-share-picker # omarchy-repo
owe # omarchy-repo
owe-lockfeed # omarchy-repo
EOF

WICKET_PACMAN_CONF="$PACCONF_PRESENT" wicket_run "$OMARCHYMIXED" "$PATH_FULL" "$SANDBOX/om.log" install-base
rc=$?
want="pacman -Sy --needed --noconfirm hyprland grim hyprland-preview-share-picker owe owe-lockfeed"
[ "$rc" -eq 0 ] && ok "omarchy repo present: rc 0" || bad "omarchy repo present rc=$rc"
[ "$(cat "$SANDBOX/pacman.log")" = "$want" ] &&
 ok "omarchy repo present: argv includes trio" ||
 bad "omarchy repo present argv got: $(cat "$SANDBOX/pacman.log")"
grep -qx "install-base pkgs=5 manifest=$OMARCHYMIXED" "$SANDBOX/om.log" &&
 ok "omarchy repo present: pkgs=5" ||
 bad "omarchy repo present pkgs line got: $(cat "$SANDBOX/om.log")"

WICKET_PACMAN_CONF="$PACCONF_PRESENT" wicket_run "$OMARCHYONLY" "$PATH_FULL" "" install-base
rc=$?
[ "$rc" -eq 0 ] &&
 [ "$(cat "$SANDBOX/pacman.log")" = "pacman -Sy --needed --noconfirm hyprland-preview-share-picker owe owe-lockfeed" ] &&
 ok "omarchy-only + repo present: trio transaction rc 0" ||
 bad "omarchy-only + repo present rc=$rc pacmanlog=$(cat "$SANDBOX/pacman.log")"

WICKET_PACMAN_CONF="$SANDBOX/no-such-pacman.conf" wicket_run "$OMARCHYMIXED" "$PATH_FULL" "" install-base
rc=$?
want="pacman -Sy --needed --noconfirm hyprland grim"
[ "$rc" -eq 0 ] &&
 [ "$(cat "$SANDBOX/pacman.log")" = "$want" ] &&
 ok "omarchy repo absent (missing conf): argv EXACT unchanged" ||
 bad "omarchy repo absent rc=$rc argv=$(cat "$SANDBOX/pacman.log")"

WICKET_PACMAN_CONF="$PACCONF_COMMENTED" wicket_run "$OMARCHYONLY" "$PATH_FULL" "" install-base
rc=$?
[ "$rc" -eq 4 ] && [ ! -s "$SANDBOX/pacman.log" ] &&
 grep -q 'omarchy-repo deferred: 3' "$SANDBOX/err" &&
 ok "commented '#[omarchy]' conf: treated absent, omarchy-only rc 4" ||
 bad "commented #[omarchy] rc=$rc pacmanlog=$(cat "$SANDBOX/pacman.log")"

wicket_run "$COMMENTSONLY" "$PATH_FULL" "" install-base
[ "$?" -eq 4 ] && ok "comment-only manifest: rc 4" || bad "comment-only rc"

wicket_run "$EMPTY" "$PATH_FULL" "" install-base
[ "$?" -eq 4 ] && ok "empty manifest: rc 4" || bad "empty manifest rc"

wicket_run "$SANDBOX/does-not-exist.packages" "$PATH_FULL" "" install-base
rc=$?
[ "$rc" -eq 4 ] && ok "missing manifest: rc 4" || bad "missing manifest rc=$rc"

UNREADABLE="$SANDBOX/unreadable.packages"
printf 'hyprland\n' >"$UNREADABLE" && chmod 000 "$UNREADABLE"
if [ "$(id -u)" -ne 0 ]; then
 wicket_run "$UNREADABLE" "$PATH_FULL" "" install-base
 [ "$?" -eq 4 ] && ok "unreadable manifest: rc 4" || bad "unreadable manifest rc"
else
 ok "unreadable manifest: skipped (running as root)"
fi

# --- (c) pacman absent -------------------------------------------------------
wicket_run "$MIXED" "$PATH_NO_PAC" "" install-base
rc=$?
[ "$rc" -eq 4 ] && ok "pacman absent: rc 4" || bad "pacman absent rc=$rc"

# --- (d) audit sink ----------------------------------------------------------
wicket_run "$MIXED" "$PATH_NO_LOG" "" install-base # no logger anywhere, no file sink
[ "$?" -eq 0 ] && ok "logger absent: still success (best-effort)" || bad "logger absent rc"

: >"$SANDBOX/logger.log"
wicket_run "$MIXED" "$PATH_FULL" "" install-base # logger stub on PATH, no file sink
grep -q "install-base pkgs=2 manifest=$MIXED" "$SANDBOX/logger.log" &&
 ok "logger sink: stub got the pkgs line" ||
 bad "logger sink got: $(cat "$SANDBOX/logger.log")"

# --- (e) sudoers template law ------------------------------------------------
grantlines="$(grep -v '^[[:space:]]*#' "$SUDOERS_TMPL" | grep -c 'NOPASSWD')"
grants_ok=1
for g in install-base stage install-file; do
 grep -q "NOPASSWD: /usr/local/lib/hngh/wicket\.sh $g" "$SUDOERS_TMPL" || grants_ok=0
done
if [ "$grantlines" -eq 3 ] && [ "$grants_ok" -eq 1 ]; then
 ok "template: exactly three per-action grants naming dispatcher+subcommand"
else
 bad "template grants: lines=$grantlines per-action-present=$grants_ok"
fi
if grep -v '^[[:space:]]*#' "$SUDOERS_TMPL" | grep -q 'NOPASSWD:ALL'; then
 bad "template: NOPASSWD:ALL present"
else
 ok "template: no NOPASSWD:ALL"
fi
if command -v visudo >/dev/null 2>&1; then
 if visudo -cf "$SUDOERS_TMPL" >/dev/null 2>&1; then
  ok "template: visudo -cf parses"
 else
  bad "template: visudo -cf rejects"
 fi
else
 ok "template: visudo absent, parse check skipped"
fi

# --- (f) privileged.sh seam --------------------------------------------------
export SUDO_LOG="$SANDBOX/sudo.log" SUDO_EXEC_LOG="$SANDBOX/sudoexec.log"
export CRUMBS_WRITER="$SANDBOX/crumbstub.py" HNGH_CRUMBS_DB="$SANDBOX/crumbs.log"
pv_run() { # PATHSPEC args... (SUDO_* env pre-set by caller)
 PATH="$1" "$PV" "${@:2}" >"$SANDBOX/out" 2>"$SANDBOX/err"
}

SUDO_ARMED=0 pv_run "$CORE:$SANDBOX/sud" wicket install-base
rc=$?
err="$(cat "$SANDBOX/err")"
first="${err%%$'\n'*}"
[ "$rc" -eq 3 ] && ok "not armed: rc 3" || bad "not armed rc=$rc"
case "$first" in
"wicket not armed:"*)
 if grep -q 'install -D -o root -g root -m 0755' "$SANDBOX/err" &&
  grep -q 'sudoers.d/hngh-wicket' "$SANDBOX/err"; then
  ok "not armed: exact opener + bootstrap block"
 else
  bad "not armed: block incomplete"
 fi
 ;;
*) bad "not armed: stderr starts: $first" ;;
esac

: >"$SUDO_EXEC_LOG"
: >"$HNGH_CRUMBS_DB"
SUDO_ARMED=1 SUDO_EXEC_RC=0 \
 SUDO_LIST_OUT="  (root) NOPASSWD: /usr/local/lib/hngh/wicket.sh install-base" \
 pv_run "$CORE:$SANDBOX/sud" wicket install-base
rc=$?
wantexec="sudo-exec -n /usr/local/lib/hngh/wicket.sh install-base"
if [ "$rc" -eq 0 ] && [ "$(cat "$SUDO_EXEC_LOG")" = "$wantexec" ]; then
 ok "armed: stub sudo execed with exact dispatcher argv"
else
 bad "armed rc=$rc exec=$(cat "$SUDO_EXEC_LOG")"
fi
grep -q "wicket wicket-run action=install-base rc=0" "$HNGH_CRUMBS_DB" &&
 ok "armed: best-effort crumb fired" ||
 bad "armed: crumb missing ($(cat "$HNGH_CRUMBS_DB" 2>/dev/null))"

SUDO_ARMED=1 SUDO_EXEC_RC=7 \
 SUDO_LIST_OUT="  (root) NOPASSWD: /usr/local/lib/hngh/wicket.sh install-base" \
 pv_run "$CORE:$SANDBOX/sud" wicket install-base
rc=$?
[ "$rc" -eq 7 ] && ok "action failure: rc propagates (7)" || bad "failure rc=$rc"

: >"$SUDO_EXEC_LOG"
SUDO_ARMED=1 SUDO_EXEC_RC=0 \
 SUDO_LIST_OUT="  (root) NOPASSWD: /usr/local/lib/hngh/wicket.sh stage" \
 pv_run "$CORE:$SANDBOX/sud" wicket stage "$SANDBOX/src/owe-1.0-1-x86_64.pkg.tar.zst"
rc=$?
wantexec="sudo-exec -n /usr/local/lib/hngh/wicket.sh stage $SANDBOX/src/owe-1.0-1-x86_64.pkg.tar.zst"
[ "$rc" -eq 0 ] && [ "$(cat "$SUDO_EXEC_LOG")" = "$wantexec" ] &&
 ok "armed (stage grant): passthrough execs exact dispatcher argv" ||
 bad "armed stage got: $(cat "$SUDO_EXEC_LOG")"

# --- (g) stage lane -----------------------------------------------------------
SD="$SANDBOX/staging"
export WICKET_STAGING_DIR="$SD"
mkdir -p "$SANDBOX/src"
GOOD="$SANDBOX/src/owe-1.0-1-x86_64.pkg.tar.zst"
printf 'PKGDATA' >"$GOOD"
chmod 640 "$GOOD"
SDLOG="$SANDBOX/stage.log"
wicket_run "$MIXED" "$PATH_FULL" "$SDLOG" stage "$GOOD"
rc=$?
if [ "$rc" -eq 0 ] &&
 [ "$(cat "$SD/owe-1.0-1-x86_64.pkg.tar.zst" 2>/dev/null)" = "PKGDATA" ] &&
 [ "$(stat -c %a "$SD/owe-1.0-1-x86_64.pkg.tar.zst" 2>/dev/null)" = "640" ]; then
 ok "stage happy: copied into staging, mode preserved"
else
 bad "stage happy rc=$rc mode=$(stat -c %a "$SD/owe-1.0-1-x86_64.pkg.tar.zst" 2>/dev/null)"
fi
grep -qx "stage file=owe-1.0-1-x86_64.pkg.tar.zst src=$GOOD" "$SDLOG" &&
 ok "stage: audit line" ||
 bad "stage audit got: $(cat "$SDLOG")"

mkdir -p "$SANDBOX/src/adir"
wicket_run "$MIXED" "$PATH_FULL" "" stage "$SANDBOX/src/adir"
[ "$?" -eq 4 ] && ok "stage: dir-as-file rc 4" || bad "stage dir rc"
wicket_run "$MIXED" "$PATH_FULL" "" stage "$SANDBOX/src/absent-1.0-1-x86_64.pkg.tar.zst"
[ "$?" -eq 4 ] && ok "stage: absent file rc 4" || bad "stage absent rc"

ROOTOWNED=""
if [ "$(id -u)" -ne 0 ]; then
 for c in /etc/hosts /etc/hostname /etc/passwd; do
  [ -f "$c" ] && [ -r "$c" ] && [ "$(stat -c %u "$c" 2>/dev/null)" = "0" ] && {
   ROOTOWNED="$c"
   break
  }
 done
fi
if [ -n "$ROOTOWNED" ]; then
 wicket_run "$MIXED" "$PATH_FULL" "" stage "$ROOTOWNED"
 [ "$?" -eq 4 ] && ok "stage: root-owned src refused ($ROOTOWNED)" || bad "stage root-owned rc"
else
 echo "skip: stage root-owned case (no root-owned readable regular file / running as root)"
fi

BIG="$SANDBOX/src/big-1.0-1-x86_64.pkg.tar.zst"
truncate -s 67108865 "$BIG" # 64MiB + 1, sparse
wicket_run "$MIXED" "$PATH_FULL" "" stage "$BIG"
[ "$?" -eq 4 ] && ok "stage: over 64MiB cap rc 4" || bad "stage big rc"

printf 'x' >"$SANDBOX/src/Bad Name.pkg.tar.zst"
wicket_run "$MIXED" "$PATH_FULL" "" stage "$SANDBOX/src/Bad Name.pkg.tar.zst"
[ "$?" -eq 4 ] && ok "stage: unsanitized basename rc 4" || bad "stage badname rc"

wicket_run "$MIXED" "$PATH_FULL" "" stage "$SANDBOX/src/sub/../owe-1.0-1-x86_64.pkg.tar.zst"
[ "$?" -eq 4 ] && ok "stage: '..' traversal rc 4" || bad "stage traversal rc"

# --- (h) install-file ----------------------------------------------------------
resolved="$(realpath -e -- "$SD/owe-1.0-1-x86_64.pkg.tar.zst")"
IFLOG="$SANDBOX/installfile.log"
wicket_run "$MIXED" "$PATH_FULL" "$IFLOG" install-file owe-1.0-1-x86_64.pkg.tar.zst
rc=$?
wantU="pacman -U --noconfirm --needed $resolved"
if [ "$rc" -eq 0 ] && [ "$(cat "$SANDBOX/pacman.log")" = "$wantU" ]; then
 ok "install-file happy: EXACT pacman argv"
else
 bad "install-file rc=$rc argv=$(cat "$SANDBOX/pacman.log")"
fi
grep -qx "install-file pkg=owe-1.0-1-x86_64.pkg.tar.zst file=$resolved" "$IFLOG" &&
 grep -qx "install-file pkg=owe-1.0-1-x86_64.pkg.tar.zst rc=0 upgrades=0" "$IFLOG" &&
 ok "install-file: audit + result lines" ||
 bad "install-file audit got: $(cat "$IFLOG")"

wicket_run "$MIXED" "$PATH_FULL" "" install-file "../evil.pkg.tar.zst"
[ "$?" -eq 2 ] && ok "install-file: bad name rc 2 (misuse)" || bad "install-file badname rc"
wicket_run "$MIXED" "$PATH_FULL" "" install-file absent-1.0-1-x86_64.pkg.tar.zst
[ "$?" -eq 4 ] && ok "install-file: absent staged file rc 4" || bad "install-file absent rc"

ln -sf "$MIXED" "$SD/escape-1.0-1-x86_64.pkg.tar.zst" # symlink escape out of staging
wicket_run "$MIXED" "$PATH_FULL" "" install-file escape-1.0-1-x86_64.pkg.tar.zst
[ "$?" -eq 4 ] && ok "install-file: symlink escape refused rc 4" || bad "install-file escape rc"

wicket_run "$MIXED" "$PATH_FULL" "" install-file
[ "$?" -eq 2 ] && ok "install-file: no arg usage rc 2" || bad "install-file noarg rc"

# --- (i) upgrading-signal extraction -------------------------------------------
UP="$SANDBOX/up.out"
printf 'resolving dependencies...\nupgrading foo 1.0-1 -> 1.1-1\n(2/2) installing bar\n:: Running post-transaction hooks...\n' >"$UP"
UPLOG="$SANDBOX/up.log"
PACMAN_OUT="$UP" wicket_run "$MIXED" "$PATH_FULL" "$UPLOG" install-base
rc=$?
[ "$rc" -eq 0 ] && grep -qx "install-base rc=0 upgrades=1 list=foo" "$UPLOG" &&
 ok "upgrading signal: count=1 list=foo" ||
 bad "upgrading rc=$rc log=$(cat "$UPLOG")"

NOUP="$SANDBOX/noup.out"
printf 'resolving dependencies...\n(1/1) installing hyprland\n' >"$NOUP"
NOPLOG="$SANDBOX/noup.log"
PACMAN_OUT="$NOUP" wicket_run "$MIXED" "$PATH_FULL" "$NOPLOG" install-base
rc=$?
[ "$rc" -eq 0 ] && grep -qx "install-base rc=0 upgrades=0" "$NOPLOG" &&
 ok "no upgrading lines: count=0" ||
 bad "no-upgrade rc=$rc log=$(cat "$NOPLOG")"

IFUPLOG="$SANDBOX/installfile-up.log"
PACMAN_OUT="$UP" wicket_run "$MIXED" "$PATH_FULL" "$IFUPLOG" install-file owe-1.0-1-x86_64.pkg.tar.zst
rc=$?
[ "$rc" -eq 0 ] &&
 grep -qx "install-file pkg=owe-1.0-1-x86_64.pkg.tar.zst rc=0 upgrades=1 list=foo" "$IFUPLOG" &&
 ok "install-file: same upgrading signal" ||
 bad "install-file upgrading rc=$rc log=$(cat "$IFUPLOG")"

RCLOG="$SANDBOX/rc.log"
PACMAN_RC=3 PACMAN_OUT="$UP" wicket_run "$MIXED" "$PATH_FULL" "$RCLOG" install-base
rc=$?
[ "$rc" -eq 3 ] && grep -qx "install-base rc=3 upgrades=1 list=foo" "$RCLOG" &&
 ok "pacman rc propagates through captured output" ||
 bad "pacman rc=3 path rc=$rc log=$(cat "$RCLOG")"

pv_run "$CORE:$SANDBOX/sud"
rc=$?
[ "$rc" -eq 2 ] && ok "privileged: no argv rc 2" || bad "privileged no-argv rc=$rc"
pv_run "$CORE:$SANDBOX/sud" bogus
rc=$?
[ "$rc" -eq 2 ] && ok "privileged: unknown subcommand rc 2" || bad "privileged bogus rc=$rc"
pv_run "$CORE:$SANDBOX/sud" wicket
rc=$?
[ "$rc" -eq 2 ] && ok "privileged: wicket without action rc 2" || bad "privileged bare-wicket rc=$rc"

# --- summary -----------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
 echo "PASS: test-wicket"
 exit 0
fi
echo "FAIL: test-wicket ($fails)"
exit 1
