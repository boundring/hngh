#!/usr/bin/env bash
# install-hngh-os.sh — codified 2026-09-28 laptop deployment arc
# (docs/records/2026-09-28-laptop-hngh-os-deployment.md): boot the hngh live
# ISO -> omarchy session (liveuser, foot) -> ONE script installs a wholly
# Hngh OS: GPT + LUKS2 (keyfile slot 0, recovery passphrase slot) + btrfs
# + systemd-boot with keyfile unlock + key-only sshd + ufw + tier user +
# hngh tail. Every step mirrors what the arc verified by hand.
#
# Modes:
#   default         full-disk install of TARGET_DISK from the live env.
#   --tier-migrate  retier an ALREADY-INSTALLED hngh box to a new tier user
#                   (stop old units -> enable new -> verify :8890 owner ->
#                   retire old linger; f2b1cee0 migration record).
# Exit: 0 ok; 2 usage; 3 fail-closed verification failure (nothing half-
# verified proceeds: missing tools, unreadable keyfile, lsinitcpio miss,
# clone failure all abort with remediation text).
set -euo pipefail

REPO_URL="https://github.com/boundring/hngh.git"
TIMEZONE="America/New_York"
LOCALE="en_US.UTF-8"
LAN="192.168.0.0/24"
DASH_PORT="8890"
MAPPER="hngh-root"
OMARCHY_GPG_FINGERPRINT="40DFB630FF42BCFFB047046CF0134EE680CAC571"
KEYFILE="/run/hngh-keyfile.bin"

MODE="install"
TTY=/dev/tty
[ -r "$TTY" ] || TTY=""
MOUNTED=""
OPENED=""
LUKS_UUID=""

usage() {
 cat <<'EOF'
usage: install-hngh-os.sh [--tier-migrate] [options]

install mode (from the hngh live ISO; wipes TARGET_DISK):
  --target-disk DEV       target disk (env TARGET_DISK, default /dev/sda)
  --hostname NAME         (env HOSTNAME, default brick-hngh)
  --tier-user NAME        (env TIER_USER, default brick)
  --wifi-ssid SSID / --wifi-pass PASS   optional Wi-Fi before pacstrap
  --gen-passwords         generate + print root/tier passwords
  --yes                   non-interactive: skips typed confirmations
                          (wipe, recovery passphrase, reboot prompt)

--tier-migrate mode (on an ALREADY-INSTALLED hngh system):
  --user NAME             new tier user (alias --tier-user)
  --from-user NAME        old tier user (default: auto-detect the single
                          linger user with an hngh-automation home)

Exit: 0 ok; 2 usage; 3 fail-closed failure.
EOF
}

info() { printf 'install-hngh-os: %s\n' "$*"; }
die() { # die MESSAGE [REMEDIATION]
 printf 'install-hngh-os: FATAL: %s\n' "$1" >&2
 [ $# -ge 2 ] && printf 'install-hngh-os: remediation: %s\n' "$2" >&2
 exit 3
}

ask() { # ask PROMPT DEFAULT -> sets REPLY (falls back to DEFAULT w/o tty)
 local prompt="$1" def="$2"
 REPLY=""
 if [ -n "$TTY" ]; then
  printf '%s [%s]: ' "$prompt" "$def" >&2
  IFS= read -r REPLY <"$TTY" || REPLY=""
 fi
 : "${REPLY:=$def}"
}

ask_secret() { # ask_secret PROMPT -> sets REPLY
 local prompt="$1"
 REPLY=""
 if [ -n "$TTY" ]; then
  read -rsp "$prompt" REPLY <"$TTY"
  printf '\n' >&2
 fi
}

cleanup() {
 [ -n "$MOUNTED" ] && umount -R /mnt 2>/dev/null
 [ -n "$OPENED" ] && cryptsetup close "$MAPPER" 2>/dev/null
 return 0
}
trap cleanup EXIT

# --- inputs (flags > env > interactive prompt > default) -------------------
# HOSTNAME is resolved via printenv on purpose: bash seeds an unexported
# $HOSTNAME from the live medium ("hngh-live") and that must not override
# the brick-hngh default — only an explicitly exported HOSTNAME counts.
_env() { printenv "$1" 2>/dev/null || true; }

TARGET_DISK="$(_env TARGET_DISK)"
: "${TARGET_DISK:=/dev/sda}"
HOSTNAME_VALUE="$(_env HOSTNAME)"
: "${HOSTNAME_VALUE:=brick-hngh}"
TIER_USER="$(_env TIER_USER)"
: "${TIER_USER:=brick}"
FROM_USER="$(_env HNGH_FROM_USER)"
WIFI_SSID="$(_env WIFI_SSID)"
WIFI_PASS="$(_env WIFI_PASS)"
ASSUME_YES="${ASSUME_YES:-}"
GEN_PASSWORDS="${GEN_PASSWORDS:-}"

while [ $# -gt 0 ]; do
 case "$1" in
 --tier-migrate)
  MODE="migrate"
  shift
  ;;
 --target-disk)
  [ $# -ge 2 ] || {
   usage >&2
   exit 2
  }
  TARGET_DISK="$2"
  shift 2
  ;;
 --hostname)
  [ $# -ge 2 ] || {
   usage >&2
   exit 2
  }
  HOSTNAME_VALUE="$2"
  shift 2
  ;;
 --tier-user | --user)
  [ $# -ge 2 ] || {
   usage >&2
   exit 2
  }
  TIER_USER="$2"
  shift 2
  ;;
 --from-user)
  [ $# -ge 2 ] || {
   usage >&2
   exit 2
  }
  FROM_USER="$2"
  shift 2
  ;;
 --wifi-ssid)
  [ $# -ge 2 ] || {
   usage >&2
   exit 2
  }
  WIFI_SSID="$2"
  shift 2
  ;;
 --wifi-pass)
  [ $# -ge 2 ] || {
   usage >&2
   exit 2
  }
  WIFI_PASS="$2"
  shift 2
  ;;
 --yes)
  ASSUME_YES=1
  shift
  ;;
 --gen-passwords)
  GEN_PASSWORDS=1
  shift
  ;;
 -h | --help)
  usage
  exit 0
  ;;
 *)
  usage >&2
  exit 2
  ;;
 esac
