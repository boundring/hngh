# Omarchy limine boot runbook (2026-10-05)

> The screen was black because nothing was there yet -- not even an
> error worth printing.

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

## Unattended stock reinstall (pilot-first)

`automation/jobs/omarchy-unattended-install.sh` replaces the interactive
wizard with a seeded cidata install: four phases (`seed` `run` `verify`
`full`), dry-run by default.

### Two-command flow (the operator path)

1. Pilot chain -- one command, ends green at the real-disk gate:
   `automation/jobs/omarchy-unattended-install.sh full --yes --disk <disk> --iso <iso> --user <name> --credentials-hash <hash>`
   (or `--defer-provisioning` instead of the hash). Runs `seed` ->
   `run --pilot` -> `verify` in order, waiting for the install VM to
   power off before verify (verify never double-opens the target). Then
   it prints `pilot green: <workdir>/pilot.qcow2 proved the install.`
   plus the exact re-run command and exits 0.
2. Real pass:
   `automation/jobs/omarchy-unattended-install.sh full --yes --go-real --disk <disk> --iso <iso> --user <name>`
   Fails closed without a pilot `run-manifest` (pilot green first).
   Reuses the seed (idempotent skip), installs onto the real disk -- the
   "will be FORMATTED" y/N gate still asks once -- verifies the same
   way, then prints a fresh limine entry block (via
   `omarchy-boot-build.sh emit-entry`, read-only) and the hand-edit steps.
3. Paste the entry: back up `/boot/EFI/limine/limine.conf` (e.g.
   `sudo cp /boot/EFI/limine/limine.conf /boot/EFI/limine/limine.conf.bak-<UTC>`)
   and replace the stale `/Omarchy ...` title block (title line + its
   indented directives) with the chainload entry from step 2. This paste
   is deliberately manual: `omarchy-boot-provision.sh` fails closed on a
   duplicate title, so it cannot swap the stale block for you.
4. Reboot and pick the entry (staged reboot table below). Nothing here
   reboots the host or touches NVRAM.

### Phase reference (surgical use)

- `seed` bakes the cidata file pair + `cidata.iso` in the secrets home
  (`HNGH_SECRETS_HOME`, default `~/.hngh-automation/omarchy-unattended` --
  never the repo, never `~/.hngh`), workdir 0700. Password hashes go in
  (`--credentials-hash` = `openssl passwd -6` output) and never come out:
  every print says `<redacted>`. `--defer-provisioning` writes an empty
  `cidata/defer-provisioning` marker and NO credentials at all; first-boot
  provisioning then completes from live SSH.
- schema provenance: `seed --iso <iso>` extracts the ISO's own
  `usr/local/bin/omarchy-cidata-load` (bare sfs-relative extraction) and
  reads the exact keys it consumes from `user_configuration.json` /
  `user_credentials.json`; the emitted seed must cover them all or seed
  fails closed naming the gaps. Without `--iso`/`--config-sample` the seed
  still builds but prints a loud `SCHEMA-UNVERIFIED` warning naming what
  was never verified -- suspect it first when the wizard stays interactive.
- `run` installs: pilot by default (qcow2 overlay
  `qemu-img create -f qcow2 -b <DISK> -F raw <workdir>/pilot.qcow2`,
  backing untouched), or `--real-disk`, which FORMATTEDs the disk and
  carries its own y/N gate naming it. The backing must be unmounted, not
  the host system disk, and not held by any qemu. One `sudo -v` up front,
  then y/N per action. A `run-manifest` records mode/target/backing/iso/
  serials/user so `verify` boots exactly what `run` wrote.
- detection proof (host-side): the partition layout must APPEAR on the
  target within minutes -- an unconsumed cidata leaves the wizard
  interactive forever, so the layout change IS the signal (the serial
  stays tiny, ~425 bytes). `run` prints the watch command; no layout after
  ~10 minutes means the cidata was NOT consumed (seed files first).
- `verify` boots the target disk-only (no cdrom) with hostfwd 2222 and
  always kills its VM on exit. Verdict table: `verdict: BOOTED+SSH`
  (serial over 425B + boot marker + ssh probe = proven complete),
  `verdict: BOOT_ONLY` (booted, no ssh: check authorized_keys and the
  user credentials), `verdict: TIMEOUT` (serial never crossed the floor).
- flags: `--disk --iso --credentials-hash --defer-provisioning
  --config-sample --authorized-keys --user --hostname --timezone
  --keyboard --pilot --real-disk --go-real`; `help` prints the full
  contract.

ISO hashes: every published Omarchy ISO has a `.sha256` beside it at the
same URL -- download both into one directory and check the ISO before
seeding (see the omarchy-iso README: https://github.com/omacom/omarchy-iso).

## The entry block (point-in-time example)

Point-in-time example -- run `automation/jobs/omarchy-boot-build.sh
emit-entry` to generate the current block (`full --go-real` prints it at
the end of the two-command flow); it probes the ids at runtime and never
guesses. The literal block below is what was verified
2026-10-05. For the host loader config (/boot/EFI/limine/limine.conf on the host
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

## Driver-first

Run `automation/jobs/omarchy-boot-provision.sh` from your own terminal
first: it drives the steps below and prompts y/N (default N) before each
privileged action. It refuses the esp phase (it would mkfs the live
ESP), backs up /boot/EFI/limine/limine.conf before appending the entry
block, and stops after printing the staged reboot checklist -- it never
reboots and never touches NVRAM. The numbered sequence below stays as
the manual reference and as physical-observation guidance.

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
