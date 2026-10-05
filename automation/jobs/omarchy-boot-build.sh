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
#   emit-entry  print the limine chainload entry + target kernel entry
#               template for the probed ids (read-only, never guesses)
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
#   HNGH_ESP_PARTUUID emit-entry override: ESP GPT PARTUUID (probed at
#                                  runtime when unset; HNGH_ESP_ID
#                                  doubles as the FAT volume id override)
#   HNGH_ROOT_UUID  emit-entry override: root filesystem UUID (probed
#                                  at runtime when unset)
#   HNGH_DEV_DISK   by-partuuid/by-uuid scan root (default /dev/disk)
#   HNGH_PACMAN_SYNC_DIR pacman sync-db dir probed inside the chroot for
#                                  the -Syu fallback (default
#                                  /var/lib/pacman/sync)
#   HNGH_UPSTREAM   host-path omarchy upstream clone for the adopt hint
#                                  (default ~/Projects/etc/omarchy-upstream)
#   HNGH_BOOT_LOGDIR live stage-log directory (REQ-I26, default
#                                  ~/.hngh/installer-logs; every run --
#                                  dry or real -- mirrors its output there)
set -u

DISK="${HNGH_BOOT_DISK:-/dev/nvme0n1}"
ESP="${DISK}p1"
ROOTP="${DISK}p2"
MNT="${HNGH_BOOT_MNT:-/mnt}"
USER_NAME="${HNGH_BOOT_USER:-bricker}"
ESP_ID="${HNGH_ESP_ID:-317A31FF}"
ESP_LABEL="${HNGH_ESP_LABEL:-OMARCHY-ESP}"
UPSTREAM="${HNGH_UPSTREAM:-$HOME/Projects/etc/omarchy-upstream}"
DEV_DISK="${HNGH_DEV_DISK:-/dev/disk}"

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
  say "  phases: census esp build qemu adopt-check emit-entry all"
  say "  dry-run default; --yes executes the named phase (privileged)"
  say "  env: HNGH_BOOT_DISK HNGH_BOOT_MNT HNGH_BOOT_USER HNGH_ESP_ID HNGH_ESP_LABEL HNGH_UPSTREAM"
  say "       HNGH_BOOT_LOGDIR (live stage log; default ~/.hngh/installer-logs)"
  exit 0
}

