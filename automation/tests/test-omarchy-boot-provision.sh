#!/usr/bin/env bash
# test-omarchy-boot-provision.sh -- hermetic proofs for
# jobs/omarchy-boot-provision.sh. PATH-stub style like
# test-omarchy-boot-build.sh: a stub omarchy-boot-build.sh records every
# invocation; sudo is a passthrough shim over temp paths (or an exit-99
# detector). No real sudo, qemu, pacman, or disk is ever touched.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/jobs/omarchy-boot-provision.sh"
fails=0
ok() { printf 'ok %s\n' "$1"; }
bad() {
  printf 'FAIL %s: %s\n' "$1" "${2:-}"
  fails=$((fails + 1))
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STUB="$WORK/omarchy-boot-build.sh"
STUB_LOG="$WORK/stub-invocations.log"
CONF="$WORK/limine.conf"
MNT="$WORK/mnt"
LOGS="$WORK/logs"
SHIM="$WORK/shim-pass"
SHIM99="$WORK/shim-fail"
mkdir -p "$MNT/boot/EFI/BOOT" "$LOGS" "$SHIM" "$SHIM99"
cat >"$SHIM/sudo" <<'SH'
#!/bin/sh
case "$1" in
  -v)
    printf 'sudo -v\n' >>"$HNGH_STUB_LOG"
    exit 0
    ;;
esac
exec "$@"
SH
printf '#!/bin/sh\nexit 99\n' >"$SHIM99/sudo"
chmod +x "$SHIM/sudo" "$SHIM99/sudo"
: >"$STUB_LOG"
BLOCK_TITLE='/Omarchy 4.0.4 (chainload nvme0n1 ESP)'
BLOCK_PATH='    path: guid(c1953180-ad35-427a-a8cd-1fd922897680):/EFI/BOOT/BOOTX64.EFI'

cat >"$STUB" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$HNGH_STUB_LOG"
case "${1:-}" in
  census) echo "== census: stub ==" ;;
  emit-entry)
    [ "${HNGH_STUB_FAIL:-}" = "1" ] && exit 2
    printf '%s\n' \
      '/Omarchy 4.0.4 (chainload nvme0n1 ESP)' \
      '    protocol: efi' \
      '    path: guid(c1953180-ad35-427a-a8cd-1fd922897680):/EFI/BOOT/BOOTX64.EFI' \
      '' \
      '# stub template comment (must NOT be installed)' \
      '/Omarchy 4.0.4 (target kernel TEMPLATE - edit before use)' \
      '    protocol: linux'
    ;;
esac
exit 0
STUB
chmod +x "$STUB"

# run_drv <sudo-shim-dir> <gate> <answers> <args...>: run the driver with
# the stub environment. stdin is a pipe (never a TTY), so <gate> is the
# HNGH_BOOT_CONFIRM value: YES is the scripted-run authorization for
# --yes; '' leaves the no-TTY gate to refuse it.
run_drv() {
  shim="$1" gate="$2" answers="$3"
  shift 3
  printf '%s' "$answers" | env HNGH_BOOT_CONFIRM="$gate" \
    HNGH_STUB_LOG="$STUB_LOG" HNGH_BOOT_BUILD="$STUB" HNGH_LIMINE_CONF="$CONF" \
    HNGH_BOOT_MNT="$MNT" HNGH_BOOT_LOGDIR="$LOGS" PATH="$shim:$PATH" \
    bash "$SCRIPT" "$@"
}
stub_has() { grep -q "$1" "$STUB_LOG"; }

# 1. syntax
if bash -n "$SCRIPT"; then ok "bash -n"; else bad "bash -n" "syntax error"; fi

# 2. --help exits 0 and lists the flags
out="$(bash "$SCRIPT" --help)" && hrc=0 || hrc=$?
if [ "$hrc" -eq 0 ]; then ok "--help rc"; else bad "--help rc" "rc=$hrc"; fi
case "$out" in
*"--dry-run"*) ok "--help lists --dry-run" ;;
*) bad "--help lists --dry-run" "$out" ;;
esac
case "$out" in
*"--yes"*) ok "--help lists --yes" ;;
*) bad "--help lists --yes" "$out" ;;
esac

