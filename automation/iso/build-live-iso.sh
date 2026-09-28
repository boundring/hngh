#!/usr/bin/env bash
# build-live-iso.sh — build the combined CachyOS+Omarchy hngh live ISO from
# automation/iso/profile via mkarchiso (archiso). Validates the profile,
# builds with default work/out dirs under ~/.hngh/db/iso (never inside the
# dev repo), prints the newest artifact on success.
# Exit: 0 ok; 2 usage; 3 prereq/profile validation; mkarchiso rc propagates.
# Seams (hermetic tests): MKARCHISO_BIN, ISO_PROFILE_DIR, ISO_WORKDIR,
# ISO_OUTDIR, HNGH_HOME_DIR.
# Needs root for the real build (mkarchiso runs pacstrap) — this wrapper
# never escalates; run it under sudo yourself.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

ISO_PROFILE_DIR="${ISO_PROFILE_DIR:-$AUTOMATION_ROOT/iso/profile}"
MKARCHISO_BIN="${MKARCHISO_BIN:-mkarchiso}"
WORK="${ISO_WORKDIR:-$HNGH_HOME_DIR/db/iso/work}"
OUT="${ISO_OUTDIR:-$HNGH_HOME_DIR/db/iso/out}"

usage() { echo "usage: build-live-iso.sh [--work DIR] [--out DIR]" >&2; }

while [ $# -gt 0 ]; do
  case "$1" in
  --work)
    [ $# -ge 2 ] || {
      usage
      exit 2
    }
    WORK="$2"
    shift 2
    ;;
  --out)
    [ $# -ge 2 ] || {
      usage
      exit 2
    }
    OUT="$2"
    shift 2
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    usage
    exit 2
    ;;
  esac
done

command -v "$MKARCHISO_BIN" >/dev/null 2>&1 || {
  log "mkarchiso not found: install archiso (MKARCHISO_BIN overrides the name)"
  exit 3
}

missing=0
for f in profiledef.sh packages.x86_64 pacman.conf \
  efiboot/loader/loader.conf \
  efiboot/loader/entries/01-hngh-linux.conf \
  syslinux/syslinux.cfg \
  airootfs/etc/mkinitcpio.conf.d/archiso.conf; do
  [ -f "$ISO_PROFILE_DIR/$f" ] || {
    log "profile missing: $f"
    missing=1
  }
done
[ "$missing" -eq 0 ] || exit 3

mkdir -p -- "$WORK" "$OUT"
"$MKARCHISO_BIN" -v -w "$WORK" -o "$OUT" "$ISO_PROFILE_DIR"
rc=$?
[ "$rc" -eq 0 ] || exit "$rc"

# newest artifact wins (rebuilds layer up)
ISO_FILE="$(ls -1t "$OUT"/*.iso 2>/dev/null | head -n 1)"
[ -n "$ISO_FILE" ] && printf 'build-live-iso: %s\n' "$ISO_FILE"
exit 0
