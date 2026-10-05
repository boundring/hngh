#!/usr/bin/env bash
# test-omarchy-boot-build.sh -- hermetic proofs for jobs/omarchy-boot-build.sh.
# No real disk, no real sudo, no network: dry-run prints; the real-execution
# path is probed with a PATH sudo shim that exits 99.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/jobs/omarchy-boot-build.sh"
fails=0
ok() { printf 'ok %s\n' "$1"; }
bad() {
  printf 'FAIL %s: %s\n' "$1" "${2:-}"
  fails=$((fails + 1))
}
trap 'rm -rf "${SHIMDIR:-}"' EXIT

# 1. syntax
if bash -n "$SCRIPT"; then ok "bash -n"; else bad "bash -n" "syntax error"; fi

# 2. --help exits 0 and lists the phases
out="$(bash "$SCRIPT" --help)" && hrc=0 || hrc=$?
if [ "$hrc" -eq 0 ]; then ok "--help rc"; else bad "--help rc" "rc=$hrc"; fi
for phase in census esp build qemu adopt-check all; do
  case "$out" in *"$phase"*) ok "--help lists $phase" ;; *) bad "--help lists $phase" "missing" ;; esac
done

# 3. census on an absent target disk: exit 3, message says inconclusive
out="$(HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" census 2>&1)" && crc=0 || crc=$?
if [ "$crc" -eq 3 ]; then ok "census absent rc=3"; else bad "census absent rc=3" "rc=$crc"; fi
case "$out" in *inconclusive*) ok "census absent message" ;; *) bad "census absent message" "$out" ;; esac

# 4. esp dry-run prints the mkfs with the pinned id + label, executes nothing
out="$(HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" esp)"
case "$out" in *"-i 317A31FF"*) ok "esp pins id 317A31FF" ;; *) bad "esp pins id" "$out" ;; esac
case "$out" in *"-n OMARCHY-ESP"*) ok "esp label" ;; *) bad "esp label" "$out" ;; esac
case "$out" in *"+ sudo mkfs.vfat"*) ok "esp dry-run prints sudo line" ;; *) bad "esp dry-run print" "$out" ;; esac

# 5. build dry-run order: reinstall FIRST, then mkinitcpio -P; linger touch present
out="$(HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" build)"
pac_line="$(printf '%s\n' "$out" | grep -n 'pacman -S --needed linux-omarchy' | head -1 | cut -d: -f1)"
mk_line="$(printf '%s\n' "$out" | grep -n 'mkinitcpio -P' | head -1 | cut -d: -f1)"
if [ -n "$pac_line" ] && [ -n "$mk_line" ] && [ "$pac_line" -lt "$mk_line" ]; then
  ok "build order: reinstall before mkinitcpio -P"
else
  bad "build order" "pac=$pac_line mk=$mk_line"
fi
case "$out" in *"/var/lib/systemd/linger/"*) ok "linger touch present" ;; *) bad "linger touch" "$out" ;; esac
case "$out" in *"mkinitcpio.d"*) ok "empty-preset note present" ;; *) bad "empty-preset note" "$out" ;; esac

# 6. dry-run never calls sudo (PATH shim would exit 99)
SHIMDIR="$(mktemp -d)"
printf '#!/bin/sh\nexit 99\n' >"$SHIMDIR/sudo"
chmod +x "$SHIMDIR/sudo"
PATH="$SHIMDIR:$PATH" HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" esp >/dev/null 2>&1 &&
  ok "dry-run runs no sudo" || bad "dry-run runs no sudo" "sudo shim was invoked"

# 7. --yes without a TTY and without HNGH_BOOT_CONFIRM=YES: refuse rc=2
out="$(HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" esp --yes </dev/null 2>&1)" && yrc=0 || yrc=$?
if [ "$yrc" -eq 2 ]; then ok "--yes no-tty refusal rc=2"; else bad "--yes no-tty refusal rc=2" "rc=$yrc"; fi
case "$out" in *"refused"*) ok "--yes refusal message" ;; *) bad "--yes refusal message" "$out" ;; esac

# 8. real path reaches sudo ONLY under --yes + HNGH_BOOT_CONFIRM=YES (shim exit 99)
PATH="$SHIMDIR:$PATH" HNGH_BOOT_CONFIRM=YES HNGH_BOOT_DISK=/dev/hngh-test-nonexistent \
  bash "$SCRIPT" esp --yes >/dev/null 2>&1
rrc=$?
if [ "$rrc" -eq 99 ]; then ok "real path reaches sudo under double authorization"; else bad "real path sudo" "rc=$rrc"; fi

# 9. no --yes, no TTY: dry-run exit 0 (safe by construction)
HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" build </dev/null >/dev/null 2>&1 &&
  ok "no-flag invocation stays dry" || bad "no-flag invocation stays dry" "unexpected nonzero rc"

