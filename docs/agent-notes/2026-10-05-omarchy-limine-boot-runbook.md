# Omarchy limine boot runbook (2026-10-05)

Machine-specific operator runbook for booting the Omarchy 4.0.4 install
(nvme0n1) from the host's limine bootloader on the dual-SSD UEFI box.
Diagnosis source: LimineBootDiagnosis scout, 2026-10-05 (evidence in
this file). Everything privileged is operator-supervised: a machine
session never holds the sudo password.

## What went wrong (ranked)

1. STRONGEST - the chainload target has no boot layer. The 2026-10-05
   census run (omarchy-boot-build.sh phases, real mode) proved @/boot
   holds no kernel and no initramfs, /etc/mkinitcpio.d is empty, and no
   limine tooling is installed. All 16 run groups in the installer log
   home are fixture runs against /dev/hngh-test-nonexistent; the build
   phase never ran against the real root. Black screen = limine chained
   into an EFI binary with nothing behind it.
2. Entry volume identifier wrong. The Omarchy ESP has NO label (the
   label-less census mkfs variant was used), so the stale
   fslabel(OMARCHY-ESP) form cannot resolve. Two same-format FAT volume
   ids are in reach of any wrong guess.
3. Provenance of whatever BOOTX64.EFI sits on the ESP is unverified; a
   bad binary can hang before first draw.
4. Entry syntax error - low: limine prints parse errors on screen, so a
   pure black screen is unlikely to be syntax.
5. GPU/console - lowest: the host boots the same console/driver family.

## The entry block (verified UUIDs)

For the host loader config (/boot/EFI/limine/limine.conf on the host
ESP; root-owned, 0077 directory):

```
/Omarchy 4.0.4 (chainload nvme0n1 ESP)
    protocol: efi
    path: guid(c1953180-ad35-427a-a8cd-1fd922897680):/EFI/BOOT/BOOTX64.EFI
```

- c1953180-ad35-427a-a8cd-1fd922897680 = Omarchy ESP PARTUUID
  (nvme0n1p1). Equivalent: guid(317A-31FF) (FAT volume id).
- NEVER root partition f5b8200b / 29e56cf7. NEVER the host ESP
  (2972-BC0E / b938d556-bba0-40b8-86f9-30cd1e3f6d0d) - that chains
  limine into itself.

## Operator run sequence (in order)

1. SKIP the esp phase. The ESP is already formatted with id 317A-31FF;
   the phase's mkfs.vfat would destroy it and anything manually placed
   there. Mount-only steps if needed: ESP -> /mnt/boot on
   /dev/nvme0n1p1.
2. Build the boot layer (root):
   `omarchy-boot-build.sh build --yes` (TTY-gated; logs to the
   installer log home). In-chroot: `pacman -S --needed linux-omarchy
   limine`, `mkinitcpio -P`, tooling discovery. Expect
   /boot/vmlinuz-linux-omarchy + initramfs after it.
3. Verify the chainload loader exists on the ESP:
   \EFI\BOOT\BOOTX64.EFI. If missing, copy the target's limine
   BOOTX64.EFI to that fallback path (same procedure as the fleet
   chainload-entry pattern). Confirm the target's limine.conf or
   limine hook generated an entry for vmlinuz-linux-omarchy with
   root=UUID=f5b8200b... rootflags=subvol=@ - unresolved uncertainty:
   who authors the target limine.conf is not yet proven (build phase
   does not write one; the mkinitcpio hook may).
4. Replace the host entry block in /boot/EFI/limine/limine.conf (above).
   Note: the host runs a stale limine 10.7.0 binary while the package is
   12.9.0; limine-mkinitcpio-hook and limine-snapper-sync are installed
   and may regenerate the host config - re-check the entry after kernel
   updates.
5. QEMU boot proof before touching the physical boot path: overlay
   qcow2 backed by the raw disk (`qemu-img create -f qcow2 -b
   /dev/nvme0n1 -F raw ...`), boot OVMF over the overlay - the real
   disk stays pristine.
6. Physical reboot test (staged, stops at first failure):
   - Stage 1: limine menu visible on the iGPU display (DP-2). If not,
     console/GOP problem: stop here.
   - Stage 2: select the entry. "could not open/resolve guid" = wrong
     identifier (use the block above); a second menu appears = chainload
     OK, target side; instant black = the chained BOOTX64.EFI hangs
     pre-draw; "no bootable entries" / missing kernel = step 2/3
     incomplete.
   - Stage 3: kernel starts, then black with disk activity = target-side
     GPU/plymouth: probe target cmdline `plymouth.enable=0 nomodeset`,
     then read `journalctl -b -1` on the host.
