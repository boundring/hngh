#!/usr/bin/env bash
# omarchy-boot-build.sh -- scripted boot-layer bring-up for a powered-off
# Omarchy root (harness-skeleton E-phase; encodes the E3/E4 operator blocks).
#
# Phases:
#   census      read-only look at the target disk (no sudo)
#   esp         E3a/E3b: mkfs.vfat the ESP (DESTROYS the partition), mount
#               root+aux subvols, mount ESP at /mnt/boot        [privileged]
#   build       E3 chroot: reinstall-first kernel+limine, mkinitcpio -P,
#               limine tooling discovery, linger touch          [privileged]
#   qemu        E4 boot proof on a qcow2 overlay over the real disk [privileged]
#   adopt-check print the post-boot config-adopt command (runs on the
#               booted TARGET, not here; safe)
#   all         census -> esp -> build -> qemu
#
# House rules (match install.sh / bootstrap):
#   - dry-run is the default: exact privileged commands are printed,
#     nothing executes;
#   - --yes executes the named phase for real; it must come from a
#     human at a TTY (sudo prompts there); --yes without a TTY and
#     without HNGH_BOOT_CONFIRM=YES is refused (exit 2) so a CI or
#     scripted call can never run destructive work;
#   - no --yes -> dry-run print, exit 0, always safe;
#   - never guesses the limine loader path: build discovers the tooling
#     and prints what it found for the operator to finalize.
#
# Env knobs (tests override; defaults match the E-phase target):
#   HNGH_BOOT_DISK  target disk    (default /dev/nvme0n1)
#   HNGH_BOOT_MNT   mount point    (default /mnt)
#   HNGH_BOOT_USER  linger user    (default bricker)
#   HNGH_ESP_ID     mkfs volume id (default 317A31FF -- the target fstab
#                                  pins UUID=317A-31FF for /boot; a wrong
#                                  id breaks the pinned mount)
#   HNGH_ESP_LABEL  mkfs label     (default OMARCHY-ESP)
#   HNGH_UPSTREAM   host-path omarchy upstream clone for the adopt hint
#                                  (default ~/Projects/etc/omarchy-upstream)
set -u

DISK="${HNGH_BOOT_DISK:-/dev/nvme0n1}"
ESP="${DISK}p1"
ROOTP="${DISK}p2"
MNT="${HNGH_BOOT_MNT:-/mnt}"
USER_NAME="${HNGH_BOOT_USER:-bricker}"
ESP_ID="${HNGH_ESP_ID:-317A31FF}"
ESP_LABEL="${HNGH_ESP_LABEL:-OMARCHY-ESP}"
UPSTREAM="${HNGH_UPSTREAM:-$HOME/Projects/etc/omarchy-upstream}"

PHASE="${1:---help}"
DRY=1
[ "${2:-}" = "--yes" ] && DRY=0

say() { printf '%s\n' "$*"; }
die() {
  printf 'omarchy-boot-build: %s\n' "$*" >&2
  exit 1
}

usage() {
  say "usage: omarchy-boot-build.sh <phase> [--yes]"
  say "  phases: census esp build qemu adopt-check all"
  say "  dry-run default; --yes executes the named phase (privileged)"
  say "  env: HNGH_BOOT_DISK HNGH_BOOT_MNT HNGH_BOOT_USER HNGH_ESP_ID HNGH_ESP_LABEL HNGH_UPSTREAM"
  exit 0
}

# run_root <args...>: print the sudo line; execute it only in real mode.
run_root() {
  say "+ sudo $*"
  [ "$DRY" -eq 1 ] && return 0
  sudo "$@" || exit $?   # fail-closed: never mount over a failed mkfs
}

# gate <phase>: dry-run never gates. Real execution (--yes) must come
# from a human at a TTY; a scripted --yes additionally needs
# HNGH_BOOT_CONFIRM=YES or it is refused (exit 2).
gate() {
  [ "$DRY" -eq 1 ] && return 0
  [ "${HNGH_BOOT_CONFIRM:-}" = "YES" ] && return 0
  [ -t 0 ] && return 0
  printf 'omarchy-boot-build: refused: %s with --yes but no TTY; set HNGH_BOOT_CONFIRM=YES to authorize non-interactive execution\n' "$1" >&2
  exit 2
}

mount_cmds() {
  run_root mount -o subvol=@,compress=zstd:3 "$ROOTP" "$MNT"
  run_root mkdir -p "$MNT/boot"
  run_root mount "$ESP" "$MNT/boot" # ESP AT /boot -- fstab pins UUID=317A-31FF
  run_root mount --mkdir -o subvol=@home "$ROOTP" "$MNT/home"
  run_root mount --mkdir -o subvol=@log "$ROOTP" "$MNT/var/log"
  run_root mount --mkdir -o subvol=@pkg "$ROOTP" "$MNT/var/cache/pacman/pkg"
}

