#!/usr/bin/env bash
# omarchy-config-adopt.sh — integration-plan phase 2: adopt the Omarchy
# upstream user-config layer (clone's config/<rel>) into the operator home
# (<home>/.config/<rel>) so the installed Hyprland session boots looking and
# behaving like Omarchy. No boot-chain contact, no Plasma defaults, no theme
# seeding (session boots unthemed; theme state is out of scope).
#
# Adopt convention (upstream omarchy-refresh-config / copy_config_default):
#   target missing      -> copy
#   target identical    -> skip (idempotent)
#   target differs      -> mv target target.bak, then copy (never silent clobber)
#
# Also writes <home>/.config/uwsm/env.d/10-hngh-omarchy.conf pinning
# OMARCHY_PATH at the clone so hyprland.lua's dofile of
# $OMARCHY_PATH/default/hypr/bootstrap.lua resolves in dev-link mode. No PATH
# line: upstream default/bash/env-bootstrap owns PATH; the hook only pins
# OMARCHY_PATH.
#
# Usage: omarchy-config-adopt.sh [--dry-run]
#   OMARCHY_UPSTREAM_DIR    upstream clone (default ~/Projects/etc/omarchy-upstream)
#   HNGH_CONFIG_ADOPT_HOME  target home (default $HOME; tests sandbox it)
#   HNGH_CONFIG_ADOPT_DRY=1 plan only, same as --dry-run
# Exit: 0 ok, 2 usage (unknown flag), 3 fail-closed prereq.
set -u

PROG=omarchy-config-adopt
DRY=0
[ "${HNGH_CONFIG_ADOPT_DRY:-0}" = "1" ] && DRY=1
while [ $# -gt 0 ]; do
  case "$1" in
  --dry-run) DRY=1 ;;
  -h | --help)
    echo "usage: $PROG [--dry-run]" >&2
    exit 0
    ;;
  *)
    echo "$PROG: unknown flag: $1" >&2
    echo "usage: $PROG [--dry-run] (env: OMARCHY_UPSTREAM_DIR, HNGH_CONFIG_ADOPT_HOME, HNGH_CONFIG_ADOPT_DRY=1)" >&2
    exit 2
    ;;
  esac
  shift
done

UPSTREAM="${OMARCHY_UPSTREAM_DIR:-$HOME/Projects/etc/omarchy-upstream}"
ADOPT_HOME="${HNGH_CONFIG_ADOPT_HOME:-$HOME}"
DOTCFG="$ADOPT_HOME/.config"

log() { echo "$PROG: $*" >&2; }
die3() { # fail-closed prereq: name the path + remediation, exit 3
  echo "$PROG: $*" >&2
  exit 3
}

# ---- (a) fail-closed prereqs -------------------------------------------------
[ -d "$UPSTREAM" ] || die3 "upstream clone missing or not a directory: $UPSTREAM (remediation: git clone https://github.com/omarchy/omarchy $UPSTREAM)"
CFG="$UPSTREAM/config"
[ -d "$CFG/hypr" ] || die3 "upstream missing session-critical dir: $CFG/hypr"
[ -f "$CFG/omarchy/shell.json" ] || die3 "upstream missing: $CFG/omarchy/shell.json"
[ -d "$CFG/omarchy/hooks" ] || die3 "upstream missing: $CFG/omarchy/hooks"

UPREAL="$(realpath "$UPSTREAM")"
copied=0 skipped=0 backed=0

# classify + perform one file: SRC (clone) -> DST (home, same rel path)
adopt_file() { # src dst
  local src="$1" dst="$2" act
  local rel="${dst#"$DOTCFG"/}"
  if [ ! -e "$dst" ]; then
    act=copy
  elif cmp -s "$dst" "$src"; then
    act=skip
  else act=backup; fi
  case "$act" in
  skip)
    skipped=$((skipped + 1))
    log "skipped (identical) $rel"
    ;;
  copy)
    copied=$((copied + 1))
    if [ "$DRY" -eq 1 ]; then
      log "would copy $rel"
    else
      mkdir -p "$(dirname "$dst")" || exit 3
      cp -- "$src" "$dst" || {
        log "copy failed: $rel"
        exit 3
      }
      log "copied $rel"
    fi
    ;;
  backup)
    backed=$((backed + 1))
    if [ "$DRY" -eq 1 ]; then
      log "would backup $rel -> $rel.bak and copy"
    else
      mkdir -p "$(dirname "$dst")" || exit 3
      mv -- "$dst" "$dst.bak" || {
        log "backup mv failed: $rel"
        exit 3
      }
      cp -- "$src" "$dst" || {
        log "copy failed: $rel"
        exit 3
      }
      log "backed up $rel -> .bak"
    fi
    ;;
  esac
}

# ---- (b) allowlist copy -------------------------------------------------------
# whole hypr/ tree (find-based, files only, rel paths preserved)
while IFS= read -r f; do
  adopt_file "$f" "$DOTCFG/hypr/${f#"$CFG/hypr/"}"
done < <(find "$CFG/hypr" -type f | sort)

adopt_file "$CFG/omarchy/shell.json" "$DOTCFG/omarchy/shell.json"

# omarchy/hooks/ (hook samples)
while IFS= read -r f; do
  adopt_file "$f" "$DOTCFG/omarchy/hooks/${f#"$CFG/omarchy/hooks/"}"
done < <(find "$CFG/omarchy/hooks" -type f | sort)

# foot/ if the clone ships it
if [ -d "$CFG/foot" ]; then
  while IFS= read -r f; do
    adopt_file "$f" "$DOTCFG/foot/${f#"$CFG/foot/"}"
  done < <(find "$CFG/foot" -type f | sort)
fi

# ---- (c) uwsm env hook: pin OMARCHY_PATH only --------------------------------
ENV_DIR="$DOTCFG/uwsm/env.d"
ENV_FILE="$ENV_DIR/10-hngh-omarchy.conf"
ENV_BODY="OMARCHY_PATH=$UPREAL
# PATH: \$OMARCHY_PATH/bin is prepended by upstream env-bootstrap in dev-link mode"
if [ ! -e "$ENV_FILE" ]; then
  env_act=wrote
  if [ "$DRY" -eq 1 ]; then
    log "would write uwsm env hook ${ENV_FILE#"$DOTCFG"/}"
  else
    mkdir -p "$ENV_DIR"
    printf '%s\n' "$ENV_BODY" >"$ENV_FILE"
    log "wrote uwsm env hook ${ENV_FILE#"$DOTCFG"/} (OMARCHY_PATH=$UPREAL)"
  fi
elif [ "$(cat "$ENV_FILE")" = "$ENV_BODY" ]; then
  env_act=current
  log "skipped (identical) uwsm env hook"
else
  env_act=backed-up
  if [ "$DRY" -eq 1 ]; then
    log "would backup uwsm env hook -> .bak and write"
  else
    mkdir -p "$ENV_DIR"
    mv -- "$ENV_FILE" "$ENV_FILE.bak"
    printf '%s\n' "$ENV_BODY" >"$ENV_FILE"
    log "backed up uwsm env hook -> .bak"
  fi
fi

# ---- (d) summary ---------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
  echo "$PROG (dry-run): home=$ADOPT_HOME would copy=$copied skip=$skipped backup=$backed (nothing written)"
else
  echo "$PROG: home=$ADOPT_HOME copied=$copied skipped=$skipped backed-up=$backed env=$env_act"
fi
exit 0
