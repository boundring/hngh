#!/usr/bin/env bash
set -u

usage() {
  cat <<'EOF'
Usage: hngh-workspace-migrate.sh --check|--migrate|--rollback [--home PATH]
EOF
}

mode=
home=${HOME:-}
while (($#)); do
  case $1 in
    --home)
      (($# >= 2)) || { printf '%s\n' '--home requires PATH' >&2; exit 2; }
      home=$2
      shift 2
      ;;
    --check|--migrate|--rollback)
      [[ -z $mode ]] || { printf '%s\n' 'exactly one operation is required' >&2; exit 2; }
      mode=${1#--}
      shift
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      printf 'unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -n $mode ]] || { usage >&2; exit 2; }
[[ -n $home && $home != *$'\n'* ]] || { printf '%s\n' 'home path is required' >&2; exit 2; }
home=$(CDPATH= cd -- "$home" 2>/dev/null && pwd) || {
  printf 'home does not exist: %s\n' "$home" >&2
  exit 1
}

canonical=$home/.hngh
roots=(.hngh-night .hngh-day)

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

kind() {
  local path=$1
  if [[ -L $path ]]; then
    printf 'symlink\n'
  elif [[ -d $path ]]; then
    printf 'directory\n'
  elif [[ -e $path ]]; then
    printf 'other\n'
  else
    printf 'absent\n'
  fi
}

state_for() {
  local root=$1
  local source=$home/$root
  local target=$canonical/$root
  local source_kind target_kind source_link
  source_kind=$(kind "$source")
  target_kind=$(kind "$target")
  source_link=
  [[ $source_kind == symlink ]] && source_link=$(readlink -- "$source")

  if [[ $source_kind == directory && $target_kind == absent ]]; then
    printf 'ready\n'
  elif [[ $source_kind == symlink && $source_link == "$target" && $target_kind == directory ]]; then
    printf 'migrated\n'
  elif [[ $source_kind == absent && $target_kind == absent ]]; then
    printf 'absent\n'
  else
    printf 'conflict\n'
  fi
}

check_root() {
  local root=$1 source=$home/$root target=$canonical/$root
  local source_kind target_kind source_link
  source_kind=$(kind "$source")
  target_kind=$(kind "$target")
  source_link=
  [[ $source_kind == symlink ]] && source_link=$(readlink -- "$source")
  printf '%s: %s (source=%s target=%s' "$root" "$(state_for "$root")" "$source_kind" "$target_kind"
  [[ $source_kind == symlink ]] && printf ' link=%s' "$source_link"
  printf ')\n'
}

same_filesystem() {
  local left=$1 right=$2
  [[ $(stat -c '%d' "$left") == $(stat -c '%d' "$right") ]]
}

failure_consumed=0

inject_failure() {
  local point=$1
  if [[ ${HNGH_WORKSPACE_MIGRATE_FAIL_ONCE:-} == "$point" && $failure_consumed -eq 0 ]]; then
    failure_consumed=1
    return 1
  fi
  return 0
}

atomic_mv() {
  local point=$1
  shift
  inject_failure "$point" || return 1
  mv -- "$@"
}

atomic_ln() {
  local point=$1
  shift
  inject_failure "$point" || return 1
  ln -s -- "$@"
}

validate_common() {
  [[ -d $canonical && ! -L $canonical ]] || fail "canonical root is absent or not a directory: $canonical"
}

validate_migrate() {
  local root source target state
  validate_common
  for root in "${roots[@]}"; do
    source=$home/$root
    target=$canonical/$root
    state=$(state_for "$root")
    case $state in
      ready|migrated|absent) ;;
      conflict) fail "unsafe $root state (source=$source target=$target)" ;;
    esac
    if [[ $state == ready ]] && ! same_filesystem "$source" "$canonical"; then
      fail "source and canonical root are on different filesystems: $source"
    fi
    if [[ $(kind "$source") == symlink && $state != migrated ]]; then
      fail "source is an unexpected symlink: $source"
    fi
  done
  for root in "${roots[@]}"; do
    [[ $(state_for "$root") == absent ]] && fail "missing source and target cannot be migrated: $root"
  done
}

migrate_root() {
  local root=$1 source=$home/$root target=$canonical/$root
  [[ $(state_for "$root") == ready ]] || return 0
  atomic_mv migrate-mv "$source" "$target" || fail "could not atomically move $source to $target"
  if ! atomic_ln migrate-ln "$target" "$source"; then
    atomic_mv migrate-recover "$target" "$source" || fail "migration is partially complete; inspect with --check: $source"
    fail "could not install compatibility symlink; migration restored: $source"
  fi
}

validate_rollback() {
  local root source target state link
  validate_common
  for root in "${roots[@]}"; do
    source=$home/$root
    target=$canonical/$root
    state=$(state_for "$root")
    case $state in
      migrated|absent) ;;
      conflict) fail "unsafe rollback state (source=$source target=$target)" ;;
    esac
    if [[ $state == migrated ]]; then
      link=$(readlink -- "$source")
      [[ $link == "$target" ]] || fail "compatibility root points elsewhere: $source"
    fi
  done
}

rollback_root() {
  local root=$1 source=$home/$root target=$canonical/$root
  [[ $(state_for "$root") == migrated ]] || return 0
  if ! inject_failure rollback-rm; then
    fail "could not remove expected compatibility symlink: $source"
  fi
  rm -- "$source" || fail "could not remove expected compatibility symlink: $source"
  atomic_mv rollback-mv "$target" "$source" || {
    if ! ln -s -- "$target" "$source"; then
      fail "rollback is partially complete; inspect with --check: $target"
    fi
    fail "could not atomically restore $target to $source; compatibility link restored"
  }
}

case $mode in
  check)
    validate_common
    for root in "${roots[@]}"; do check_root "$root"; done
    ;;
  migrate)
    validate_migrate
    for root in "${roots[@]}"; do migrate_root "$root"; done
    for root in "${roots[@]}"; do check_root "$root"; done
    ;;
  rollback)
    validate_rollback
    for root in "${roots[@]}"; do rollback_root "$root"; done
    for root in "${roots[@]}"; do check_root "$root"; done
    ;;
esac
