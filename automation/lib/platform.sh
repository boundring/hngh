# platform.sh — package-manager detection + per-manager package-name map for
# the installer (install.sh). Sourced, never run. Pure functions over PATH:
# no installs, no privilege escalation, no network, no secrets
# (test-installer.sh sentinel).
#
# Package names: the Arch column is prereq_pkg (lib/prereqs.sh) — that is the
# box the automation tier is developed on. Non-Arch names below are plausible
# per each distro's package search (packages.debian.org, fedora packages,
# software.opensuse.org, pkgs.alpinelinux.org) but are UNVERIFIED on real
# installs — docs/records/2026-09-11-installer-skeleton.md tracks the distro
# matrix as next work. Nothing here installs anything.
set -u
# pkg_for reuses prereq_pkg (the Arch map) — one source of package names.
# Pure-bash path split (dirname may be absent under a stripped test PATH).
_PLATFORM_LIB="${BASH_SOURCE[0]}"
. "${_PLATFORM_LIB%/*}/prereqs.sh"

# detect_pm -> first supported system package manager on PATH, empty if none.
# Order matches bootstrap --install (pacman/apt-get/dnf/zypper/apk).
detect_pm() {
  local pm
  for pm in pacman apt-get dnf zypper apk; do
    if command -v "$pm" >/dev/null 2>&1; then
      echo "$pm"
      return 0
    fi
  done
  return 0
}

# pkg_for MANAGER TOOL -> system package name for TOOL on MANAGER.
# Base map is prereq_pkg (the Arch names); overrides only where a distro
# names the package differently. Empty for an unknown manager (caller
# decides; install.sh reports and refuses, never guesses).
pkg_for() { # MANAGER TOOL -> pkg
  local pm="$1" tool="$2"
  case "$pm:$tool" in
  pacman:*) prereq_pkg "$tool" ;; # prereq_pkg IS the arch map
  apt-get:python3) echo python3 ;;
  apt-get:sqlite3) echo sqlite3 ;;
  apt-get:*) prereq_pkg "$tool" ;; # git curl jq sbcl flock->util-linux
  dnf:python3) echo python3 ;;
  dnf:sqlite3) echo sqlite ;; # fedora: sqlite ships /usr/bin/sqlite3
  dnf:*) prereq_pkg "$tool" ;;
  zypper:python3) echo python3 ;;
  zypper:sqlite3) echo sqlite3 ;;
  zypper:*) prereq_pkg "$tool" ;;
  apk:python3) echo python3 ;;
  apk:sqlite3) echo sqlite ;; # alpine: sqlite ships the sqlite3 CLI
  apk:*) prereq_pkg "$tool" ;;
  *) echo "" ;;
  esac
}

# systemd_user_ok -> 0 iff systemctl --user answers (running or degraded
# both count: degraded still runs user units). Read-only; never enables.
systemd_user_ok() {
  command -v systemctl >/dev/null 2>&1 || return 1
  local s
  s="$(systemctl --user is-system-running 2>/dev/null)" || true
  [ "$s" = "running" ] || [ "$s" = "degraded" ]
}

# python3_ok -> 0 iff python3 major.minor >= 3.12 (kernel floor). Warn-only
# upstream: install.sh reports but bootstrap still owns the hard gate.
python3_ok() {
  command -v python3 >/dev/null 2>&1 || return 1
  local v
  v="$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null)" || return 1
  local maj min
  maj="${v%%.*}"
  min="${v#*.}"
  [ "$maj" -gt 3 ] || { [ "$maj" -eq 3 ] && [ "$min" -ge 12 ]; }
}