done

[ "$(id -u)" -eq 0 ] ||
 die "must run as root" "run from the hngh live ISO (liveuser has passwordless sudo: sudo bash install-hngh-os.sh)"

# --- shared helpers ---------------------------------------------------------
have_tools() { # have_tools REMEDIATION TOOL...
 local missing=""
 local t
 shift # first arg is the remediation text
 for t in "$@"; do
  command -v "$t" >/dev/null 2>&1 || missing="$missing $t"
 done
 [ -z "$missing" ] || die "missing tools:$missing" "$1"
}

as_user() { # as_user USER CMD... — run with the user-manager env (record
 # f2b1cee0: su/ssh sessions lack XDG_RUNTIME_DIR/DBUS_SESSION_BUS_ADDRESS,
 # without them systemctl --user fails; machinectl shell <user>@.host is
 # the interactive equivalent).
 local u="$1" uid
 shift
 uid="$(id -u "$u")"
 sudo -u "$u" env \
  XDG_RUNTIME_DIR="/run/user/$uid" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$uid/bus" \
  "$@"
}

user_home() { getent passwd "$1" | cut -d: -f6; }

ensure_zprofile() { # ensure_zprofile USER — skel hook lands the omarchy
 # session on tty1; explicit for users that predate it
 local home
 home="$(user_home "$1")"
 [ -f "$home/.zprofile" ] && return 0
 [ -f /etc/skel/.zprofile ] ||
  die "/etc/skel/.zprofile missing" "the installed profile ships it; re-pull the repo or restore the file"
 install -m 644 /etc/skel/.zprofile "$home/.zprofile"
 chown "$1:$1" "$home/.zprofile"
}

set_password() { # set_password USER — interactive prompt, or generated +
 # printed (scripted runs); returns the value in REPLY
 local u="$1" pw pw2
 if [ -n "$GEN_PASSWORDS" ] || [ -z "$TTY" ]; then
  pw="$(head -c 18 /dev/urandom | base64 | tr -d '\n')"
  info "$u password generated: $pw"
 else
  while :; do
   ask_secret "$u password: "
   pw="$REPLY"
   ask_secret "$u password (again): "
   pw2="$REPLY"
   [ -n "$pw" ] && [ "$pw" = "$pw2" ] && break
   printf 'install-hngh-os: passwords empty or differ, retry\n' >&2
  done
 fi
 REPLY="$pw"
}

