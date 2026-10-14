#!/usr/bin/env bash
# systemd-units.sh — reconcile ~/.config/systemd/user with automation/systemd/.
#
# Why this job exists. Units used to be hand-copied into the user unit
# directory, which is the mechanism behind the drift that handoff §3.7a
# documents: seven cadence services and their timers were consolidated out of
# the repo in commit 17b898e6 and sat on the box for twenty days afterwards,
# still looking live but hard-failing on every tick because their TIER no
# longer passed jobs/cadence-tick.sh's guard. Copying by hand does not delete,
# so a consolidation can never propagate.
#
# Stages:
#   status   default — report what would change, mutate nothing
#   apply    copy changed units in, delete deployed units the repo no longer
#            has, then `systemctl --user daemon-reload`
#
# Deleting is the point. An installer that only copies re-arms the exact trap
# it is meant to close.
#
# Deletion is guarded three ways:
#   - only files matching hngh-*.service / hngh-*.timer are ever considered,
#     and only ones with no counterpart in automation/systemd/
#   - HNGH_OPT_DRY_RUN=1 lists them and removes nothing
#   - a unit with a live activation is skipped and reported, never killed
#
# Dropin directories (hngh-*.service.d/) are NOT touched. They hold operator
# local config (credentials.conf, mem-caps.conf) that is not in the repo and
# must survive a sync.
set -u

SCRIPT_NAME="systemd-units.sh"
LOGDIR="${HNGH_OPT_LOGDIR:-$HOME/.hngh/installer-logs}"
UNIT_DIR="${HNGH_OPT_UNIT_DIR:-$HOME/.config/systemd/user}"
DRY_RUN="${HNGH_OPT_DRY_RUN:-0}"

# Deliberately standalone, same as disk-headroom.sh: this job repairs the
# user unit directory, so it must not depend on a tree it may be repairing.
SRC_DIR="$(cd "$(dirname "$0")/../systemd" && pwd)"

say() { printf '%s\n' "$*"; }

stage_status() {
  local changed=0 orphan=0 live=0 unit
  say "repo units : $SRC_DIR"
  say "deployed   : $UNIT_DIR"
  say ""

  for unit in "$SRC_DIR"/hngh-*.service "$SRC_DIR"/hngh-*.timer; do
    [ -e "$unit" ] || continue
    local base; base="$(basename "$unit")"
    if [ ! -e "$UNIT_DIR/$base" ]; then
      say "  new       $base"; changed=$((changed + 1))
    elif ! cmp -s "$unit" "$UNIT_DIR/$base"; then
      say "  changed   $base"; changed=$((changed + 1))
    fi
  done

  # Deployed hngh units with no repo source. This is the drift signal, and it
  # is the only thing that would have caught the seven stale cadence tiers.
  for unit in "$UNIT_DIR"/hngh-*.service "$UNIT_DIR"/hngh-*.timer; do
    [ -e "$unit" ] || continue
    local base; base="$(basename "$unit")"
    [ -e "$SRC_DIR/$base" ] && continue
    if systemctl --user is-active --quiet "$base" 2>/dev/null; then
      say "  LIVE      $base (no repo source, currently running — SKIPPED)"; live=$((live + 1))
    else
      say "  orphan    $base (no repo source, inactive)"; orphan=$((orphan + 1))
    fi
  done

  say ""
  say "new-or-changed=$changed  orphans=$orphan  live-skipped=$live  dry_run=$DRY_RUN"
}

stage_apply() {
  local unit base copied=0 removed=0 skipped=0

  for unit in "$SRC_DIR"/hngh-*.service "$SRC_DIR"/hngh-*.timer; do
    [ -e "$unit" ] || continue
    base="$(basename "$unit")"
    if cmp -s "$unit" "$UNIT_DIR/$base"; then continue; fi
    if [ "$DRY_RUN" = 1 ]; then
      say "  would copy $base"; copied=$((copied + 1)); continue
    fi
    cp "$unit" "$UNIT_DIR/$base" && { say "  copied   $base"; copied=$((copied + 1)); }
  done

  for unit in "$UNIT_DIR"/hngh-*.service "$UNIT_DIR"/hngh-*.timer; do
    [ -e "$unit" ] || continue
    base="$(basename "$unit")"
    [ -e "$SRC_DIR/$base" ] && continue
    if systemctl --user is-active --quiet "$base" 2>/dev/null; then
      say "  SKIP     $base is active; stop it before this job will remove it"; skipped=$((skipped + 1)); continue
    fi
    if [ "$DRY_RUN" = 1 ]; then
      say "  would remove $base"; removed=$((removed + 1)); continue
    fi
    rm -- "$unit" && { say "  removed  $base"; removed=$((removed + 1)); }
  done

  say ""
  say "copied=$copied removed=$removed skipped=$skipped dry_run=$DRY_RUN"

  if [ "$DRY_RUN" = 1 ]; then
    say "dry run: daemon-reload skipped"
    return 0
  fi

  # Reload only when something actually changed. An unconditional reload on
  # every timer tick would churn systemd's view for nothing.
  if [ "$copied" -eq 0 ] && [ "$removed" -eq 0 ]; then
    say "nothing changed; daemon-reload skipped"
    return 0
  fi
  systemctl --user daemon-reload && say "daemon-reload done"
}

stage="${1:-status}"
case "$stage" in
  status) stage_status ;;
  apply)  stage_apply ;;
  *)
    say "usage: $SCRIPT_NAME [status|apply]" >&2
    say "  HNGH_OPT_DRY_RUN=1 rehearse apply without changing anything" >&2
    exit 2
    ;;
esac
