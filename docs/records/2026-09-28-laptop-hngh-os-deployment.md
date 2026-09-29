# 2026-09-28 — Laptop hngh-OS deployment (brick, 192.168.0.16)

Operator decision: full wipe, wholly Hngh OS, omarchy-way disk encryption +
passwordless startup (wake-over-LAN friendly; physically secured machine).
Remote drive over ssh (root, key-only) from the hngh live medium.

## Arc

1. **Live medium**: built `hngh-2026.09.28-x86_64.iso` (cachyos-v3 dropped —
   its CDN path served a 988-byte HTML page as the db; pacstrap died on
   "GPGME error: No data"). Console-unlock fix (profile shadow override +
   tty1 autologin drop-in) and live-ssh slice (openssh + key-permission
   service + root authorized_keys) landed as 2853f520 / d9b31a2a / ed75be35
   before this session's build.
2. **Install** (over ssh from live env): rewrote the mkarchiso-generated
   `/etc/pacman.conf` (no servers — same gap as live env), `pacman-key
   --init/--populate`, imported the omarchy packaging key; GPT: sda1 1G ESP
   + sda2 930.5G LUKS2 (keyfile slot 0 + recovery passphrase slot; LUKS-UUID
   `7a4f959e-fbe3-45bc-a3c6-8ba3c73d096b`); btrfs `hngh-root`; pacstrap base
   + linux-cachyos + full omarchy session stack; chroot: fstab, tz, locale,
   hostname `brick-hngh`, mkinitcpio HOOKS+encrypt with keyfile baked into
   the initramfs (verified via lsinitcpio), systemd-boot `Boot0004`,
   sshd key-only + root authorized_keys, ufw default-deny + LAN-scoped 22,
   user `brick` (wheel), root/brick passwords delivered to the operator,
   WOL dispatcher, `enable NetworkManager sshd systemd-timesyncd ufw`.
3. **Recovery**: first boot prompted for the LUKS passphrase — the `encrypt`
   hook ignores `/etc/crypttab.initramfs` (that is the `sd-encrypt` hook's
   input); keyfile unlock requires the kernel cmdline. Fix: append
   `cryptkey=rootfs:/boot/hngh-keyfile.bin` to the loader entry options.
   Verified: two consecutive unattended reboots reached ssh in ~30 s.
4. **hngh install tail**: prereqs (git sbcl jq make; flock/sqlite/python/
   curl preinstalled), clone at `/root/Projects/etc/hngh`,
   `install.sh --non-interactive` (all stages), smoke green except the
   daily-digest checks (fresh box — digest materializes on first cadence
   run; no secrets on the laptop yet, so no model output until then),
   `loginctl enable-linger root` + `make enable` (dashboard :8890 + hourly/
   4h/06-09/night-agent/report/research/bench/autonomy/credential-health/
   cadence timer set), permissions profile mirrored from the desktop, ufw
   LAN rule for 8890 (dashboard answers 403 unauthenticated, by design).

## Gaps found (installer/ISO follow-ups, not blockers)

- Installed system inherits the live-env pacman.conf server gap
  (mkarchiso-generated conf + stock commented mirrorlist); had to rewrite
  it before any pacman install on the fresh system.
- `make` is not in the pacstrap set; smoke/enable need it.
- Console autologin had to be added on the installed system (the profile's
  tty1 drop-in covers the live env only).

## State

Laptop: wholly Hngh OS, encrypted, passwordless boot, hngh tier live,
LAN-reachable dashboard (token-gated), wake-over-LAN dispatcher installed.
Credentials were delivered out-of-band to the operator (recovery passphrase,
root and brick passwords); nothing sensitive is recorded in-repo.

## Tier migration to brick (same day, follow-up)

