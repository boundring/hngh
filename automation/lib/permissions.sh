# permissions.sh — the hngh permission-profile seam (contract:
# docs/records/2026-09-12-privilege-model.md §profile). ONE authoritative
# grant surface: automation/config/permissions-profile.json (shipped
# default = everything denied) or the operator-granted profile the
# installer writes (default ~/.hngh-automation/permissions-profile.json).
# hngh machinery reads grants ONLY through this file — never ambient
# state, never hngh discretion. Fail-closed: a missing profile loads
# minimum grants (rc 0); a present-but-invalid profile ALSO loads minimum
# grants and returns nonzero (operator setup error, surfaced loudly).
# Requires jq (a bootstrap prereq). Sourced, never run.
set -u

PERM_DEFAULT_PROFILE="${PERM_DEFAULT_PROFILE:-${AUTOMATION_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}/config/permissions-profile.json}"

_perm_set_defaults() {
  PERM_SECRET_ACCESS=none
  PERM_SNAPSHOTS=0
  PERM_PACKAGE_UPDATES=0
  PERM_WOL=0
  PERM_FILE_PATHS="" # newline-separated absolute paths
  PERM_SOCIAL_POSTING=0
}

# perm_validate FILE -> prints "OK" on stdout, rc 0; on any violation
# prints the reason and rc 1. Pure: reads the file, writes nothing.
perm_validate() { # FILE
  local f="$1" out
  [ -r "$f" ] || {
    echo "permissions: unreadable profile: $f"
    return 1
  }
  out="$(jq -r '
    if type != "object" then "profile must be a JSON object"
    elif ((.version // 0) != 1) then "version must be 1"
    elif ([.["secret-access"]] | inside(["1password", "envfile", "none"]) | not)
      then "secret-access must be 1password|envfile|none"
    elif (.["host-actions"] | type != "object") then "host-actions must be an object"
    elif ([.["host-actions"][] | type] | any(. != "boolean"))
      then "host-actions values must be booleans"
    elif (.["file-paths"] | type != "array") then "file-paths must be an array"
    elif ([.["file-paths"][] |
            (type == "string" and startswith("/") and (contains("..") | not))]
          | any(not))
      then "file-paths entries must be absolute paths without .."
    elif (.["social-posting"] | type != "boolean") then "social-posting must be boolean"
    elif (.["kernel-gates"] != "operator-only") then "kernel-gates must be operator-only"
    else "OK" end
  ' "$f" 2>/dev/null)" || out="profile is not valid JSON"
  [ "$out" = "OK" ] && return 0
  echo "permissions: $out ($f)"
  return 1
}

# perm_load [FILE] -> 0 iff profile absent (minimum grants) or valid;
# rc 1 iff present and invalid. Either way PERM_* holds only the granted
# values from a VALID profile or the all-denied defaults.
perm_load() { # [FILE]
  local f="${1:-$PERM_DEFAULT_PROFILE}" reason ha
  _perm_set_defaults
  [ -r "$f" ] || return 0
  reason="$(perm_validate "$f")" || {
    echo "$reason" >&2
    return 1
  }
  PERM_SECRET_ACCESS="$(jq -r '.["secret-access"]' "$f")"
  ha="$(jq -cr '.["host-actions"]' "$f")"
  [ "$(jq -r '.snapshots' <<<"$ha")" = true ] && PERM_SNAPSHOTS=1
  [ "$(jq -r '.["package-updates"]' <<<"$ha")" = true ] && PERM_PACKAGE_UPDATES=1
  [ "$(jq -r '.wol' <<<"$ha")" = true ] && PERM_WOL=1
  PERM_FILE_PATHS="$(jq -r '.["file-paths"] | join("\n")' "$f")"
  [ "$(jq -r '.["social-posting"]' "$f")" = true ] && PERM_SOCIAL_POSTING=1
  return 0
}

# perm_granted NAME -> rc 0 iff that host-action/social grant is true.
perm_granted() { # snapshots|package-updates|wol|social-posting
  case "$1" in
  snapshots) [ "$PERM_SNAPSHOTS" = 1 ] ;;
  package-updates) [ "$PERM_PACKAGE_UPDATES" = 1 ] ;;
  wol) [ "$PERM_WOL" = 1 ] ;;
  social-posting) [ "$PERM_SOCIAL_POSTING" = 1 ] ;;
  *)
    echo "permissions: unknown grant class: $1" >&2
    return 1
    ;;
  esac
}

# perm_secret_ok -> rc 0 iff ANY secret tier is granted at all.
perm_secret_ok() { [ "$PERM_SECRET_ACCESS" != "none" ]; }

# perm_paths -> newline-separated time-travel roots (the profile's
# file-paths; the scope the snapshot machinery may touch).
perm_paths() { printf '%s' "$PERM_FILE_PATHS"; }

# sudoers_for PROFILE [USER] -> scoped sudoers.d drop-in on stdout.
# The profile is the durable approval record; this emits the enforcement
# (contract: docs/records/2026-09-12-privilege-model.md §sudoers). Each
# checked host-action maps 1:1 to a Cmnd_Alias; unchecked contribute
# nothing. Fail-closed: an invalid profile emits nothing, rc 1. This
# GENERATES the rules only - nothing here installs them; installation is
# the operator's one password moment (installer offers it; hngh itself
# never runs sudo install).
sudoers_for() { # PROFILE-JSON [USER]
  local f="$1" user="${2:-${HNGH_SUDO_USER:-hngh}}" ha
  perm_validate "$f" >/dev/null || return 1
  ha="$(jq -cr '.["host-actions"]' "$f")"
  local -a aliases=()
  [ "$(jq -r '.["package-updates"]' <<<"$ha")" = true ] &&
    aliases+=(HNGH_PKGCACHE HNGH_PARU_CLEAN)
  [ "$(jq -r '.wol' <<<"$ha")" = true ] && aliases+=(HNGH_WOL)
  [ "$(jq -r '.snapshots' <<<"$ha")" = true ] && aliases+=(HNGH_BTRFS_SNAP)
  cat <<EOF
# hngh-automation scoped sudo rules - generated $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# grant source: permissions-profile.json (the checked host-actions below)
# scoped per docs/records/2026-09-12-privilege-model.md; no NOPASSWD:ALL
EOF
  [ ${#aliases[@]} -eq 0 ] && return 0
  printf '\n# host-actions.package-updates: package cache hygiene only (no installs, no upgrades).\n'
  case " ${aliases[*]} " in
  *" HNGH_PKGCACHE "*)
    printf 'Cmnd_Alias HNGH_PKGCACHE = /usr/bin/paccache -r *\nCmnd_Alias HNGH_PARU_CLEAN = /usr/bin/paru -Sc *\n'
    ;;
  esac
  case " ${aliases[*]} " in
  *" HNGH_WOL "*)
    printf '\n# host-actions.wol: link wake flags only.\nCmnd_Alias HNGH_WOL = /usr/bin/ethtool wol *\n'
    ;;
  esac
  case " ${aliases[*]} " in
  *" HNGH_BTRFS_SNAP "*)
    printf '\n# host-actions.snapshots: btrfs time travel scoped to the profile file-paths; no subvolume delete.\n'
    printf 'Cmnd_Alias HNGH_BTRFS_SNAP = /usr/bin/btrfs subvolume snapshot *, /usr/bin/btrfs subvolume list *\n'
    ;;
  esac
  local joined
  joined="$(printf '%s, ' "${aliases[@]}")"
  printf '\n%s ALL=(root) NOPASSWD: %s\n' "$user" "${joined%, }"
}
