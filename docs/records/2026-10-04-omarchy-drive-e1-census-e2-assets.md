# 2026-10-04 — Omarchy drive E1 census + E2 assets (harness-skeleton program, phase E)

Operator decision (2026-10-04, "Drive the install") scoped E1/E2 as
machine-executable with E3/E4 privileged steps parked with exact
commands. This record covers the unprivileged portion, executed against
the powered-off target's btrfs root mounted read-write via udisks at
`/run/media/bricker/f5b8200b-76ee-41f6-a4dd-9216f8358836` (subvolid=5;
`@`, `@home`, `@factory`, `@log`, `@pkg`).

## E1 census (verified facts)

- OS: Omarchy 4.0.4 (os-release ID=omarchy), hostname
  `brickertop-omarchy`, machine-id
  `dc6b04192f8b4bf5b336f86c70a0b28e`.
- Boot layer MISSING (the E3 blocker): the ESP nvme0n1p1 is blank;
  `@/boot` holds no vmlinuz/initramfs; `/etc/mkinitcpio.d` is EMPTY (no
  preset, so `mkinitcpio -P` would produce nothing);
  HOOKS=(base systemd autodetect microcode modconf kms keyboard
  sd-vconsole block filesystems fsck) carry no limine hook. E3 must
  chroot, `pacman -S linux-omarchy` (lays /boot files), restore/write
  `/etc/mkinitcpio.d/linux-omarchy.preset`, add the limine hook,
  `mkinitcpio -P`, then limine + efibootmgr per omarchy tooling.
- fstab pins the ESP: `UUID=317A-31FF /boot vfat ... 0 2` — E3's
  `mkfs.vfat` MUST force the volume id (`-i 317A31FF`) or the pinned
  UUID breaks. `/swap/swapfile` swap entry present (hibernation
  intended; resume wiring unverified).
- Zero hngh footprint before E2: no hngh-* units under `@/etc/systemd`
  or `@/usr/lib/systemd`; `@home/bricker` had no `.hngh`, no
  `.hngh-automation`, no `Projects`, no environment.d;
  `.config/systemd/user` held only an empty `default.target.wants`.
- Config present for adopt: `.config/{hypr (7 lua/conf files),
  foot/foot.ini, omarchy/{shell.json,branding,extensions,hooks,themed,themes}}`;
  `.ssh` contains authorized_keys only.
- btrfs scrub: "no stats available ... no errors found" — never
  scrubbed; `scrub start` is privileged (operator option post-boot).
- Target uid 1000/1000 matches the host user, so user-space writes
  land correctly owned.

## E2 assets placed (unprivileged, verified by readback)

- Checkout: clone at eb404cb9 ->
  `@home/bricker/Projects/etc/hngh`, origin reset to
  https://github.com/boundring/hngh.git (satisfies
  hngh-dashboard.service ExecStart
  `%h/Projects/etc/hngh/automation/dashboard-server.py` and its
  WorkingDirectory).
- Upstream: clone at the omarchy-base.packages pin 3faafba ->
  `@home/bricker/Projects/etc/omarchy-upstream`, origin
  https://github.com/omarchy/omarchy.git (satisfies the adopt seam's
  upstream contract and the readiness beat's clone boolean on target).
- Units: all 27 `automation/systemd` files copied to
  `.config/systemd/user/`; 13 timer symlinks (`../<name>.timer`) in
  `timers.target.wants` (automation, security, morning, night-agent,
  morning-report, night-research, model-bench, autonomy,
  credential-health, cadence-subhour, cadence-hour, cadence-calendar,
  overnight-lead); `../hngh-dashboard.service` in
  `default.target.wants` — mirroring `make enable`'s
  systemctl --user enable set.
- Homes: `.hngh/{newspaper,manga,wiki,db,dispatch,imagegen,archive/digest}`
  plus an empty `catalog.tsv` (the `automation/lib/hngh_home.py`
  layout contract), and `.hngh-automation/README.md` documenting the
  two-home rule, the 1Password seam, and the `op account list` probe.
- Adopt DRY-RUN against the target home with the target-side upstream:
  `copy=0 skip=12 backup=5`. Files that differ (would be `.bak` +
  replaced): `hypr/bindings.lua`, `hypr/input.lua`,
  `hypr/monitors.lua`, `omarchy/shell.json`,
  `omarchy/hooks/pre-refresh-pacman.d/add-custom-repo.sample`. The
  real run is DEFERRED to the operator: it mutates the machine's live
  desktop config pre-first-boot.
- Linger: NOT placed — `/var/lib/systemd/linger` is root-owned on the
  target (user-side touch denied); moved to the E3 block.

## Parked with operator (E3/E4, exact commands)

1. Boot layer: mount ESP + `arch-chroot`, `pacman -S linux-omarchy`,
   restore `/etc/mkinitcpio.d/linux-omarchy.preset`, add the limine
   hook to HOOKS, `mkinitcpio -P`, limine install + `efibootmgr`.
2. ESP format preserving the pinned UUID:
   `mkfs.vfat -i 317A31FF /dev/nvme0n1p1`.
3. `loginctl enable-linger bricker` (or `touch
   /var/lib/systemd/linger/bricker` in the chroot).
4. First-boot real adopt run:
   `OMARCHY_UPSTREAM_DIR=~/Projects/etc/omarchy-upstream bash
   ~/Projects/etc/hngh/automation/jobs/omarchy-config-adopt.sh`
   (five files land as `.bak` twins).
5. Optional: `btrfs scrub start -B /` after the first healthy boot.
6. E4: QEMU boot proof of the qcow2 overlay (headless, serial console).

## Verification

Every placement above was verified by readback: clone heads + origin
URLs, unit count 27, 13 timer want-links, the dashboard service
symlink target, the homes listing, and the adopt dry-run summary line.
The smoke-test digest-path fix shipped separately was verified
hermetically (fixture present -> both assertions OK; absent -> both
BAD) against the verbatim production lines.
