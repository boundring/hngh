#!/usr/bin/env bash
# omarchy-boot-provision.sh -- ATTENDED driver for the Omarchy limine boot
# provisioning (runbook: docs/agent-notes/2026-10-05-omarchy-limine-boot-runbook.md).
# It drives the operator run sequence from your own terminal and asks
# y/N (default N) before EACH privileged action; empty input aborts that
# action. sudo prompts land on the operator's TTY -- that is the design.
#
# Usage: omarchy-boot-provision.sh [--dry-run] [--yes]
#   --dry-run is the DEFAULT (same convention as omarchy-boot-build.sh):
#   the plan is printed and nothing is written. --yes executes, still
#   asking y/N per privileged action.
#
# Hard rules (fail-closed):
#   - the esp phase is NEVER run anywhere in the flow: it would
#     mkfs.vfat the live ESP and destroy it ("esp" as an argument is
#     refused with the reason, exit 2);
#   - entry install refuses (exit 2, nothing written) when an entry with
#     the same title already exists: the operator edits it by hand;
#   - the driver NEVER reboots and NEVER touches NVRAM; it stops after
#     printing the staged post-reboot verification checklist.
#
# Flow: preflight (census + emit-entry) -> build -> verify ->
#       entry install -> optional QEMU proof -> checklist.
#
# Env knobs (the omarchy-boot-build.sh seams are honored too):
#   HNGH_BOOT_BUILD   build script to drive (default: the sibling
#                     omarchy-boot-build.sh; tests stub it)
#   HNGH_LIMINE_CONF  limine config to edit (default
#                     /boot/EFI/limine/limine.conf)
#   HNGH_BOOT_DISK    target disk      (default /dev/nvme0n1)
#   HNGH_BOOT_MNT     root mount point (default /mnt)
#   HNGH_BOOT_LOGDIR  live stage-log directory (default
#                     ~/.hngh/installer-logs)
#   HNGH_BOOT_CONFIRM=YES authorizes --yes without a TTY (scripted run)
set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${HNGH_BOOT_BUILD:-$DIR/omarchy-boot-build.sh}"
CONF="${HNGH_LIMINE_CONF:-/boot/EFI/limine/limine.conf}"
DISK="${HNGH_BOOT_DISK:-/dev/nvme0n1}"
MNT="${HNGH_BOOT_MNT:-/mnt}"
DRY=1
ENTRY_OUT=""
BLOCK=""
TITLE=""
BAK=""

say() { printf '%s\n' "$*"; }

usage() {
  say "usage: omarchy-boot-provision.sh [--dry-run] [--yes]"
  say "  --dry-run  print the plan, write nothing (DEFAULT)"
  say "  --yes      execute; y/N (default N) is asked per privileged action"
  say "  attended: never runs the esp phase (mkfs.vfat on the live ESP),"
  say "  never reboots, never touches NVRAM"
  exit 0
}

for arg in "$@"; do
  case "$arg" in
  --dry-run) DRY=1 ;;
  --yes) DRY=0 ;;
  --help | -h | help) usage ;;
  esp)
    printf 'omarchy-boot-provision: refused: the esp phase would mkfs.vfat the live ESP (%sp1) and destroy it; this driver never runs it\n' "$DISK" >&2
    exit 2
    ;;
  *)
    printf 'omarchy-boot-provision: refused: unknown argument: %s (see --help)\n' "$arg" >&2
    exit 2
    ;;
  esac
done

# Live stage log (REQ-I26): same convention as omarchy-boot-build.sh.
now="$(date -u +%Y%m%dT%H%M%SZ)"
logdir="${HNGH_BOOT_LOGDIR:-$HOME/.hngh/installer-logs}"
if mkdir -p "$logdir" 2>/dev/null && [ -d "$logdir" ]; then
  exec > >(tee -a "$logdir/provision-$now.log") 2>&1
  mode=dry-run
  [ "$DRY" -eq 0 ] && mode=REAL
  say "== omarchy-boot-provision mode=$mode disk=$DISK conf=$CONF $(date -u +%Y-%m-%dT%H:%M:%SZ) =="
fi

# gate: --yes must come from a human at a TTY (prompts land there) or
# from a scripted run explicitly marked HNGH_BOOT_CONFIRM=YES.
if [ "$DRY" -eq 0 ] && [ "${HNGH_BOOT_CONFIRM:-}" != "YES" ] && [ ! -t 0 ]; then
  printf 'omarchy-boot-provision: refused: --yes but no TTY; set HNGH_BOOT_CONFIRM=YES to authorize non-interactive execution\n' >&2
  exit 2
fi

# confirm <action>: y/N, default N. Only y/yes proceeds; empty input or
# anything else aborts THIS action (fail-closed).
confirm() {
  printf 'omarchy-boot-provision: %s [y/N] ' "$1"
  read -r ans || ans=""
  case "$ans" in
  y | Y | yes | YES) return 0 ;;
  *)
    say "aborted: $1 (operator answered no)"
    return 1
    ;;
  esac
}

