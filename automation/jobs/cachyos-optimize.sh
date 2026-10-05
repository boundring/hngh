#!/usr/bin/env bash
# cachyos-optimize.sh — apply the evidence-backed host optimizations from
# docs/design/cachyos-optimization.md. Dry by default: stages print what
# they WOULD do and exit 0. Real changes need --yes AND a TTY (or
# HNGH_OPT_CONFIRM=YES), and ride sudo fail-closed. Every run logs per
# stage under $HNGH_OPT_LOGDIR (REQ-I26 posture, shared with the installer).
#
# Stages:
#   census      read-only evidence table (no sudo, no changes)
#   zram        write /etc/systemd/zram-generator.conf + start the unit
#   swappiness  vm.swappiness=100 persisted (refuses while zram is off)
#   all         census then every stage
#
# Env: HNGH_OPT_CONFIRM=YES (headless --yes), HNGH_OPT_LOGDIR (log dir),
#      HNGH_OPT_ZRAM_CONF (override target path, tests), HNGH_OPT_SUDO
#      (sudo shim, tests).
set -u

CONF="${HNGH_OPT_ZRAM_CONF:-/etc/systemd/zram-generator.conf}"
SWAPPINESS_CONF="${HNGH_OPT_SWAPPINESS_CONF:-/etc/sysctl.d/90-zram-posture.conf}"
LOGDIR="${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}"
SUDO="${HNGH_OPT_SUDO:-sudo}"
STAGE=""
WANT_YES=0

say() { printf '%s\n' "$*"; }
die() {
 printf 'refused: %s\n' "$*" >&2
 exit 2
}

log_begin() { # stage -> opens the stage log, tees output
 mkdir -p "$LOGDIR" 2>/dev/null || return 0
 local now
 now="$(date -u +%Y%m%dT%H%M%SZ)"
 local log="$LOGDIR/cachyos-$STAGE-$now.log"
 exec > >(tee -a "$log") 2>&1
 say "== cachyos-optimize stage=$STAGE mode=$(real_mode) host=$(uname -n) <$(date -u +%Y-%m-%dT%H:%M:%SZ)> =="
}
real_mode() { [ "$WANT_YES" = 1 ] && echo REAL || echo dry; }

confirm_real() { # --yes needs an interactive TTY or the explicit knob
 [ "$WANT_YES" = 1 ] || die "real changes need --yes (dry run only)"
 if [ ! -t 0 ] && [ "${HNGH_OPT_CONFIRM:-}" != "YES" ]; then
  die "--yes without a TTY needs HNGH_OPT_CONFIRM=YES (fail closed)"
 fi
}

stage_census() {
 say "-- census (read-only; evidence, not a lease) --"
 say "zram-generator: $(pacman -Qi zram-generator 2>/dev/null | sed -n 's/^Version *: //p' || echo absent)"
 if [ -s "$CONF" ]; then
  say "zram conf: present ($(wc -c <"$CONF") bytes)"
 else
  say "zram conf: EMPTY or absent -> zram configured-and-off"
 fi
 say "zram devices: $(zramctl 2>/dev/null | tail -n +2 | wc -l) active"
 say "swap: $(swapon --show 2>/dev/null | tail -n +2 | awk '{printf "%s %s used=%s prio=%s ", $1, $3, $4, $5}')"
 say "swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null)"
 say "nvme scheduler: $(cat /sys/block/nvme*/queue/scheduler 2>/dev/null | head -1)"
 say "cpu: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null) / epp $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)"
}

zram_conf_text() {
 printf '[zram0]\nzram-size = min(ram / 2, 16384)\ncompression-algorithm = zstd\nswap-priority = 100\nfs-type = swap\n'
}

stage_zram() {
 local cur=""
 [ -f "$CONF" ] && cur="$(cat "$CONF")"
 local want
 want="$(zram_conf_text)"
 if [ "$cur" = "$want" ] && zramctl 2>/dev/null | grep -q zram0; then
  say "-- zram: already applied (conf matches, zram0 active) --"
  return 0
 fi
 say "-- zram: write $CONF + start systemd-zram-setup@zram0 --"
 if [ "$(real_mode)" = dry ]; then
  say "dry: would write:"
  say "$want"
  return 0
 fi
 confirm_real
 printf '%s\n' "$want" | "$SUDO" tee "$CONF" >/dev/null || exit $?
 "$SUDO" systemctl daemon-reload || exit $?
 "$SUDO" systemctl start systemd-zram-setup@zram0.service || exit $?
 zramctl 2>/dev/null | grep -q zram0 && say "zram: zram0 active" ||
  {
   say "zram: FAILED to activate zram0"
   exit 1
  }
}

stage_swappiness() {
 unless_zram() { die "swappiness posture needs active zram first (run the zram stage)"; }
 zramctl 2>/dev/null | grep -q zram0 || {
  [ "$(real_mode)" = dry ] || unless_zram
 }
 local cur
 cur="$(cat /proc/sys/vm/swappiness 2>/dev/null || echo 60)"
 if [ "$cur" = "100" ] &&
  grep -q "vm.swappiness = 100" "$SWAPPINESS_CONF" 2>/dev/null; then
  say "-- swappiness: already applied (100 persisted + live) --"
  return 0
 fi
 say "-- swappiness: set vm.swappiness=100 + persist $SWAPPINESS_CONF --"
 if [ "$(real_mode)" = dry ]; then
  say "dry: would set 100 (live $cur) and persist the sysctl drop-in"
  return 0
 fi
 confirm_real
 printf 'vm.swappiness = 100\n' | "$SUDO" tee "$SWAPPINESS_CONF" >/dev/null || exit $?
 "$SUDO" sysctl -q -w vm.swappiness=100 || exit $?
}

main() {
 while [ $# -gt 0 ]; do
  case "$1" in
  census | zram | swappiness | all) STAGE="$1" ;;
  --yes) WANT_YES=1 ;;
  --help | -h)
   say "usage: cachyos-optimize.sh [census|zram|swappiness|all] [--yes]"
   say "  dry by default; --yes needs a TTY or HNGH_OPT_CONFIRM=YES"
   exit 0
   ;;
  *) die "unknown argument: $1" ;;
  esac
 shift
 done
 [ -n "$STAGE" ] || { STAGE="census"; } # default: dry census
 log_begin
 case "$STAGE" in
 census) stage_census ;;
 zram) stage_zram ;;
 swappiness) stage_swappiness ;;
 all)
  stage_census
  stage_zram
  stage_swappiness
  ;;
 esac
 say "== stage=$STAGE done ($(real_mode)) =="
}

main "$@"
