#!/usr/bin/env bash
# disk-headroom.sh — reclaim disk from regenerable build and cache trees.
#
# Operator constraint (2026-10-13): disk reached 81% (367G free) largely because
# cargo build trees accumulate one artifact set per build fingerprint and never
# prune. This job prunes the *regenerable* residue only. It never touches source,
# never touches a target dir belonging to a live process, and never runs an
# unbounded `cargo clean` (that would trade disk for a full rebuild).
#
# Stages:
#   census   default — print the measured table, no mutation, no sudo
#   sweep    prune the reclaimable set; requires a live-free check per tree
#
# Every run appends a per-stage log under
# ${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}; the log is the review
# artifact. Log loss never gates.
#
# Why incremental/ and orphaned target dirs come first: they are pure derived
# state. Deleting them costs a recompile, not a lost artifact.
set -u

SCRIPT_NAME="disk-headroom.sh"
LOGDIR="${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}"

# The etc/ frame seam, same default as lib/common.sh:15. This job deliberately
# does NOT source lib/common.sh: it must keep running even when the hngh tree
# is mid-move or mid-merge, because it is the job you reach for when the tree
# is exactly in that state.
ETC_ROOT="${ETC_ROOT:-$HOME/Projects/etc}"

# cistern's checkout. Same seam as CISTERN_ROOT in lib/common.sh:32 — kept
# local because this job cannot source common.sh, so it must not depend on a
# tree it may be repairing.
CISTERN_ROOT="${CISTERN_ROOT:-$ETC_ROOT/cistern}"

# Trees this job is allowed to prune. Each entry is "<path>|<label>".
# Keep this list explicit: a glob over $HOME is how cleanup jobs delete things
# they were never asked about.
PRUNE_INCREMENTAL=(
  "$CISTERN_ROOT/target/debug/incremental|cistern incremental"
  "$HOME/src/jcode/target/debug/incremental|jcode debug incremental"
  "$HOME/src/jcode/target/release/incremental|jcode release incremental"
)
# Orphans: a target dir whose owning checkout is gone or whose sessions died.
# Each is reclaimed whole, because nothing can incrementally build from them.
PRUNE_ORPHAN=(
  "$HOME/.cache/ngp1|ngp1 scratch target dir (orphaned 2026-10-11, no Cargo.toml)"
)

# A scratch target dir younger than this is presumed to belong to work that is
# still starting up. An orphan only becomes reclaimable once it is old enough
# that nobody can plausibly still be aiming at it.
ORPHAN_MIN_AGE_DAYS="${HNGH_OPT_ORPHAN_MIN_AGE_DAYS:-14}"

# When set, sweep reports what it would prune and removes nothing. This is the
# only supported way to rehearse the destructive path: the guards below are
# exercised for real, so a rehearsal proves the job would behave as claimed.
DRY_RUN="${HNGH_OPT_DRY_RUN:-0}"

# prune <label> <path> — the single removal chokepoint, so dry-run cannot be
# bypassed by a new call site.
prune() { # label path
  local label="$1" path="$2"
  if [ "$DRY_RUN" = "1" ]; then
    say "would prune: $label — $path ($(du_of "$path"))"
    return 0
  fi
  say "prune: $label — $path ($(du_of "$path"))"
  rm -rf -- "$path" || say "  FAILED to remove $path"
}

say() { printf '%s\n' "$*"; }
die() {
  printf 'refused: %s\n' "$*" >&2
  exit 2
}

log_begin() { # stage
  mkdir -p "$LOGDIR" 2>/dev/null || return 0
  local log="$LOGDIR/disk-headroom-$1-$(date -u +%Y%m%dT%H%M%SZ).log"
  exec > >(tee -a "$log") 2>&1
}

du_of() { # path -> human size, or "-" when absent
  [ -e "$1" ] || { printf -- '-\n'; return 0; }
  du -sh "$1" 2>/dev/null | cut -f1 || printf -- '?\n'
}

# A build tree is prunable only when no process is using it. Cargo and rustc do
# not hold the target dir open exclusively, so match on the owning binary name
# and the tree path, which is what actually indicates a live build.
build_busy() { # path
  local path="$1"
  pgrep -af 'cargo|rustc' 2>/dev/null | grep -Fq "$path"
}

stage_census() {
  say "disk-headroom census — $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  say ""
  say "filesystem:"
  df -h "$HOME" 2>/dev/null | tail -1 | sed 's/^/  /'
  say ""

  say "reclaimable (derived state, rebuildable):"
  local entry path label
  for entry in "${PRUNE_INCREMENTAL[@]}" "${PRUNE_ORPHAN[@]}"; do
    path="${entry%%|*}"
    label="${entry##*|}"
    say "$(printf '  %6s  %s' "$(du_of "$path")" "$path")"
    say "$(printf '  %6s  %s' "" "($label)")"
  done
  say ""
  local total
  total="$(du -sch "${PRUNE_INCREMENTAL[@]%%|*}" "${PRUNE_ORPHAN[@]%%|*}" 2>/dev/null | tail -1 | cut -f1)"
  say "$(printf '  %6s  total reclaimable' "${total:-0}")"

  say ""
  say "not reclaimable by this job:"
  say "  cistern target/debug/deps  — $(du_of "$CISTERN_ROOT/target/debug/deps")  current build artifacts"
  say "  ~/.cache/huggingface      — $(du_of "$HOME/.cache/huggingface")  model weights, fetch is slow"
  say "  ~/.cargo/registry         — $(du_of "$HOME/.cargo/registry")  crate sources"

  say ""
  [ "$DRY_RUN" = "1" ] && say "(dry run: HNGH_OPT_DRY_RUN=1)" || say "run 'sweep' to prune the reclaimable set."
}

stage_sweep() {
  local entry path label
  for entry in "${PRUNE_INCREMENTAL[@]}"; do
    path="${entry%%|*}"
    label="${entry##*|}"
    [ -e "$path" ] || continue
    if build_busy "$path"; then
      say "skip (build in flight): $label — $path"
      continue
    fi
    prune "$label" "$path"
  done

  for entry in "${PRUNE_ORPHAN[@]}"; do
    path="${entry%%|*}"
    label="${entry##*|}"
    [ -e "$path" ] || continue
    if build_busy "$path"; then
      say "skip (build in flight): $label — $path"
      continue
    fi
    # Orphan trees are reclaimed whole, but only when the owning checkout is
    # genuinely absent. If a Cargo.toml ever appears beside it, it stopped being
    # an orphan and this job must not touch it.
    if [ -e "$path/Cargo.toml" ] || [ -e "$(dirname "$path")/Cargo.toml" ]; then
      say "skip (no longer orphaned, checkout present): $label — $path"
      continue
    fi
    local age_days
    age_days=$(( ( $(date +%s) - $(stat -c %Y "$path") ) / 86400 ))
    if [ "$age_days" -lt "$ORPHAN_MIN_AGE_DAYS" ]; then
      say "skip (only ${age_days}d old, threshold ${ORPHAN_MIN_AGE_DAYS}d): $label — $path"
      continue
    fi
    prune "$label" "$path"
  done

  say ""
  [ "$DRY_RUN" = "1" ] && say "(dry run: nothing was removed)"
  df -h "$HOME" 2>/dev/null | tail -1 | sed 's/^/  /'
}

main() {
  local stage="${1:-census}"
  case "$stage" in
    census) log_begin census; stage_census ;;
    sweep)  log_begin sweep;  stage_sweep ;;
    *) die "unknown stage '$stage' (use: census | sweep)" ;;
  esac
}

main "$@"