# ===========================================================================
# MIGRATE MODE — retier an installed hngh box (f2b1cee0 record)
# ===========================================================================
if [ "$MODE" = migrate ]; then
 have_tools "install the hngh OS first (this mode runs ON an installed hngh system)" \
  systemctl loginctl sudo ss git make useradd getent

 # --- new tier user -------------------------------------------------------
 id "$TIER_USER" >/dev/null 2>&1 ||
  useradd -m -G wheel -s /bin/bash "$TIER_USER"
 if [ ! -f /etc/sudoers.d/10-wheel ]; then
  printf '%%wheel ALL=(ALL:ALL) ALL\n' >/etc/sudoers.d/10-wheel
  chmod 440 /etc/sudoers.d/10-wheel
 fi
 visudo -c >/dev/null || die "sudoers invalid" "fix /etc/sudoers* output above, then re-run"
 ensure_zprofile "$TIER_USER"

 # console follows the tier (f2b1cee0: autologin switched root -> brick)
 mkdir -p /etc/systemd/system/getty@tty1.service.d
 # shellcheck disable=SC2016  # $TERM must stay literal in the drop-in
 printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin %s --noclear %%I $TERM\n' \
  "$TIER_USER" >/etc/systemd/system/getty@tty1.service.d/autologin.conf
 systemctl daemon-reload

 # --- old tier: explicit --from-user, else the single hngh linger user ----
 OLD=""
 if [ -n "$FROM_USER" ]; then
  OLD="$FROM_USER"
 else
  old_candidates=""
  for f in /var/lib/systemd/linger/*; do
   [ -e "$f" ] || continue
   u="${f##*/}"
   [ "$u" = "$TIER_USER" ] && continue
   [ -d "$(user_home "$u")/.hngh-automation" ] && old_candidates="$old_candidates $u"
  done
  # shellcheck disable=SC2086
  n=$(
   set -- $old_candidates
   echo $#
  )
  if [ "$n" -eq 1 ]; then
   OLD="${old_candidates# }"
  elif [ "$n" -gt 1 ]; then
   die "ambiguous old tier:$old_candidates" "pass --from-user NAME to pick the tier to retire"
  else
   info "no prior tier found (no other linger user with an hngh-automation home) — enable-only run"
  fi
 fi

 # --- STOP OLD ------------------------------------------------------------
 # both tiers bind :8890 and both run hngh-*.timer beats: enabling the new
 # tier while the old one still runs guarantees a bind failure and
 # double-fired beats. Old units stop and disable FIRST.
 if [ -n "$OLD" ]; then
  old_units="$(as_user "$OLD" systemctl --user list-unit-files 'hngh-*' --no-legend 2>/dev/null |
   awk '{print $1}')" || old_units=""
  if [ -n "$old_units" ]; then
   # shellcheck disable=SC2086  # word-split list of unit names is the point
   if ! as_user "$OLD" systemctl --user stop $old_units; then
    info "old tier manager unreachable — its units cannot be running"
   fi
   # shellcheck disable=SC2086
   as_user "$OLD" systemctl --user disable $old_units >/dev/null 2>&1 || true
   info "STOP OLD: stopped + disabled:$old_units"
  else
   info "STOP OLD: no hngh user units for $OLD"
  fi
 fi

 # hngh homes follow the tier
 move_if_absent() { # move_if_absent SRC DEST OWNER
  local src="$1" dst="$2" owner="$3"
  [ -e "$src" ] || return 0
  if [ -e "$dst" ]; then
   info "both exist — keeping $dst (left $src in place)"
   return 0
  fi
  mkdir -p "$(dirname "$dst")"
  mv "$src" "$dst"
  chown -R "$owner" "$dst"
  info "moved $src -> $dst"
 }
 NEW_HOME="$(user_home "$TIER_USER")"
 if [ -n "$OLD" ]; then
  OLD_HOME="$(user_home "$OLD")"
  move_if_absent "$OLD_HOME/.hngh-automation" "$NEW_HOME/.hngh-automation" "$TIER_USER:"
  move_if_absent "$OLD_HOME/Projects/etc/hngh" "$NEW_HOME/Projects/etc/hngh" "$TIER_USER:"
 fi

 # --- ENABLE NEW ----------------------------------------------------------
 loginctl enable-linger "$TIER_USER"
 if [ ! -d "$NEW_HOME/Projects/etc/hngh" ]; then
  sudo -u "$TIER_USER" git clone "$REPO_URL" "$NEW_HOME/Projects/etc/hngh" ||
   die "tier-user clone failed" \
    "check network and $REPO_URL reachability (auth? grant HTTPS access or a deploy key), then re-run --tier-migrate"
 fi
 as_user "$TIER_USER" bash -lc 'cd ~/Projects/etc/hngh && bash install.sh --non-interactive' ||
  die "install.sh --non-interactive failed for $TIER_USER" \
   "inspect the output above; repo at $NEW_HOME/Projects/etc/hngh, then re-run"
 if ! as_user "$TIER_USER" bash -lc 'cd ~/Projects/etc/hngh && make -C automation smoke'; then
  info "make smoke reported failures — NOTED, continuing: fresh-tier digest checks fail until the first cadence run (2026-09-28 arc precedent)"
 fi
 as_user "$TIER_USER" bash -lc 'cd ~/Projects/etc/hngh && make -C automation enable' ||
  die "make enable failed for $TIER_USER" \
   "check journalctl --user -u hngh-dashboard; user-manager env: XDG_RUNTIME_DIR=/run/user/$(id -u "$TIER_USER") DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u "$TIER_USER")/bus"

 # --- VERIFY PORT OWNER ---------------------------------------------------
 sleep 1
 port_line="$(ss -tlnpe "( sport = :$DASH_PORT )" | sed -n '2p')"
 [ -n "$port_line" ] ||
  die "nothing listens on :$DASH_PORT after make enable" \
   "check journalctl --user -u hngh-dashboard.service as $TIER_USER"
 port_uid="$(printf '%s\n' "$port_line" | grep -o 'uid=[0-9]*' | head -n1 | cut -d= -f2)"
 [ "$port_uid" = "$(id -u "$TIER_USER")" ] ||
  die ":$DASH_PORT owned by uid ${port_uid:-?}, not $TIER_USER" \
   "the old tier dashboard is still running — stop it (see STOP OLD above) and re-run --tier-migrate"
 info "VERIFY PORT OWNER: :$DASH_PORT held by $TIER_USER (uid $port_uid)"

 # --- RETIRE OLD LINGER ---------------------------------------------------
 if [ -n "$OLD" ]; then
  loginctl disable-linger "$OLD"
  info "RETIRE OLD LINGER: $OLD linger disabled (user manager retired)"
 fi

 cat <<EOF