# 10. live stage log: census mirrors output to a timestamped log
LOGS="$(mktemp -d)"
out="$(HNGH_BOOT_LOGDIR="$LOGS" HNGH_BOOT_DISK=/dev/hngh-test-nonexistent bash "$SCRIPT" census 2>&1)" && lrc=0 || lrc=$?
if [ "$lrc" -eq 3 ]; then ok "logged census rc=3 (unchanged)"; else bad "logged census rc" "rc=$lrc"; fi
sleep 0.3 # tee procsub may drain just after exit
log_file="$(printf '%s\n' "$LOGS"/census-*.log)"
if [ -f "$log_file" ]; then ok "census log file exists"; else bad "census log file" "$LOGS is empty"; fi
log_body="$(cat "$LOGS"/census-*.log 2>/dev/null)"
case "$log_body" in
*"== omarchy-boot-build phase=census mode=dry-run"*) ok "log header recorded" ;;
*) bad "log header" "$(printf '%s\n' "$log_body" | head -1)" ;;
esac
case "$log_body" in
*inconclusive*) ok "log captures phase output incl. die path" ;;
*) bad "log phase output" "missing inconclusive line" ;;
esac

# 11. --help writes no log
nlogs_before="$(ls "$LOGS" | wc -l)"
bash "$SCRIPT" --help >/dev/null 2>&1
sleep 0.2
nlogs_after="$(ls "$LOGS" | wc -l)"
if [ "$nlogs_before" -eq "$nlogs_after" ]; then ok "--help writes no log"; else bad "--help writes no log" "$nlogs_before -> $nlogs_after"; fi

# 12. adopt-check logs its hint line
HNGH_BOOT_LOGDIR="$LOGS" bash "$SCRIPT" adopt-check >/dev/null 2>&1
sleep 0.2
case "$(cat "$LOGS"/adopt-check-*.log 2>/dev/null)" in
*"OMARCHY_UPSTREAM_DIR="*) ok "adopt-check log present" ;;
*) bad "adopt-check log" "missing hint line" ;;
esac

# 13. real path logs mode=REAL even when sudo fails (shim exit 99)
PATH="$SHIMDIR:$PATH" HNGH_BOOT_CONFIRM=YES HNGH_BOOT_DISK=/dev/hngh-test-nonexistent \
  HNGH_BOOT_LOGDIR="$LOGS" bash "$SCRIPT" esp --yes >/dev/null 2>&1
sleep 0.2
case "$(cat "$LOGS"/esp-*.log 2>/dev/null)" in
*"mode=REAL"*) ok "real attempt logged as REAL" ;;
*) bad "REAL log header" "missing mode=REAL" ;;
esac
rm -rf "$LOGS"

# 14-18. emit-entry: chainload entry block + target kernel entry
# template for the probed ids; fail-closed (exit 2, no block) on
# unresolvable or malformed ids; read-only in dry-run and --yes alike
EXP="$(
  cat <<'EOF'
/Omarchy 4.0.4 (chainload nvme0n1 ESP)
    protocol: efi
    path: guid(c1953180-ad35-427a-a8cd-1fd922897680):/EFI/BOOT/BOOTX64.EFI

# probed at runtime: ESP FAT volume id 317A-31FF (equivalent: guid(317A-31FF)),
# root filesystem UUID deadbeef-1234-4abc-8def-1234567890ab.
# Target-side kernel entry TEMPLATE -- UNCONFIRMED: verify against whatever
# authors the target limine config (mkinitcpio hook vs hand-authored) before use.
/Omarchy 4.0.4 (target kernel TEMPLATE - edit before use)
    protocol: linux
    kernel_path: guid(c1953180-ad35-427a-a8cd-1fd922897680):/vmlinuz-linux-omarchy
    module_path: guid(c1953180-ad35-427a-a8cd-1fd922897680):/initramfs-linux-omarchy.img
    cmdline: root=UUID=deadbeef-1234-4abc-8def-1234567890ab rootflags=subvol=@
EOF
)"
LOGS="$(mktemp -d)"
ERRF="$(mktemp)"

# 14. env overrides honored (HNGH_ESP_ID in undashed form normalizes to
#     317A-31FF); the exit-99 sudo shim in PATH proves it runs no sudo
out="$(env -u HNGH_BOOT_DISK HNGH_ESP_PARTUUID=c1953180-ad35-427a-a8cd-1fd922897680 \
  HNGH_ESP_ID=317A31FF HNGH_ROOT_UUID=deadbeef-1234-4abc-8def-1234567890ab \
  HNGH_BOOT_LOGDIR="$LOGS" PATH="$SHIMDIR:$PATH" bash "$SCRIPT" emit-entry 2>"$ERRF")" && erc=0 || erc=$?
