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

if [ "$fails" -eq 0 ]; then
  printf 'test-omarchy-boot-build: all proofs passed\n'
  exit 0
fi
printf 'test-omarchy-boot-build: %d failure(s)\n' "$fails"
exit 1