================ hngh tier migration card ================
 new tier:      $TIER_USER ($NEW_HOME) — linger on, wheel + sudoers
 old tier:      ${OLD:-none} — units stopped/disabled, linger off
 dashboard:     :$DASH_PORT verified owned by $TIER_USER
 console:       tty1 autologin -> $TIER_USER (omarchy via .zprofile uwsm)
 verify:        ssh root@<host>; ss -tlnpe '( sport = :$DASH_PORT )'
==========================================================
EOF
 exit 0
fi

# ===========================================================================
# INSTALL MODE — the 2026-09-28 arc, scripted
# ===========================================================================
have_tools "run from the hngh live ISO; the arc installed the installer deps into the live env with: sudo pacman -Sy --needed arch-install-scripts sgdisk cryptsetup btrfs-progs dosfstools ufw ethtool efibootmgr archlinux-keyring make git jq" \
 sgdisk cryptsetup mkfs.btrfs mkfs.vfat pacstrap genfstab arch-chroot lsinitcpio nmcli timedatectl ping visudo

mountpoint -q /mnt &&
 die "/mnt already mounted" "unmount it first (umount -R /mnt; cryptsetup close $MAPPER) — a stale mount means a previous run died mid-flight"

# --- preflight: UEFI, RTC/NTP, network (arc step 1) -------------------------
[ -d /sys/firmware/efi/efivars ] ||
 die "not booted in UEFI mode" "boot the hngh live ISO in UEFI mode — BIOS/CSM would leave a systemd-boot entry that cannot boot"