if [ "$erc" -eq 0 ]; then ok "emit-entry overrides rc=0 (read-only)"; else bad "emit-entry overrides rc=0" "rc=$erc $(cat "$ERRF")"; fi
if [ "$out" = "$EXP" ]; then ok "emit-entry exact block (env overrides)"; else bad "emit-entry block" "$(printf '%s\n' "$out")"; fi
case "$(cat "$LOGS"/emit-entry-*.log 2>/dev/null)" in
*"/Omarchy 4.0.4 (chainload nvme0n1 ESP)"*) ok "emit-entry block logged" ;;
*) bad "emit-entry log" "block missing from the stage log" ;;
esac

# 15. runtime probes (lsblk PATH-stub fixture, no overrides): same block
cat >"$SHIMDIR/lsblk" <<'LS'
#!/bin/sh
case "$3:$2" in
  /dev/nvme0n1p1:PARTUUID) printf '%s\n' c1953180-ad35-427a-a8cd-1fd922897680 ;;
  /dev/nvme0n1p1:UUID) printf '%s\n' 317A-31FF ;;
  /dev/nvme0n1p2:UUID) printf '%s\n' deadbeef-1234-4abc-8def-1234567890ab ;;
  *) exit 1 ;;
esac
LS
chmod +x "$SHIMDIR/lsblk"
out="$(env -u HNGH_BOOT_DISK -u HNGH_ESP_ID -u HNGH_ESP_PARTUUID -u HNGH_ROOT_UUID \
  HNGH_BOOT_LOGDIR="$LOGS" PATH="$SHIMDIR:$PATH" bash "$SCRIPT" emit-entry 2>"$ERRF")" && erc=0 || erc=$?
if [ "$erc" -eq 0 ] && [ "$out" = "$EXP" ]; then ok "emit-entry exact block (runtime probes)"; else bad "emit-entry probes" "rc=$erc $(printf '%s\n' "$out")"; fi

# 16. unresolvable id: exit 2, one-line stderr, NO block on stdout
out="$(env -u HNGH_BOOT_DISK -u HNGH_ESP_ID -u HNGH_ESP_PARTUUID -u HNGH_ROOT_UUID \
  HNGH_BOOT_DISK=/dev/hngh-test-nonexistent HNGH_BOOT_LOGDIR="$LOGS" \
  PATH="$SHIMDIR:$PATH" bash "$SCRIPT" emit-entry 2>"$ERRF")" && erc=0 || erc=$?
if [ "$erc" -eq 2 ]; then ok "emit-entry unresolvable rc=2"; else bad "emit-entry unresolvable rc=2" "rc=$erc"; fi
case "$(cat "$ERRF")" in
*"cannot resolve"*"PARTUUID"*) ok "emit-entry error names the missing id" ;;
*) bad "emit-entry error line" "$(cat "$ERRF")" ;;
esac
if [ -z "$out" ]; then ok "emit-entry prints no block on failure"; else bad "emit-entry failure output" "$(printf '%s\n' "$out")"; fi

# 17. malformed override: exit 2, error names the root filesystem UUID
out="$(env -u HNGH_BOOT_DISK HNGH_ESP_PARTUUID=c1953180-ad35-427a-a8cd-1fd922897680 \
  HNGH_ESP_ID=317A31FF HNGH_ROOT_UUID=garbage HNGH_BOOT_LOGDIR="$LOGS" \
  PATH="$SHIMDIR:$PATH" bash "$SCRIPT" emit-entry 2>"$ERRF")" && erc=0 || erc=$?
if [ "$erc" -eq 2 ]; then ok "emit-entry malformed rc=2"; else bad "emit-entry malformed rc=2" "rc=$erc"; fi
case "$(cat "$ERRF")" in
*"root partition filesystem UUID"*) ok "emit-entry malformed names root fs UUID" ;;
*) bad "emit-entry malformed error" "$(cat "$ERRF")" ;;
esac
if [ -z "$out" ]; then ok "emit-entry malformed prints no block"; else bad "emit-entry malformed output" "$(printf '%s\n' "$out")"; fi

# 18. --yes alike: no gate, no sudo (shim exit 99), same exact block
out="$(env -u HNGH_BOOT_DISK HNGH_ESP_PARTUUID=c1953180-ad35-427a-a8cd-1fd922897680 \
  HNGH_ESP_ID=317A31FF HNGH_ROOT_UUID=deadbeef-1234-4abc-8def-1234567890ab \
  HNGH_BOOT_LOGDIR="$LOGS" PATH="$SHIMDIR:$PATH" bash "$SCRIPT" emit-entry --yes 2>"$ERRF")" && erc=0 || erc=$?
if [ "$erc" -eq 0 ] && [ "$out" = "$EXP" ]; then ok "emit-entry --yes is safe and exact"; else bad "emit-entry --yes" "rc=$erc $(printf '%s\n' "$out")"; fi
rm -rf "$LOGS" "$ERRF"

if [ "$fails" -eq 0 ]; then
  printf 'test-omarchy-boot-build: all proofs passed\n'
  exit 0
fi
printf 'test-omarchy-boot-build: %d failure(s)\n' "$fails"
exit 1
