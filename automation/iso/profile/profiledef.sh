#!/usr/bin/env bash
# profiledef.sh — hngh live ISO profile (mkarchiso, releng shape, archiso >= v76).
# Combined CachyOS base + Omarchy session stack ("the distribution" horizon,
# docs/design/presentation-direction.md; gap registry G8/G9 backdrop).
# Boot chain is stock archiso (syslinux BIOS + systemd-boot UEFI) with the
# CachyOS kernel: the omarchy avoid-list (automation/config/omarchy-base.packages)
# holds here too — no linux-omarchy, no limine, no mkinitcpio UKI contact.
# shellcheck disable=SC2034

iso_name="hngh"
iso_label="HNGH_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="hngh (CachyOS base + Omarchy session)"
iso_application="hngh live medium (CachyOS base + Omarchy session)"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="hngh"
bootmodes=('bios.syslinux'
 'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
 ["/etc/shadow"]="0:0:400"
 ["/root"]="0:0:750"
 ["/etc/sudoers.d/liveuser"]="0:0:440"
)