# NTP-ish RTC: pacstrap GPG checks need a sane clock (the arc synced first)
timedatectl set-ntp true
for _ in 1 2 3 4 5 6 7 8 9 10; do
 [ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" = yes ] && break
 sleep 2
done
[ "$(timedatectl show -p NTPSynchronized --value 2>/dev/null)" = yes ] ||
 info "WARN: clock not NTP-synchronized yet — GPG verification fails if the RTC is far off"

# the arc imported the omarchy packaging key before pacstrap could verify
# the [omarchy] repo (baked pacman.conf ships the repo, not the key)
if ! pacman-key --list-keys "$OMARCHY_GPG_FINGERPRINT" >/dev/null 2>&1; then
 if ! pacman-key --recv-keys "$OMARCHY_GPG_FINGERPRINT" --keyserver keys.openpgp.org ||
  ! pacman-key --lsign-key "$OMARCHY_GPG_FINGERPRINT"; then
  die "omarchy signing key import failed" \
   "check network to keys.openpgp.org, then re-run (arc command: pacman-key --recv-keys $OMARCHY_GPG_FINGERPRINT --keyserver keys.openpgp.org && pacman-key --lsign-key $OMARCHY_GPG_FINGERPRINT)"
 fi
fi

if [ -n "$WIFI_SSID" ]; then
 # shellcheck disable=SC2086  # deliberate empty-arg elision without --yes
 nmcli device wifi connect "$WIFI_SSID" ${WIFI_PASS:+password "$WIFI_PASS"} ||
  die "Wi-Fi connect failed for $WIFI_SSID" \
   "check SSID/password; or plug ethernet and re-run without --wifi-*"
fi
ping -c1 -W3 1.1.1.1 >/dev/null 2>&1 ||
 die "no network" "connect ethernet or pass --wifi-ssid/--wifi-pass — pacstrap needs the mirrors"

# --- interactive inputs -----------------------------------------------------
if [ -z "${ASSUME_YES:-}" ] && [ -n "$TTY" ]; then
 lsblk -dn -o NAME,SIZE,MODEL "$TARGET_DISK" 2>/dev/null || true
 ask "Target disk to DESTROY (TARGET_DISK)" "$TARGET_DISK"
 TARGET_DISK="$REPLY"
 ask "Hostname (HOSTNAME)" "$HOSTNAME_VALUE"
 HOSTNAME_VALUE="$REPLY"
 ask "Tier user (TIER_USER)" "$TIER_USER"
 TIER_USER="$REPLY"
 if [ -z "$WIFI_SSID" ]; then
  ask "Wi-Fi SSID (empty = ethernet)" ""
  if [ -n "$REPLY" ]; then
   WIFI_SSID="$REPLY"
   ask_secret "Wi-Fi passphrase: "
   WIFI_PASS="$REPLY"
  fi
 fi
fi

[ -b "$TARGET_DISK" ] ||
 die "not a block device: $TARGET_DISK" "pass --target-disk /dev/nvme0n1 (or TARGET_DISK env) — lsblk lists candidates"
if [ -z "${ASSUME_YES:-}" ]; then
 ask "About to DESTROY ALL DATA on $TARGET_DISK — type DESTROY to continue" ""
 [ "$REPLY" = DESTROY ] ||
  die "wipe confirmation != DESTROY" "nothing was written to $TARGET_DISK; re-run when sure"
fi

case "$TARGET_DISK" in
*/nvme* | */mmcblk*)
 PART1="${TARGET_DISK}p1"
 PART2="${TARGET_DISK}p2"
 ;;
*)
 PART1="${TARGET_DISK}1"
 PART2="${TARGET_DISK}2"
 ;;
esac

# --- wipe + GPT: ESP 1G + rest linux (arc step 2) ---------------------------
sgdisk --zap-all "$TARGET_DISK"
sgdisk -n 1:0:+1G -t 1:C12A7328-F81F-11D2-BA4B-00A0C93EC93B \
 -n 2:0:0 -t 2:8300 "$TARGET_DISK"
partprobe "$TARGET_DISK"
sleep 1

# --- LUKS2: keyfile slot 0 + recovery passphrase slot (arc step 2) ----------
dd if=/dev/urandom of="$KEYFILE" bs=4096 count=1 status=none
chmod 600 "$KEYFILE"
cryptsetup luksFormat --type luks2 --batch-mode "$PART2" "$KEYFILE" ||
 die "luksFormat failed" "check $PART2 exists (lsblk); dmesg for device errors"

RECOVERY="$(head -c 18 /dev/urandom | base64 | tr -d '\n')"
printf '\n  RECOVERY PASSPHRASE (unlocks without the keyfile — WRITE IT DOWN):\n  %s\n\n' "$RECOVERY"
if [ -n "${ASSUME_YES:-}" ]; then
 info "--yes: skipping the typed recovery-passphrase confirmation (scripted run)"
elif [ -z "$TTY" ]; then
 die "no TTY for the typed recovery-passphrase confirmation" \
  "run interactively, or pass --yes for a fully scripted run (the passphrase is printed above)"
else
 confirmed=""
 for _ in 1 2 3; do
  ask_secret "Type the recovery passphrase to confirm: "
  if [ "$REPLY" = "$RECOVERY" ]; then
   confirmed=1
   break
  fi
  printf 'install-hngh-os: mismatch, retry\n' >&2
 done
 [ -n "$confirmed" ] ||
  die "recovery passphrase confirmation failed after 3 attempts" \
   "the passphrase is printed above; nothing beyond the wipe + format happened, re-run and copy it exactly"
fi

printf '%s\n' "$RECOVERY" | cryptsetup luksAddKey "$PART2" --key-file "$KEYFILE" ||
 die "luksAddKey failed" "recovery passphrase slot not added; re-run"
[ "$(cryptsetup luksDump "$PART2" | grep -c ENABLED)" -eq 2 ] ||
 die "LUKS header does not show exactly 2 enabled keyslots" \
  "expected keyfile (slot 0) + recovery passphrase (slot 1); inspect: cryptsetup luksDump $PART2"

