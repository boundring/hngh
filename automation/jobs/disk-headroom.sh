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
#   strip    Tier 2 lever 2 — remove debug info from large ELF build artifacts
#
# sweep and strip are separate levers on the same tree and their savings must
# never be added together: stripping is reversible only by a full rebuild, and
# dropping stale variants changes what is left to strip. Run one, measure, then
# decide on the other.
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

# Tier 2, lever 2. `strip -g` keeps the loadable segments and drops .debug_*,
# which is the whole of the win: debug info is only read by a debugger, and a
# build artifact is not something anyone debugs. The proven saving is 74%
# (1.7 G -> 437 M, binary still launched Bevy and reported the RADV adapter).
# Files below this size are not worth a temp copy and a rename.
STRIP_MIN_SIZE_MB="${HNGH_OPT_STRIP_MIN_SIZE_MB:-100}"
STRIP_FLAGS="${HNGH_OPT_STRIP_FLAGS:--g}"

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

# human <bytes> -> 437M. The census and the strip report both quote byte counts,
# and `du -h` cannot be used for a single file's size without a second stat.
human() { # bytes
  awk -v b="${1:-0}" 'BEGIN {
    split("B K M G T P", u, " ")
    i = 1
    while (b >= 1024 && i < 6) { b /= 1024; i++ }
    printf (i == 1 ? "%d%s\n" : "%.1f%s\n"), b, u[i]
  }'
}

# A build tree is prunable only when no process is using it. Cargo and rustc do
# not hold the target dir open exclusively, so match on the owning binary name
# and the tree path, which is what actually indicates a live build.
build_busy() { # path
  local path="$1"
  # $$ is excluded because a caller that reaches this job through a shell whose
  # own command line mentions both cargo and this path would otherwise make the
  # job skip itself forever.
  pgrep -af 'cargo|rustc' 2>/dev/null | grep -v "^$$[ ]" | grep -Fq "$path"
}

# A binary under this tree that a live process is currently executing. Stripping
# one of those replaces the inode a running process is holding open, so the
# guard is not optional.
deps_in_use() { # deps_dir
  local link
  for link in /proc/[0-9]*/exe; do
    readlink "$link" 2>/dev/null || true
  done | grep -F "$1/" | sort -u
}

# NUL-delimited for `read -d ''`, and counted here so the two call sites cannot
# disagree about how many files qualify.
strip_count() { # deps_dir
  unstripped_big "$1" | tr '\0' '\n' | grep -c .
}

# Every ELF file at or above the threshold that still carries DWARF debug info.
#
# The selector is `with debug_info`, NOT file(1)'s bare `not stripped`. `strip -g`
# keeps .symtab, so a fully stripped artifact still reads "not stripped" and
# selecting on that word would make this stage re-strip the same 111 G forever
# while the census kept reporting it as available. Only the debug_info clause
# means there is something left to remove.
#
# Non-ELF files in deps (preallocated test fixtures that file(1) calls plain
# "data", and .rlib ar archives) are excluded by construction, which is correct:
# strip does not reclaim archive members here.
unstripped_big() { # deps_dir
  find "$1" -type f -size +"${STRIP_MIN_SIZE_MB}"M -print0 2>/dev/null |
    while IFS= read -r -d '' f; do
      if file -b "$f" 2>/dev/null | grep -q 'with debug_info'; then
        printf '%s\0' "$f"
      fi
    done
}

strip_total() { # deps_dir -> bytes of strippable debug info
  local f n=0
  while IFS= read -r -d '' f; do
    n=$(( n + $(stat -c %s "$f" 2>/dev/null || echo 0) ))
  done < <(unstripped_big "$1")
  printf '%s\n' "$n"
}

# Build-date distribution over the deps tree: one line per date, oldest first,
# each carrying the file count and the bytes. This is the measurement that
# separates "one big build" from "many small stale ones", which is the whole
# question Tier 2 lever 1 turns on.
#
# Report only. Nothing in this function deletes, and nothing in this file acts on
# what it prints -- the lever-1 policy is operator-owned (package F f8).
#
# mtime, not ctime: cargo writes artifacts once and hardlinks them, so ctime
# tracks the link, not the build. Age here means "how long since this artifact
# was produced", which is the quantity the lever is reasoning about.
build_dates() { # deps_dir -> "YYYY-MM-DD count bytes" lines, oldest first
  find "$1" -type f -printf '%TY-%Tm-%Td %s\n' 2>/dev/null |
    awk '{ c[$1]++; s[$1] += $2 }
         END { for (d in c) printf "%s %d %d\n", d, c[d], s[d] }' |
    sort
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

  # Tier 2 lever 2, reported but never acted on here: census-and-report is safe
  # to run on a timer, stripping is not.
  say ""
  say "Tier 2 lever — strippable debug info in deps (strip stage removes it):"
  local deps total row d c b ndates
  deps="$CISTERN_ROOT/target/debug/deps"
  if [ -d "$deps" ]; then
    total="$(strip_total "$deps")"
    say "  $(human "$total") in unstripped ELF over ${STRIP_MIN_SIZE_MB}M"
    say "  $(strip_count "$deps") files"
  else
    say "  - (no deps tree)"
  fi

  # Tier 2 lever 1 is undecided (package F f8), so this table exists to make the
  # decision possible rather than to pre-empt it. Capped at the 10 oldest dates
  # because a deps tree accumulates one per build day and the interesting rows
  # are always the old ones.
  say ""
  say "Tier 2 lever — deps build-date distribution (report only, nothing prunes):"
  if [ -d "$deps" ]; then
    ndates=0
    while read -r d c b; do
      ndates=$(( ndates + 1 ))
      [ "$ndates" -le 10 ] && say "$(printf '  %-10s  %6s files  %8s' "$d" "$c" "$(human "$b")")"
    done < <(build_dates "$deps")
    say "  $(printf '(%s distinct build dates; oldest %s shown)' "$ndates" "$([ "$ndates" -gt 10 ] && echo 10 || echo "$ndates")")"
  else
    say "  - (no deps tree)"
  fi

  # The etc/ frame after the 2026-10-13 regroup. Reported, never pruned: which
  # of these a sweep may touch is a policy question (package F f8, deferred), so
  # this table exists to make drift visible, not to authorise anything.
  say ""
  say "etc/ frame (group dirs after the 2026-10-13 regroup):"
  local g
  for g in "$ETC_ROOT"/*/; do
    [ -d "$g" ] || continue
    say "$(printf '  %6s  %s' "$(du_of "$g")" "${g%/}")"
  done

  # Same posture for the cache tree: report, never prune. The parfact of the
  # 2026-10-13 sweep (paru 23 G, uv 13 G, yay 4.8 G) was one-time, and no
  # standing job is allowed to repeat it.
  #
  # Top 12 only: huggingface alone is 119 G, and a census that lists every cache
  # dir would bury the two numbers that actually need a decision.
  say ""
  say "largest ~/.cache entries (report only; each needs its own policy):"
  for g in $(du -s "$HOME"/.cache/*/ 2>/dev/null | sort -rn | head -12 | cut -f2-); do
    say "$(printf '  %6s  %s' "$(du_of "$g")" "${g%/}")"
  done

  say ""
  say "  ~/.cache/huggingface      — $(du_of "$HOME/.cache/huggingface")  model weights, fetch is slow"
  say "  ~/.cargo/registry         — $(du_of "$HOME/.cargo/registry")  crate sources"

  say ""
  [ "$DRY_RUN" = "1" ] && say "(dry run: HNGH_OPT_DRY_RUN=1)" || say "run 'sweep' to prune the reclaimable set, or 'strip' to drop debug info."
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