The tier was initially deployed under root (root's home + user units).
Migrated to the desktop model: cloned + `install.sh --non-interactive` +
`make enable` as `brick` (linger enabled; `su` sessions need explicit
`XDG_RUNTIME_DIR=/run/user/<uid>` + `DBUS_SESSION_BUS_ADDRESS` for
`systemctl --user` — ssh/su sessions do not carry them), permissions
profile mirrored to `/home/brick/.hngh-automation/`, root-tier units
stopped and root linger disabled (root's user manager retired entirely).
Verified: root-dash inactive, brick-dash active on :8890, desktop curl
gets the token-gated 403. Console autologin switched root -> brick on
tty1 (the GUI live-session pattern: `.zprofile` uwsm hook lands with the
scripted-installer slice; installer codification in flight).

Installer-relevant gap re-confirmed on the installed target: `su`-based
user-manager access is the friction point for any headless tier work —
the scripted installer should enable linger + run `make enable` through
`machinectl shell <user>@` or the explicit-env pattern above.

## Same day, later — installer codified into the live ISO (follow-up)

The arc above is now a script:
`automation/iso/profile/airootfs/root/install-hngh-os.sh`, so the next
machine is boot stick -> omarchy graphical session -> one command. It
replays every step this record verified by hand, in the same order, and
fails closed (exit 3 with remediation text) at each gate the arc learned
to check: UEFI vars present, tools installed (the live env needs
`pacman -Sy --needed arch-install-scripts sgdisk cryptsetup btrfs-progs
dosfstools ufw ethtool efibootmgr archlinux-keyring make git jq`), the
omarchy signing key imported, network up, `DESTROY` typed to wipe, the
recovery passphrase typed back correctly (3 attempts, or `--yes` for
scripted runs), the keyfile 4096 bytes on the ESP, exactly 2 LUKS
keyslots, the keyfile **proven inside the initramfs via lsinitcpio
before systemd-boot is configured**, sudoers valid, authorized_keys
present (key-only sshd would otherwise lock everyone out), fstab
complete. Inputs are flags, env, or interactive prompts:
TARGET_DISK (/dev/sda), HOSTNAME (brick-hngh; read via printenv because
bash seeds an unexported $HOSTNAME from the live medium), TIER_USER
(brick), optional WIFI_SSID/WIFI_PASS, --gen-passwords, --yes.

Two arc gaps are encoded rather than repeated: the target's serverless
pacman.conf (installer copies the live env's baked conf + resolv.conf
before the tail), and `make enable` — a chroot has no systemd user
manager, so the installer wires a self-disabling
`hngh-firstboot.service` user unit (retry loop, logger fallback; linger
is already set) that runs `make enable` on the first boot, which is
exactly when the arc ran it. The recovery card (LUKS uuid, recovery
passphrase, root + tier passwords, boot entry, firewall posture) is
printed at the end, with a reboot prompt.

The live env itself now boots to the omarchy session: airootfs adds
`liveuser` (wheel + device groups, NOPASSWD sudo), tty1 autologin
targets it (root GUI session unsupported; root ssh stays key-only), and
a tty1-guarded `/etc/skel/.zprofile` runs `exec uwsm start hyprland`.
The installer copies that hook to the tier user, since the target's
skel is generated post-build. `--tier-migrate` codifies the f2b1cee0
retier for already-installed boxes: stop/disable the old tier's hngh-*
user units, move ~/.hngh-automation and the repo to the new tier home,
enable-linger + install.sh + make smoke (noted) + make enable under the
explicit XDG_RUNTIME_DIR/DBUS_SESSION_BUS_ADDRESS pattern this record
identified as the friction point, verify the :8890 listener uid belongs
to the NEW tier, then retire the old tier's linger and flip tty1
autologin.

Tests red-first in `automation/tests/test-iso-build.sh` (sections g–i,
20 assertions): all NOT OK before the files existed, all green after
(suite 31 ok / 0 fail). The ISO itself was NOT rebuilt here — needs
operator sudo; the profile is ready for the next build-live-iso run.