# 3. default is dry-run: preflight runs read-only, nothing privileged
#    happens (the exit-99 sudo shim proves no sudo ran)
: >"$STUB_LOG"
out="$(run_drv "$SHIM99" '' '' 2>&1)" && drc=0 || drc=$?
if [ "$drc" -eq 0 ]; then ok "dry-run default rc=0"; else bad "dry-run default rc=0" "rc=$drc"; fi
case "$out" in
*mode=dry-run*) ok "dry-run header" ;;
*) bad "dry-run header" "missing mode=dry-run" ;;
esac
case "$out" in
*"$BLOCK_TITLE"*) ok "preflight shows the generated block" ;;
*) bad "preflight block" "title missing" ;;
esac
case "$out" in
*"build --yes"*) ok "dry-run prints the build plan" ;;
*) bad "dry-run build plan" "missing" ;;
esac
if stub_has '^census$'; then ok "preflight runs census"; else bad "preflight census" "not invoked"; fi
if stub_has '^emit-entry$'; then ok "preflight runs emit-entry"; else bad "preflight emit-entry" "not invoked"; fi
if stub_has 'build\|qemu'; then bad "dry-run runs no build/qemu" "$(cat "$STUB_LOG")"; else ok "dry-run runs no build/qemu"; fi
if stub_has 'esp\|all'; then bad "esp phase never invoked" "stub saw esp/all"; else ok "esp phase never invoked (dry-run)"; fi

# 4. --yes without a TTY is refused like the underlying gate (rc=2)
out="$(run_drv "$SHIM99" '' '' --yes 2>&1)" && yrc=0 || yrc=$?
if [ "$yrc" -eq 2 ]; then ok "--yes no-tty refusal rc=2"; else bad "--yes no-tty refusal rc=2" "rc=$yrc"; fi
case "$out" in
*"refused"*) ok "--yes refusal message" ;;
*) bad "--yes refusal message" "$out" ;;
esac

# 5. the esp phase is hard-refused as an argument, with the mkfs reason
out="$(run_drv "$SHIM99" '' '' esp 2>&1)" && erc=0 || erc=$?
if [ "$erc" -eq 2 ]; then ok "esp argument refused rc=2"; else bad "esp argument refused rc=2" "rc=$erc"; fi
case "$out" in
*mkfs*) ok "esp refusal names the mkfs reason" ;;
*) bad "esp refusal reason" "$out" ;;
esac

# 6. --yes flow: entry install backs up + appends ONLY the entry block;
#    qemu stays behind its own confirmation; esp is never invoked
printf '# existing config\n' >"$CONF"
: >"$STUB_LOG"
out="$(run_drv "$SHIM" YES $'y\ny\ny\nn\n' --yes 2>&1)" && frc=0 || frc=$?
if [ "$frc" -eq 0 ]; then ok "--yes flow rc=0"; else bad "--yes flow rc=0" "rc=$frc"; fi
if stub_has '^build --yes$'; then ok "build runs under confirmation"; else bad "build stage" "$(cat "$STUB_LOG")"; fi
if stub_has qemu; then bad "qemu only on its own confirmation" "qemu ran despite N"; else ok "qemu only on its own confirmation"; fi
if stub_has 'esp\|all'; then bad "esp phase never invoked (--yes)" "$(cat "$STUB_LOG")"; else ok "esp phase never invoked (--yes)"; fi
bak="$CONF.bak-$(date -u +%Y%m%d)"
if [ -f "$bak" ]; then ok "entry install creates the backup"; else bad "backup file" "$bak missing"; fi
bak_body="$(cat "$bak" 2>/dev/null)"
if [ "$bak_body" = '# existing config' ]; then ok "backup holds the original"; else bad "backup body" "$bak_body"; fi
exp_conf="$(printf '%s\n' '# existing config' "$BLOCK_TITLE" '    protocol: efi' "$BLOCK_PATH")"
got_conf="$(cat "$CONF")"
if [ "$got_conf" = "$exp_conf" ]; then
  ok "entry install appends exactly the entry block"
else
  bad "appended block" "$(printf '%s\n' "$got_conf")"