phase_census() {
  say "== census: $DISK =="
  if ! lsblk -no NAME "$DISK" >/dev/null 2>&1; then
    say "omarchy-boot-build: target disk absent -- census inconclusive (expected off-machine)" >&2
    exit 3
  fi
  lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID "$DISK"
  say "ESP to format: $ESP (mkfs id $ESP_ID label $ESP_LABEL)"
  say "fstab on the target pins UUID=317A-31FF for /boot -- the volume id must match"
}

phase_esp() {
  gate esp
  say "== esp: format + mounts (DESTROYS $ESP) =="
  if [ "$DRY" -eq 0 ]; then
    if findmnt -rn -S "$ESP" >/dev/null 2>&1; then
      die "refused: $ESP is currently mounted; unmount it first (fail-closed)"
    fi
  fi
  run_root mkfs.vfat -F 32 -i "$ESP_ID" -n "$ESP_LABEL" "$ESP"
  mount_cmds
}

phase_build() {
  gate build
  say "== build: chroot kernel + initramfs + linger =="
  mount_cmds
  say "+ sudo arch-chroot $MNT /bin/bash -s  (in-chroot sequence below)"
  [ "$DRY" -eq 1 ] && {
    say "ls /etc/mkinitcpio.d/            # expect EMPTY pre-reinstall"
    say "grep ^HOOKS /etc/mkinitcpio.conf # census: limine hook ABSENT; warn if still absent"
    say "pacman -S --needed linux-omarchy limine   # reinstall-FIRST: drops /boot/vmlinuz-linux-omarchy + preset"
    say "mkinitcpio -P                    # needs the preset from the previous line"
    say "ls /usr/bin | grep -i limine     # discover tooling; loader path is NOT guessed here"
    say "touch /var/lib/systemd/linger/$USER_NAME   # loginctl enable-linger fails in chroot (no bus)"
    return 0
  }
  sudo arch-chroot "$MNT" /bin/bash -euo pipefail <<CHROOT
ls /etc/mkinitcpio.d/
if grep -q '^HOOKS=.*limine' /etc/mkinitcpio.conf; then
  echo "HOOKS: limine hook present"
else
  echo "WARN: limine hook absent from HOOKS (bootloader install is separate; do not sed unattended)"
fi
pacman -S --needed linux-omarchy limine
mkinitcpio -P
ls /usr/bin | grep -i limine || echo "WARN: no limine tooling found in /usr/bin"
touch "/var/lib/systemd/linger/$USER_NAME"
echo "linger stamped for $USER_NAME"
echo "NEXT (operator): pick the limine install path from the tooling list above, then:"
echo "  efibootmgr --create --disk $DISK --part 1 --label 'Omarchy (limine)' --loader <loader.efi>"
CHROOT
}

phase_qemu() {
  gate qemu
  say "== qemu: boot proof on overlay (real disk stays pristine) =="
  OVER="/tmp/${DISK##*/}-boot-test.qcow2"
  say "+ qemu-img create -f qcow2 -b $DISK -F raw $OVER"
  if [ "$DRY" -eq 0 ]; then qemu-img create -f qcow2 -b "$DISK" -F raw "$OVER" || exit $?; fi
  if [ -w /dev/kvm ]; then
    KVM="-enable-kvm -m 8G -smp 8"
  else
    say "# /dev/kvm not writable for this user: TCG fallback (slow but boots)"
    KVM="-m 2G -smp 4"
  fi
  QCMD=(sudo qemu-system-x86_64 $KVM
    -drive "file=$OVER,format=qcow2,if=virtio"
    -bios /usr/share/ovmf/x64/OVMF_CODE.fd -vga virtio -display gtk)
  printf '+ %s\n' "${QCMD[*]}"
  if [ "$DRY" -eq 0 ]; then "${QCMD[@]}" || exit $?; fi
  say "# success = Omarchy desktop inside QEMU; only then offer the physical reboot"
}

phase_adopt_check() {
  say "== adopt-check: runs on the BOOTED TARGET, not here =="
  say "OMARCHY_UPSTREAM_DIR=$UPSTREAM ~/.hngh/automation/jobs/omarchy-config-adopt.sh"
  say "# host path rule: a /run/media upstream path dangles at boot; the target-side"
  say "# clone at /home/<user>/Projects/etc/omarchy-upstream is the boot-valid path"
}

case "$PHASE" in
--help | -h | help | '') usage ;;
census) phase_census ;;
esp) phase_esp ;;
build) phase_build ;;
qemu) phase_qemu ;;
adopt-check) phase_adopt_check ;;
all)
  phase_census
  phase_esp
  phase_build
  phase_qemu
  ;;
*) die "unknown phase: $PHASE (see --help)" ;;
esac
