#!/usr/bin/env bash
# cachyos-optimize.sh — read-only CachyOS host posture verification.
#
# Operator constraint (2026-10-05): zram is contraindicated on this host
# (AMD suspend/wake failures under zram pressure); zswap + swapfile is the
# house posture. Real swap-posture mutations belong to the operator's
# cachyos-zswap-migrate tool, never to this script.
#
# Stages:
#   census    default — print the measured evidence table (dry, no sudo)
#   zswap     assert the house posture; a miss names the migrate tool,
#             exits 1 (fail closed); never mutates
#
# Every run appends a per-stage log under
# ${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}; the log is the review
# artifact (REQ-I26 posture shared with omarchy-boot-build.sh). Log loss
# never gates.
set -u

SCRIPT_NAME="cachyos-optimize.sh"
LOGDIR="${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}"
ZSWAP_SYS="${HNGH_OPT_ZSWAP_SYS:-/sys/module/zswap/parameters}"
MIGRATE_TOOL="cachyos-zswap-migrate"

say() { printf '%s\n' "$*"; }
die() {
  printf '%s\n' "refused: $*" >&2
  exit 2
}

log_begin() { # stage
  mkdir -p "$LOGDIR" 2>/dev/null || return 0
  local log="$LOGDIR/cachyos-$1-$(date -u +%Y%m%dT%H%M%SZ).log"
  exec > >(tee -a "$log") 2>&1 # stdin stays attached; tee lag is real (tests sleep 0.3)
}

real_mode() { printf '%s' dry; } # every stage is read-only; kept for output shape

zswap_param() { # key -> value or ""
  cat "$ZSWAP_SYS/$1" 2>/dev/null | tr -d '[:space:]'
}

stage_census() {
  say "-- census (read-only; evidence, not a lease) --"
  say "zram-generator: $(pacman -Qi zram-generator 2>/dev/null | sed -n 's/^Version *: //p' || echo absent)"
  say "zram conf: $([ -s /etc/systemd/zram-generator.conf ] 2>/dev/null && echo present || echo 'EMPTY or absent -> zram off (operator posture)')"
  say "zram devices: $(zramctl --output name 2>/dev/null | tail -n +2 | wc -l) active"
  say "zswap: enabled=$(zswap_param enabled) compressor=$(zswap_param compressor) max_pool_percent=$(zswap_param max_pool_percent) shrinker=$(zswap_param shrinker_enabled)"
  say "swap: $(swapon --show 2>/dev/null | tail -n +2 | awk '{printf "%s %s used=%s prio=%s ", $1, $3, $4, $5}')"
  say "swappiness: $(cat /proc/sys/vm/swappiness 2>/dev/null || echo '?')"
  say "nvme scheduler: $(cat /sys/block/nvme0n1/queue/scheduler 2>/dev/null || echo '?')"
  say "cpu: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo '?') / epp $(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null || echo '?')"
}

stage_zswap() {
  say "-- zswap posture (house state: zswap on, zram off; read-only) --"
  local miss=0
  [ "$(zswap_param enabled)" = "Y" ] || {
    say "MISS: zswap not enabled (got '$(zswap_param enabled)')"
    miss=1
  }
  [ "$(zswap_param compressor)" = "zstd" ] || {
    say "MISS: compressor '$(zswap_param compressor)' != zstd"
    miss=1
  }
  [ "$(zramctl --output name 2>/dev/null | tail -n +2 | wc -l)" = "0" ] || {
    say "MISS: a zram device is active — operator posture violated"
    miss=1
  }
  swapon --show 2>/dev/null | grep -q . || {
    say "MISS: no backing swapfile"
    miss=1
  }
  if [ "$miss" = 0 ]; then
    say "posture ok: zswap(zstd)+swapfile backing, zram off — nothing to apply"
  else
    say "fix path: run ${MIGRATE_TOOL} inspect/plan/apply (operator's tool; reversible, backed up) — this script never mutates"
    return 1
  fi
}

main() {
  local stage=""
  while [ $# -gt 0 ]; do
    case "$1" in
    census | zswap) stage="$1" ;;
    --help | -h)
      say "usage: $SCRIPT_NAME [census|zswap]"
      say "  census  read-only evidence table (default)"
      say "  zswap   assert house posture (zswap on, zram off); rc 1 on miss"
      exit 0
      ;;
    *) die "unknown argument: $1" ;;
    esac
    shift
  done
  [ -n "$stage" ] || { stage="census"; } # default: dry census
  log_begin "$stage"
  say "== $SCRIPT_NAME stage=$stage mode=$(real_mode) host=$(uname -n) <$(date -u +%Y-%m-%dT%H:%M:%SZ)> =="
  "stage_$stage" || exit $?
  say "== stage=$stage done ($(real_mode)) =="
  exit 0
}

main "$@"