fi
case "$got_conf" in
*TEMPLATE* | *stub\ template*) bad "template never installed" "template text in conf" ;;
*) ok "template never installed" ;;
esac
case "$out" in
*checklist*) ok "staged checklist printed" ;;
*) bad "staged checklist" "missing" ;;
esac
#    --yes pays exactly one sudo -v up front, before preflight
n_sv="$(grep -c '^sudo -v$' "$STUB_LOG")"
if [ "$n_sv" = "1" ]; then ok "--yes runs sudo -v exactly once"; else bad "--yes sudo -v count" "$n_sv"; fi
if [ "$(head -n 1 "$STUB_LOG")" = "sudo -v" ]; then ok "sudo -v runs before preflight"; else bad "sudo -v order" "$(head -n 3 "$STUB_LOG" | tr '\n' ' ')"; fi

# 7. duplicate title: fail-closed, the file is left untouched
rm -f "$CONF".bak-*
printf '%s\n' '# existing config' "$BLOCK_TITLE" >"$CONF"
before="$(cat "$CONF")"
out="$(run_drv "$SHIM" YES $'y\ny\ny\nn\n' --yes 2>&1)" && rrc=0 || rrc=$?
if [ "$rrc" -eq 2 ]; then ok "duplicate title refusal rc=2"; else bad "duplicate title refusal rc=2" "rc=$rrc"; fi
if [ "$(cat "$CONF")" = "$before" ]; then ok "duplicate refusal leaves the file untouched"; else bad "duplicate refusal wrote" "$(cat "$CONF")"; fi
if [ -e "$bak" ]; then bad "duplicate refusal creates no backup" "$bak exists"; else ok "duplicate refusal creates no backup"; fi
case "$out" in
*edit*) ok "duplicate refusal tells the operator to edit" ;;
*) bad "duplicate refusal message" "$out" ;;
esac

# 8. confirmation default N / empty input aborts every privileged action
rm -f "$CONF".bak-*
printf '# existing config\n' >"$CONF"
: >"$STUB_LOG"
out="$(run_drv "$SHIM" YES $'\n\n\n\n' --yes 2>&1)" && arc=0 || arc=$?
if [ "$arc" -eq 0 ]; then ok "empty confirmations rc=0"; else bad "empty confirmations rc=0" "rc=$arc"; fi
case "$out" in
*aborted*) ok "empty input aborts the action" ;;
*) bad "abort message" "missing" ;;
esac
if stub_has 'build\|qemu'; then bad "no privileged action on empty input" "$(cat "$STUB_LOG")"; else ok "no privileged action on empty input"; fi
if [ "$(cat "$CONF")" = '# existing config' ]; then ok "conf untouched on empty input"; else bad "conf changed on empty input" "$(cat "$CONF")"; fi
if [ -e "$bak" ]; then bad "no backup on empty input" "$bak exists"; else ok "no backup on empty input"; fi

# 9. live stage log mirroring (same convention as omarchy-boot-build.sh)
sleep 0.3
if ls "$LOGS"/provision-*.log >/dev/null 2>&1; then ok "provision log file exists"; else bad "provision log file" "$LOGS is empty"; fi

# 10. dry-run never prompts: no sudo -v at all (the logging shim would
#     have recorded it)
: >"$STUB_LOG"
out="$(run_drv "$SHIM" '' '' 2>&1)" && d2rc=0 || d2rc=$?
if [ "$d2rc" -eq 0 ]; then ok "dry-run (logging shim) rc=0"; else bad "dry-run (logging shim) rc=0" "rc=$d2rc"; fi
if grep -q '^sudo -v$' "$STUB_LOG"; then bad "dry-run never invokes sudo -v" "$(cat "$STUB_LOG")"; else ok "dry-run never invokes sudo -v"; fi

# 11. dry-run preflight failure: fail-closed exit 2 plus the hint that
#     --yes will prompt once for sudo -v
out="$(HNGH_STUB_FAIL=1 run_drv "$SHIM" '' '' 2>&1)" && f2rc=0 || f2rc=$?
if [ "$f2rc" -eq 2 ]; then ok "dry-run probe failure rc=2"; else bad "dry-run probe failure rc=2" "rc=$f2rc"; fi
case "$out" in
*"sudo -v once up front"*) ok "probe failure hints at the --yes sudo -v" ;;
*) bad "probe failure hint" "$out" ;;
esac

if [ "$fails" -eq 0 ]; then
  printf 'test-omarchy-boot-provision: all proofs passed\n'
  exit 0
fi
printf 'test-omarchy-boot-provision: %d failure(s)\n' "$fails"
exit 1
