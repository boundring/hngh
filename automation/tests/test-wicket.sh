#!/usr/bin/env bash
# test-wicket.sh — the wicket privileged channel, hermetic (sandboxed
# manifest/pacman/logger/sudo via PATH + env; no network, no system
# mutations, NEVER the real sudo). Covers:
# (a) dispatcher CLI: version; usage rc 2 on unknown argv / no argv;
# (b) manifest law: happy path builds EXACTLY one `pacman -Sy --needed
#     --noconfirm <pkgs>` argv in manifest order; `# aur` lines skipped
#     and counted; aur-only / comment-only / empty manifest refuse rc 4;
#     missing / unreadable manifest rc 4;
# (c) tooling fail-closed: pacman absent rc 4;
# (d) audit sink: logger absent -> still success; logger stub -> pkgs
#     line; WICKET_LOG file sink -> pkgs + rc lines;
# (e) sudoers template: exactly one grant, exact command incl. action
#     arg, no NOPASSWD:ALL, visudo -cf parses;
# (f) privileged.sh seam: not armed -> stderr starts `wicket not armed:`
#     plus the bootstrap block, rc 3; armed -> stub sudo execed with the
#     exact dispatcher argv, best-effort crumb fires; action failure rc
#     propagates; usage rc 2.
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
ln -sf "$(command -v python3)" "$SANDBOX/core/python3" # crumbs writer needs it

# pacman stub: records full argv, configurable rc
cat >"$SANDBOX/pac/pacman" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "pacman $*" >>"$PACMAN_LOG"
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
EOF
AURONLY="$SANDBOX/auronly.packages"
printf 'owe # aur\nowe-lockfeed # aur\n' >"$AURONLY"
COMMENTSONLY="$SANDBOX/comments.packages"
printf '# a\n#b\n' >"$COMMENTSONLY"
EMPTY="$SANDBOX/empty.packages"
: >"$EMPTY"

wicket_run() { # MANIFEST PATHSPEC LOGFILE args... ; captures out/err
 : >"$SANDBOX/pacman.log"
 : >"$SANDBOX/logger.log" # fresh stub logs per case
 PACMAN_LOG="$SANDBOX/pacman.log" LOGGER_LOG="$SANDBOX/logger.log" \
  WICKET_MANIFEST="$1" PATH="$2" WICKET_LOG="${3:-}" \
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
grep -qx "install-base rc=0" "$WLOG" &&
 ok "rc line logged" ||
 bad "rc line missing"

wicket_run "$AURONLY" "$PATH_FULL" "" install-base
rc=$?
if [ "$rc" -eq 4 ] && [ ! -s "$SANDBOX/pacman.log" ]; then
 ok "aur-only manifest: rc 4, pacman never called"
else
 bad "aur-only rc=$rc pacmanlog=$(cat "$SANDBOX/pacman.log")"
fi

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
exact="$(grep -c 'wicket\.sh install-base' "$SUDOERS_TMPL")"
if [ "$grantlines" -eq 1 ] && [ "$exact" -ge 1 ]; then
 ok "template: exactly one grant naming the exact command+arg"
else
 bad "template grants=$grantlines exact=$exact"
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