# run_root <args...>: print the sudo line; execute it only in real mode.
run_root() {
  say "+ sudo $*"
  [ "$DRY" -eq 1 ] && return 0
  sudo "$@" || exit $? # fail-closed: never mount over a failed mkfs
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

# MOUNTED tracks the mountpoints THIS run mounted (newest first); the
# build-phase failure trap unmounts them in reverse order.
MOUNTED=""

# mount_one <mountpoint> <mount args...>: idempotent mount -- when the
# mountpoint is already mounted (findmnt -n hits) the mount is skipped,
# so a re-run after a failed run can never double-mount.
mount_one() {
  mount_mp="$1"
  shift
  if findmnt -n "$mount_mp" >/dev/null 2>&1; then
    say "# $mount_mp already mounted -- skipping (idempotent)"
    return 0
  fi
  run_root mount "$@"
  MOUNTED="$mount_mp $MOUNTED"
}

mount_cmds() {
  mount_one "$MNT" -o subvol=@,compress=zstd:3 "$ROOTP" "$MNT"
  run_root mkdir -p "$MNT/boot"
  mount_one "$MNT/boot" "$ESP" "$MNT/boot" # ESP AT /boot -- fstab pins UUID=317A-31FF
  mount_one "$MNT/home" --mkdir -o subvol=@home "$ROOTP" "$MNT/home"
  mount_one "$MNT/var/log" --mkdir -o subvol=@log "$ROOTP" "$MNT/var/log"
  mount_one "$MNT/var/cache/pacman/pkg" --mkdir -o subvol=@pkg "$ROOTP" "$MNT/var/cache/pacman/pkg"
}

# build_cleanup: failure-path cleanup for phase_build (EXIT trap; it
# only acts on a nonzero exit -- a successful build KEEPS its mounts so
# the driver's verify stage can read them). Unmounts what THIS run
# mounted in reverse order: the @ subvolume mounts first, then the ESP
# at /mnt/boot, then /mnt. Never installed in dry-run (nothing mounts).
build_cleanup() {
  build_rc=$?
  [ "$build_rc" -eq 0 ] && return 0
  [ -z "$MOUNTED" ] && return 0
  say "# build failed (rc=$build_rc) -- unmounting what this run mounted, in reverse order"
  for build_mp in $MOUNTED; do
    say "+ sudo umount $build_mp"
    if sudo umount "$build_mp"; then :; else
      say "WARN: umount $build_mp failed (rc=$?) -- unmount by hand before retrying"
    fi
  done
}

phase_census() {
  say "== census: $DISK =="
  if ! lsblk -no NAME "$DISK" >/dev/null 2>&1; then
    say "omarchy-boot-build: target disk absent -- census inconclusive (expected off-machine)" >&2
    exit 3
  fi
  lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTUUID "$DISK"
  say "ESP: $ESP (informational) -- mkfs id $ESP_ID label $ESP_LABEL are the canonical esp-phase defaults only; the esp phase is not part of the provisioning flow"
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
  [ "$DRY" -eq 0 ] && trap 'build_cleanup' EXIT
  mount_cmds
  say "+ sudo arch-chroot $MNT /bin/bash -s  (in-chroot sequence below)"
  [ "$DRY" -eq 1 ] && {
    say "ls /etc/mkinitcpio.d/            # expect EMPTY pre-reinstall"
    say "grep ^HOOKS /etc/mkinitcpio.conf # census: limine hook ABSENT; warn if still absent"
    say "pacman -S --needed linux-omarchy limine   # reinstall-FIRST: drops /boot/vmlinuz-linux-omarchy + preset"
    say "# half-installed root (no /var/lib/pacman/sync/*.db): one pacman -Syu --needed linux-omarchy limine transaction instead; on a keyring/signature failure: pacman -Sy archlinux-keyring then ONE retry"
    say "mkinitcpio -P                    # needs the preset from the previous line"
    say "ls /usr/bin | grep -i limine     # discover tooling; loader path is NOT guessed here"
    say "pacman -Ql limine | grep -E 'limine.conf|initcpio|hooks/' + ls /etc/limine* /boot/limine*   # discover config authorship; nothing is written"
    say "touch /var/lib/systemd/linger/$USER_NAME   # loginctl enable-linger fails in chroot (no bus)"
    return 0
  }
  PACMAN_SYNC_DIR="${HNGH_PACMAN_SYNC_DIR:-/var/lib/pacman/sync}"
  sudo arch-chroot "$MNT" /bin/bash -euo pipefail <<CHROOT || exit $?
ls /etc/mkinitcpio.d/ 2>/dev/null || echo "no /etc/mkinitcpio.d (nothing installed yet)"
if grep -q '^HOOKS=.*limine' /etc/mkinitcpio.conf; then
  echo "HOOKS: limine hook present"
else
  echo "WARN: limine hook absent from HOOKS (bootloader install is separate; do not sed unattended)"
fi
sync_dir="$PACMAN_SYNC_DIR"
if ls "\$sync_dir"/*.db >/dev/null 2>&1; then
  tx=(pacman -S --needed linux-omarchy limine)
else
  echo "pacman: no sync databases under \$sync_dir (half-installed target) -- one -Syu transaction instead of -S"
  tx=(pacman -Syu --needed linux-omarchy limine)
fi
pacman_err=/tmp/hngh-pacman-tx.err
if "\${tx[@]}" 2>"\$pacman_err"; then
  :
else
  tx_rc=\$?
  cat "\$pacman_err" >&2
  if grep -Eqi 'keyring|signature|invalid or corrupted package' "\$pacman_err"; then
    echo "pacman: transaction failed with a keyring/signature error -- syncing archlinux-keyring and retrying once"
    pacman -Sy archlinux-keyring
    "\${tx[@]}" || { rc=\$?; echo "pacman: retry after archlinux-keyring failed (rc=\$rc)" >&2; exit "\$rc"; }
    echo "pacman: retry after archlinux-keyring succeeded"
  else
    echo "pacman: transaction failed (rc=\$tx_rc) -- no retry (not a keyring/signature error)"
    exit "\$tx_rc"
  fi
fi
mkinitcpio -P
echo "--- limine packaging discovery (print only; no config is written here) ---"
pacman -Ql limine 2>/dev/null | grep -E 'limine\.conf|initcpio|hooks/' || echo "WARN: pacman -Ql limine matched no conf/initcpio/hook paths"
ls /etc/limine* /boot/limine* 2>/dev/null || echo "no /etc/limine* or /boot/limine* files present"
echo "--- end discovery ---"
ls /usr/bin | grep -i limine || echo "WARN: no limine tooling found in /usr/bin"
touch "/var/lib/systemd/linger/$USER_NAME"
echo "linger stamped for $USER_NAME"
echo "NEXT (operator): pick the limine install path from the tooling list above, then:"
echo "  efibootmgr --create --disk $DISK --part 1 --label 'Omarchy (limine)' --loader <loader.efi>"
CHROOT
  trap - EXIT
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

# probe_id <partuuid|fsuuid> <device>: resolve one identifier through
# the source chain, first hit wins. Unprivileged sources first -- lsblk
# prints empty columns without the disk group on this host -- then
# udevadm properties, then the /dev/disk/by-* symlink scan (the id IS
# the symlink name); the last resort is a NON-INTERACTIVE sudo probe
# (sudo -n never prompts: it fails silently without a cached
# credential). Empty output means every source missed and the caller
# fails closed.
probe_id() {
  probe_dev="$2"
  probe_want="${probe_dev##*/}"
  case "$1" in
  partuuid) probe_col=PARTUUID probe_key=ID_PART_ENTRY_UUID probe_sub=by-partuuid ;;
  *) probe_col=UUID probe_key=ID_FS_UUID probe_sub=by-uuid ;;
  esac
  probe_val="$(lsblk -no "$probe_col" "$probe_dev" 2>/dev/null | head -n 1 | tr -d '[:space:]')"
  [ -n "$probe_val" ] || probe_val="$(udevadm info -q property -n "$probe_dev" 2>/dev/null | grep "^$probe_key=" | head -n 1 | cut -d= -f2- | tr -d '[:space:]')"
  if [ -z "$probe_val" ] && [ -d "$DEV_DISK/$probe_sub" ]; then
    for probe_link in "$DEV_DISK/$probe_sub"/*; do
      [ -L "$probe_link" ] || continue
      probe_tgt="$(readlink "$probe_link" 2>/dev/null)"
      if [ "${probe_tgt##*/}" = "$probe_want" ]; then
        probe_val="${probe_link##*/}"
        break
      fi
    done
  fi
  [ -n "$probe_val" ] || probe_val="$(sudo -n lsblk -no "$probe_col" "$probe_dev" 2>/dev/null | head -n 1 | tr -d '[:space:]')"
  [ -n "$probe_val" ] || probe_val="$(sudo -n blkid -s "$probe_col" -o value "$probe_dev" 2>/dev/null | head -n 1 | tr -d '[:space:]')"
  printf '%s\n' "$probe_val"
}