# Tier 2 lever 2. Strips debug info out of large build artifacts. This is not a
# prune: every file survives, only its .debug_* sections go, so a failed strip
# leaves an unstripped binary rather than a broken one. Each file is stripped to
# a sibling temp path and renamed into place only after it is verified to still
# be a readable ELF, so an interrupted run cannot leave a truncated artifact.
stage_strip() {
  local deps="$CISTERN_ROOT/target/debug/deps"
  [ -d "$deps" ] || { say "no deps tree at $deps"; return 0; }

  if build_busy "$deps"; then
    say "skip (build in flight): $deps"
    return 0
  fi

  local busy
  busy="$(deps_in_use "$deps")"
  if [ -n "$busy" ]; then
    say "skip (running process holds these binaries):"
    printf '  %s\n' $busy
    return 0
  fi

  local before after saved n=0 skipped=0 failed=0
  before="$(strip_total "$deps")"
  say "strippable: $(human "$before") across $(strip_count "$deps") files"

  local f tmp
  while IFS= read -r -d '' f; do
    tmp="$f.dhstrip.$$"
    # A hardlinked artifact is shared with a stable top-level path such as
    # target/debug/<bin>, which is the one someone actually runs. Renaming over
    # the deps copy would free nothing (the other name still holds the old
    # inode) and would leave the two names pointing at different builds.
    if [ "$(stat -c %h "$f")" -gt 1 ]; then
      say "  left alone (hardlinked, shares an inode with a stable path): ${f#"$deps"/}"
      skipped=$(( skipped + 1 ))
      continue
    fi
    if [ "$DRY_RUN" = "1" ]; then
      say "would strip $(human "$(stat -c %s "$f")") — ${f#"$deps"/}"
      n=$(( n + 1 ))
      continue
    fi
    if ! strip "$STRIP_FLAGS" -o "$tmp" "$f" 2>/dev/null; then
      say "  FAILED to strip: ${f#"$deps"/}"
      rm -f -- "$tmp" 2>/dev/null
      failed=$(( failed + 1 ))
      continue
    fi
    # Never replace an artifact with something that is not an ELF. A file that
    # stopped being an ELF means the strip went wrong, and the original is
    # still intact because the rename has not happened.
    if ! file -b "$tmp" 2>/dev/null | grep -q 'ELF'; then
      say "  DISCARDED (not an ELF after strip): ${f#"$deps"/}"
      rm -f -- "$tmp" 2>/dev/null
      failed=$(( failed + 1 ))
      continue
    fi
    if [ "$(stat -c %s "$tmp")" -ge "$(stat -c %s "$f")" ]; then
      say "  no saving, left alone: ${f#"$deps"/}"
      rm -f -- "$tmp" 2>/dev/null
      skipped=$(( skipped + 1 ))
      continue
    fi
    mv -f -- "$tmp" "$f" || { rm -f -- "$tmp" 2>/dev/null; failed=$(( failed + 1 )); }
    n=$(( n + 1 ))
  done < <(unstripped_big "$deps")

  say "stripped: $n  left-alone: $skipped  failed: $failed"
  after="$(strip_total "$deps")"
  saved=$(( before - after ))
  say "reclaimed: $(human "$saved")"

  say ""
  [ "$DRY_RUN" = "1" ] && say "(dry run: nothing was stripped)"
  df -h "$HOME" 2>/dev/null | tail -1 | sed 's/^/  /'
}

main() {
  local stage="${1:-census}"
  case "$stage" in
    census) log_begin census; stage_census ;;
    sweep)  log_begin sweep;  stage_sweep ;;
    strip)  log_begin strip;  stage_strip ;;
    *) die "unknown stage '$stage' (use: census | sweep | strip)" ;;
  esac
}

main "$@"