cryptsetup open --key-file "$KEYFILE" "$PART2" "$MAPPER" ||
 die "failed to open $PART2 as $MAPPER" "check the keyfile: cryptsetup luksDump $PART2; re-run"
OPENED=1
LUKS_UUID="$(cryptsetup luksUUID "$PART2")"

# --- filesystems + mounts (arc step 2) --------------------------------------
mkfs.btrfs -L "$MAPPER" "/dev/mapper/$MAPPER"
mkfs.vfat -n HNGH-EFI -F 32 "$PART1"
mount "/dev/mapper/$MAPPER" /mnt
MOUNTED=1
mount --mkdir "$PART1" /mnt/boot

install -m 600 "$KEYFILE" /mnt/boot/hngh-keyfile.bin
[ "$(wc -c </mnt/boot/hngh-keyfile.bin)" -eq 4096 ] ||
 die "keyfile unreadable/wrong size on the ESP" \
  "the keyfile is the only passwordless-boot secret — verify /mnt/boot/hngh-keyfile.bin (expect 4096 bytes) and re-run"

# --- pacstrap: the exact verified set (arc step 2 + gap fixes: make, repos) --
PKGS=(
 base linux-cachyos linux-cachyos-headers linux-firmware amd-ucode intel-ucode
 mkinitcpio networkmanager sudo openssh terminus-font efibootmgr ufw ethtool
 archlinux-keyring cachyos-keyring cachyos-mirrorlist make git jq
 hyprland uwsm quickshell foot foot-terminfo
 xdg-desktop-portal-hyprland xdg-desktop-portal-gtk hyprland-guiutils
 hyprland-preview-share-picker hyprpicker hyprsunset grim slurp cliphist
 wl-clipboard wtype brightnessctl pamixer pipewire wireplumber xdg-terminal-exec
 owe owe-lockfeed
)
pacstrap -K /mnt "${PKGS[@]}"

# gap fixes recorded on 2026-09-28: the target inherits a serverless
# pacman.conf from mkarchiso (no working repos) — the live env's baked conf
# is self-contained, hand it over; DNS comes along for the tail's network.
install -m 644 /etc/pacman.conf /mnt/etc/pacman.conf
cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null ||
 info "WARN: no resolv.conf to copy — the tail may lack DNS"

genfstab -U /mnt >>/mnt/etc/fstab
grep -q 'btrfs' /mnt/etc/fstab ||
 die "fstab has no btrfs root entry" "genfstab produced a broken fstab; inspect /mnt/etc/fstab and re-run"
grep -q 'vfat' /mnt/etc/fstab ||
 die "fstab has no ESP entry" "genfstab produced a broken fstab; inspect /mnt/etc/fstab and re-run"

# --- chroot configuration (arc step 2) --------------------------------------
arch-chroot /mnt ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
arch-chroot /mnt hwclock --systohc

sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
grep -q '^en_US.UTF-8 UTF-8' /mnt/etc/locale.gen ||
 printf 'en_US.UTF-8 UTF-8\n' >>/mnt/etc/locale.gen
arch-chroot /mnt locale-gen
printf 'LANG=%s\n' "$LOCALE" >/mnt/etc/locale.conf

printf '%s\n' "$HOSTNAME_VALUE" >/mnt/etc/hostname

install -d /mnt/etc/mkinitcpio.conf.d
cat >/mnt/etc/mkinitcpio.conf.d/hngh-encrypt.conf <<'EOF'
# hngh: LUKS2 root + passwordless keyfile unlock (2026-09-28 arc).
# The encrypt hook reads cryptdevice= + cryptkey= from the kernel cmdline;
# the keyfile MUST be baked into the image (installer verifies via
# lsinitcpio before systemd-boot is configured).
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
FILES=(/boot/hngh-keyfile.bin)
EOF
arch-chroot /mnt mkinitcpio -P
[ -f /mnt/boot/initramfs-linux-cachyos.img ] ||
 die "initramfs-linux-cachyos.img missing" \
  "mkinitcpio -P produced nothing — check /mnt/etc/mkinitcpio.conf.d/hngh-encrypt.conf and presets"
lsinitcpio /mnt/boot/initramfs-linux-cachyos.img 2>/dev/null | grep -q hngh-keyfile.bin ||
 die "keyfile NOT in the initramfs (lsinitcpio)" \
  "passwordless boot would fail into a passphrase prompt — check FILES=(/boot/hngh-keyfile.bin) in /mnt/etc/mkinitcpio.conf.d/hngh-encrypt.conf, re-run mkinitcpio -P, then re-run"