UUID_RE='^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
FAT_RE='^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$'

# emit_die <what>: one line to stderr, no entry block, exit 2. Empty or
# malformed ids are never guessed around.
emit_die() {
  emit_msg="omarchy-boot-build: emit-entry: cannot resolve $1 (fail-closed, no entry block)"
  printf '%s\n' "$emit_msg" >&2
  [ -n "$LOGFILE" ] && printf '%s\n' "$emit_msg" >>"$LOGFILE"
  exit 2
}

# phase_emit_entry: read-only in dry-run and --yes alike -- it never
# PROMPTS (the last-resort probe is sudo -n). Prints the host chainload
# entry plus the target-side kernel entry TEMPLATE for the CURRENT ids,
# probed at runtime unless the env seams override them. All three ids
# are validated BEFORE any output.
phase_emit_entry() {
  PARTUUID="${HNGH_ESP_PARTUUID:-$(probe_id partuuid "$ESP")}"
  FAT_ID="${HNGH_ESP_ID:-$(probe_id fsuuid "$ESP")}"
  ROOT_UUID="${HNGH_ROOT_UUID:-$(probe_id fsuuid "$ROOTP")}"
  # the FAT volume id is written 317A31FF (mkfs -i) but reported
  # 317A-31FF (lsblk UUID): normalize the undashed form
  case "$FAT_ID" in
  [0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
    FAT_ID="${FAT_ID%????}-${FAT_ID#????}"
    ;;
  esac
  [[ "$PARTUUID" =~ $UUID_RE ]] || emit_die "ESP partition GPT PARTUUID"
  [[ "$FAT_ID" =~ $FAT_RE ]] || emit_die "ESP FAT volume id"
  [[ "$ROOT_UUID" =~ $UUID_RE ]] || emit_die "root partition filesystem UUID"
  block="$(printf '%s\n' \
    "/Omarchy 4.0.4 (chainload ${DISK##*/} ESP)" \
    "    protocol: efi" \
    "    path: guid($PARTUUID):/EFI/BOOT/BOOTX64.EFI" \
    "" \
    "# probed at runtime: ESP FAT volume id $FAT_ID (equivalent: guid($FAT_ID))," \
    "# root filesystem UUID $ROOT_UUID." \
    "# Target-side kernel entry TEMPLATE -- UNCONFIRMED: verify against whatever" \
    "# authors the target limine config (mkinitcpio hook vs hand-authored) before use." \
    "/Omarchy 4.0.4 (target kernel TEMPLATE - edit before use)" \
    "    protocol: linux" \
    "    kernel_path: guid($PARTUUID):/vmlinuz-linux-omarchy" \
    "    module_path: guid($PARTUUID):/initramfs-linux-omarchy.img" \
    "    cmdline: root=UUID=$ROOT_UUID rootflags=subvol=@")"
  printf '%s\n' "$block"
  [ -n "$LOGFILE" ] && printf '%s\n' "$block" >>"$LOGFILE"
}

# Live stage log (REQ-I26): every run mirrors stdout+stderr to a
# timestamped log while lines are produced (tee flushes per line); stdin
# stays attached so sudo keeps its TTY password prompt. Dry-runs log too --
# the printed plan IS the review artifact. Log loss is never a gate: if
# the directory is unwritable the run proceeds unmirrored. The == header
# line goes to the log file only: stdout stays the pure phase artifact
# (emit-entry's block stays copy-paste ready).
LOGFILE=""
case "$PHASE" in
--help | -h | help | '') ;; # usage prints below; no log
census | esp | build | qemu | adopt-check | emit-entry | all)
  now="$(date -u +%Y%m%dT%H%M%SZ)"
  logdir="${HNGH_BOOT_LOGDIR:-$HOME/.hngh/installer-logs}"
  if mkdir -p "$logdir" 2>/dev/null && [ -d "$logdir" ]; then
    mode=dry-run
    [ "$DRY" -eq 0 ] && mode=REAL
    LOGFILE="$logdir/$PHASE-$now.log"
    printf '%s\n' "== omarchy-boot-build phase=$PHASE mode=$mode disk=$DISK user=$USER_NAME $(date -u +%Y-%m-%dT%H:%M:%SZ) ==" >"$LOGFILE"
    # emit-entry keeps stdout/stderr pristine (copy-paste block, real
    # errors); every other phase mirrors live via tee.
    if [ "$PHASE" != "emit-entry" ]; then
      exec > >(tee -a "$LOGFILE") 2>&1
    fi
  fi
  ;;
*) ;; # unknown phase: no log -- $PHASE must never reach a filename
esac

case "$PHASE" in
--help | -h | help | '') usage ;;
census) phase_census ;;
esp) phase_esp ;;
build) phase_build ;;
qemu) phase_qemu ;;
adopt-check) phase_adopt_check ;;
emit-entry) phase_emit_entry ;;
all)
  phase_census
  phase_esp
  phase_build
  phase_qemu
  ;;
*) die "unknown phase: $PHASE (see --help)" ;;
esac