# (a) preflight (read-only in BOTH modes): census + emit-entry; the
# generated block is shown to the operator before anything is staged.
stage_preflight() {
  say "== preflight: census + emit-entry (read-only) =="
  bash "$BUILD" census || say "# census rc=$? (target disk absent = inconclusive; continuing)"
  ENTRY_OUT="$(bash "$BUILD" emit-entry)" || {
    printf 'omarchy-boot-provision: emit-entry failed (unresolvable id, fail-closed); nothing to install\n' >&2
    exit 2
  }
  say "--- entry block (from emit-entry) ---"
  printf '%s\n' "$ENTRY_OUT"
  say "--- end entry block ---"
  # the chainload entry = title line + its indented directives, nothing
  # else (the template after the blank/comment lines is never installed)
  BLOCK="$(printf '%s\n' "$ENTRY_OUT" | awk 'NR==1 { print; next } /^[ \t]/ { print; next } { exit }')"
  TITLE="${BLOCK%%$'\n'*}"
  if [ -z "$TITLE" ]; then
    printf 'omarchy-boot-provision: emit-entry produced no entry block (fail-closed)\n' >&2
    exit 2
  fi
}

# (b) build: reinstall-first kernel+limine + mkinitcpio (privileged).
stage_build() {
  if [ "$DRY" -eq 1 ]; then
    say "+ bash $BUILD build --yes   # privileged: chroot pacman + mkinitcpio -P"
    return 0
  fi
  confirm "run $BUILD build --yes (pacman reinstall + mkinitcpio -P)" || return 0
  bash "$BUILD" build --yes || exit $?
}

# (c) verify: kernel + initramfs on the mounted root, chainload binary
# on the ESP (privileged reads: mounts and 0077 dirs).
stage_verify() {
  if [ "$DRY" -eq 1 ]; then
    say "+ sudo test -e: $MNT/boot/vmlinuz-linux-omarchy + initramfs + \\EFI\\BOOT\\BOOTX64.EFI (findings)"
    return 0
  fi
  confirm "verify probe (sudo test -e: kernel + initramfs + chainload binary)" || return 0
  miss=0
  for f in vmlinuz-linux-omarchy initramfs-linux-omarchy.img initramfs-linux-omarchy-fallback.img; do
    if sudo test -e "$MNT/boot/$f"; then
      say "present: $MNT/boot/$f"
    else
      say "MISSING: $MNT/boot/$f"
      miss=1
    fi
  done
  if sudo test -e "$MNT/boot/EFI/BOOT/BOOTX64.EFI"; then
    say "present: \\EFI\\BOOT\\BOOTX64.EFI (chainload binary on the ESP)"
  else
    say "MISSING: \\EFI\\BOOT\\BOOTX64.EFI (chainload binary on the ESP)"
    miss=1
  fi
  [ "$miss" -eq 0 ] || say "# findings include MISSING: is the ESP mounted at $MNT/boot?"
}

# (d) entry install: back up the limine config, then append ONLY the
# chainload entry block. Fails CLOSED when an entry with the same title
# already exists -- the operator edits that entry by hand instead.
stage_install() {
  if [ "$DRY" -eq 1 ]; then
    say "+ sudo cp -a $CONF $CONF.bak-<UTC YYYYMMDD>"
    say "+ append the chainload entry block to $CONF (title: $TITLE)"
    return 0
  fi
  confirm "back up $CONF and append the entry block" || return 0
  if sudo grep -Fqx "$TITLE" "$CONF" 2>/dev/null; then
    say "refused: an entry with this title is already in $CONF: $TITLE"
    say "edit that entry by hand; nothing was written (fail-closed)"
    exit 2
  fi
  BAK="$CONF.bak-$(date -u +%Y%m%d)"
  sudo cp -a "$CONF" "$BAK" || exit $?
  printf '%s\n' "$BLOCK" | sudo tee -a "$CONF" >/dev/null || exit $?
  say "entry appended to $CONF (backup: $BAK)"
}

# (e) optional QEMU proof behind its own confirmation: qcow2 overlay +
# qemu-system over the real disk; the real disk is never written.
stage_qemu() {
  if [ "$DRY" -eq 1 ]; then
    say "+ bash $BUILD qemu --yes   # optional: qemu-img overlay + qemu-system boot proof"
    return 0
  fi
  confirm "optional QEMU boot proof ($BUILD qemu --yes; real disk untouched)" || return 0
  bash "$BUILD" qemu --yes || exit $?
}

# (f) staged post-reboot verification checklist from the runbook, then
# stop. The driver NEVER reboots and NEVER touches NVRAM.
stage_checklist() {
  say ""
  say "== staged post-reboot verification checklist (from the runbook) =="
  say "this driver never reboots and never touches NVRAM -- power off, then:"
  say "Stage 1: power on; the limine menu must draw on the iGPU display (DP-2)."
  say "Stage 2: select the entry. Failure signatures:"
  say "  could not open/resolve guid(...) = wrong identifier in limine.conf"
  say "  a second menu appears = chainload OK, target side"
  say "  instant black = the chained BOOTX64.EFI hangs pre-draw"
  say "  no bootable entries / missing kernel = build/verify incomplete"
  say "Stage 3: kernel starts then black with disk activity = target GPU/plymouth:"
  say "  probe target cmdline plymouth.enable=0 nomodeset, then journalctl -b -1"
}

stage_preflight
stage_build
stage_verify
stage_install
stage_qemu
stage_checklist