arch-chroot /mnt bootctl install
install -d /mnt/boot/loader/entries
printf 'default 01-hngh-linux\ntimeout 3\n' >/mnt/boot/loader/loader.conf
cat >/mnt/boot/loader/entries/01-hngh-linux.conf <<EOF
title   hngh Linux (CachyOS)
linux   /vmlinuz-linux-cachyos
initrd  /initramfs-linux-cachyos.img
options cryptdevice=UUID=$LUKS_UUID:$MAPPER root=/dev/mapper/$MAPPER rw cryptkey=rootfs:/boot/hngh-keyfile.bin
EOF

# sshd: key-only (the arc's recovery path; live-env authorized_keys carries)
[ -s /root/.ssh/authorized_keys ] ||
 die "live env has no /root/.ssh/authorized_keys" \
  "key-only sshd would lock everyone out — copy your key into the live env's /root/.ssh/authorized_keys and re-run"
install -d -m 700 /mnt/root/.ssh
install -m 600 /root/.ssh/authorized_keys /mnt/root/.ssh/authorized_keys
install -d /mnt/etc/ssh/sshd_config.d
printf 'PasswordAuthentication no\nPermitRootLogin prohibit-password\n' \
 >/mnt/etc/ssh/sshd_config.d/10-hngh.conf

# ufw: default deny + ssh + LAN-scoped dashboard (arc step 2)
arch-chroot /mnt ufw default deny incoming
arch-chroot /mnt ufw allow 22/tcp
arch-chroot /mnt ufw allow from "$LAN" to any port "$DASH_PORT" proto tcp
arch-chroot /mnt ufw --force enable

# tier user: wheel + sudoers + tty1 autologin + omarchy session hook
arch-chroot /mnt useradd -m -G wheel -s /bin/bash "$TIER_USER"
printf '%%wheel ALL=(ALL:ALL) ALL\n' >/mnt/etc/sudoers.d/10-wheel
chmod 440 /mnt/etc/sudoers.d/10-wheel
arch-chroot /mnt visudo -c >/dev/null ||
 die "target sudoers invalid" "fix /mnt/etc/sudoers* — %wheel grant broken"
[ -f /etc/skel/.zprofile ] ||
 die "/etc/skel/.zprofile missing in the live env" \
  "the GUI-session hook ships in the ISO profile (etc/skel/.zprofile) — rebuild the ISO or restore the file"
install -m 644 /etc/skel/.zprofile "/mnt/home/$TIER_USER/.zprofile"
arch-chroot /mnt chown "$TIER_USER:$TIER_USER" "/home/$TIER_USER/.zprofile"
install -d /mnt/etc/systemd/system/getty@tty1.service.d
# shellcheck disable=SC2016  # $TERM must stay literal in the drop-in
printf '[Service]\nExecStart=\nExecStart=-/sbin/agetty --autologin %s --noclear %%I $TERM\n' \
 "$TIER_USER" >/mnt/etc/systemd/system/getty@tty1.service.d/autologin.conf

# passwords: interactive, or generated + printed
set_password root
ROOT_PW="$REPLY"
set_password "$TIER_USER"
TIER_PW="$REPLY"
printf 'root:%s\n' "$ROOT_PW" | arch-chroot /mnt chpasswd
printf '%s:%s\n' "$TIER_USER" "$TIER_PW" | arch-chroot /mnt chpasswd

# wake-over-LAN dispatcher: the NIC must hold 'wol g' at sleep time
# (automation/deck/wake-desktop.sh sends the magic packet; ethtool is a
# pacstrap dep). NM reapplies it on every wired link-up.
install -d /mnt/etc/NetworkManager/dispatcher.d
cat >/mnt/etc/NetworkManager/dispatcher.d/70-hngh-wol <<'EOF'
#!/bin/bash
# hngh wake-over-LAN (2026-09-28 arc): reapply wol on wired link-up so a
# magic packet (automation/deck/wake-desktop.sh) can wake the box.
[ "$2" = up ] || exit 0
case "${1:-}" in
en* | eth*) ethtool -s "$1" wol g 2>/dev/null || true ;;
esac
EOF
chmod 755 /mnt/etc/NetworkManager/dispatcher.d/70-hngh-wol

arch-chroot /mnt systemctl enable NetworkManager sshd ufw
# linger via file (loginctl needs a live logind; a chroot has none)
install -d -m 755 /mnt/var/lib/systemd/linger
touch "/mnt/var/lib/systemd/linger/$TIER_USER"

# permissions profile rides along when the live env carries one
if [ -d /root/.hngh-automation ]; then
 cp -a /root/.hngh-automation "/mnt/home/$TIER_USER/.hngh-automation"
 arch-chroot /mnt chown -R "$TIER_USER:$TIER_USER" "/home/$TIER_USER/.hngh-automation"
 info "permissions profile copied from /root/.hngh-automation"
fi

# hngh tail runs NOW except make enable: a chroot has no systemd user
# manager, and systemctl --user cannot act without one. linger IS set, so
# the tier manager starts at first boot and hngh-firstboot fires make enable
# once (the arc ran this exact step on the first-booted target).
install -d -m 700 "/mnt/home/$TIER_USER/.config/systemd/user/default.target.wants"
cat >"/mnt/home/$TIER_USER/.config/systemd/user/hngh-firstboot.service" <<'EOF'
[Unit]
Description=hngh first-boot tier tail: make enable (once)
# Runs when the tier user's manager starts (linger set), then disables
# itself. Retries make enable for ~1 min — the dashboard needs network.
[Service]
Type=oneshot
ExecStart=/usr/bin/bash -c 'for i in 1 2 3 4 5 6; do make -C %h/Projects/etc/hngh/automation enable && exit 0; sleep 10; done; logger -t hngh-firstboot "make enable failed after retries — run: make -C ~/Projects/etc/hngh/automation enable"'
ExecStartPost=/usr/bin/systemctl --user disable hngh-firstboot.service
[Install]
WantedBy=default.target
EOF
ln -sfn hngh-firstboot.service \
 "/mnt/home/$TIER_USER/.config/systemd/user/default.target.wants/hngh-firstboot.service"
arch-chroot /mnt chown -R "$TIER_USER:$TIER_USER" "/home/$TIER_USER/.config"

# --- hngh tail as the tier user (arc step 4) ---------------------------------
if ! arch-chroot /mnt sudo -iu "$TIER_USER" -- test -d ~/Projects/etc/hngh; then
 arch-chroot /mnt sudo -iu "$TIER_USER" -- git clone "$REPO_URL" ~/Projects/etc/hngh ||
  die "tier-user clone failed" \
   "check DNS/network and $REPO_URL reachability from the target (auth? grant HTTPS access or a deploy key), then re-run the tail"
fi
arch-chroot /mnt sudo -iu "$TIER_USER" -- \
 bash -lc 'cd ~/Projects/etc/hngh && bash install.sh --non-interactive' ||
 die "install.sh --non-interactive failed" \
  "inspect the output above; the repo is at /home/$TIER_USER/Projects/etc/hngh — fix and re-run, then continue with make -C automation smoke"
if ! arch-chroot /mnt sudo -iu "$TIER_USER" -- \
 bash -lc 'cd ~/Projects/etc/hngh && make -C automation smoke'; then
 info "make smoke reported failures — NOTED, continuing: on a fresh box the daily-digest checks fail until the first cadence run and no secrets exist yet for model output (2026-09-28 arc precedent)"
fi
info "make enable is wired to run as $TIER_USER at first boot (hngh-firstboot.service)"

# --- recovery card + reboot gate (arc close) ---------------------------------
cat <<EOF

================= hngh OS installed — RECOVERY CARD =================
 target:        $TARGET_DISK (1G ESP "HNGH-EFI" + LUKS2 btrfs "$MAPPER")
 luks uuid:     $LUKS_UUID
 boot entry:    systemd-boot "01-hngh-linux" (timeout 3); boots without
                a passphrase via keyfile; RECOVERY PASSPHRASE unlocks
                without it:
 recovery:      $RECOVERY
 root password: $ROOT_PW
 $TIER_USER password: $TIER_PW
 ssh:           root@<host> key-only (authorized_keys from live env),
                ufw: default-deny incoming, 22/tcp open, :$DASH_PORT $LAN-only
 dashboard:     make enable fires at first boot (hngh-firstboot user
                unit, self-disabling; linger set for $TIER_USER)
 repo:          /home/$TIER_USER/Projects/etc/hngh (tier user, wheel)
 verify:        ssh root@<host>; ss -tlnpe '( sport = :$DASH_PORT )'
=====================================================================
EOF

if [ -n "$TTY" ] && [ -z "${ASSUME_YES:-}" ]; then
 printf 'Reboot into the installed system now? [y/N] ' >&2
 IFS= read -r ans <"$TTY" || ans=""
 case "$ans" in
 y | Y)
  umount -R /mnt
  MOUNTED=""
  cryptsetup close "$MAPPER"
  OPENED=""
  reboot
  ;;
 esac
fi
info "done — reboot into hngh when ready"
