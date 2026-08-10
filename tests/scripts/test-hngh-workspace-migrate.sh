#!/usr/bin/env bash
set -u

ROOT=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
SCRIPT="$ROOT/scripts/hngh-workspace-migrate.sh"
TMP=$(mktemp -d)
trap 'rm -rf -- "$TMP"' EXIT

checks=0
failures=0

pass() {
  checks=$((checks + 1))
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  failures=$((failures + 1))
}

assert_file() {
  local description=$1
  local path=$2
  if [[ -f $path ]]; then
    pass
  else
    fail "$description: missing $path"
  fi
}

assert_dir() {
  local description=$1
  local path=$2
  if [[ -d $path && ! -L $path ]]; then
    pass
  else
    fail "$description: not an ordinary directory: $path"
  fi
}

assert_absent() {
  local description=$1
  local path=$2
  if [[ ! -e $path && ! -L $path ]]; then
    pass
  else
    fail "$description: still exists: $path"
  fi
}

assert_symlink() {
  local description=$1
  local path=$2
  local target=$3
  if [[ -L $path && $(readlink -- "$path") == "$target" ]]; then
    pass
  else
    fail "$description: $path is not a symlink to $target"
  fi
}

assert_contains() {
  local description=$1
  local text=$2
  local needle=$3
  if [[ $text == *"$needle"* ]]; then
    pass
  else
    fail "$description: output lacks $needle"
  fi
}

expect_success() {
  local description=$1
  shift
  local output
  if output=$("$@" 2>&1); then
    pass
  else
    fail "$description: expected success, got $?\n$output"
  fi
  EXPECTED_OUTPUT=$output
}

expect_failure() {
  local description=$1
  shift
  local output
  if output=$("$@" 2>&1); then
    fail "$description: expected failure"
  else
    pass
  fi
  EXPECTED_OUTPUT=$output
}

make_home() {
  local home=$1
  mkdir -p -- "$home/.hngh"
}

HOME1="$TMP/home-1"
mkdir -p -- "$HOME1/.hngh-night/tasks" "$HOME1/.hngh-day/artifacts"
make_home "$HOME1"
printf 'lane-byte\n' >"$HOME1/.hngh-night/tasks/lane.txt"
printf '\001artifact-byte\n' >"$HOME1/.hngh-day/artifacts/artifact.bin"

expect_success 'check reports a fresh fixture' "$SCRIPT" --home "$HOME1" --check
assert_contains 'fresh check reports night readiness' "$EXPECTED_OUTPUT" '.hngh-night: ready'
assert_contains 'fresh check reports day readiness' "$EXPECTED_OUTPUT" '.hngh-day: ready'
assert_absent 'check does not create night target' "$HOME1/.hngh/.hngh-night"
assert_absent 'check does not create day target' "$HOME1/.hngh/.hngh-day"

expect_success 'migrate moves both roots' "$SCRIPT" --home "$HOME1" --migrate
assert_dir 'night target is migrated' "$HOME1/.hngh/.hngh-night"
assert_dir 'day target is migrated' "$HOME1/.hngh/.hngh-day"
assert_symlink 'night compatibility root' "$HOME1/.hngh-night" "$HOME1/.hngh/.hngh-night"
assert_symlink 'day compatibility root' "$HOME1/.hngh-day" "$HOME1/.hngh/.hngh-day"
assert_file 'lane file survives migration' "$HOME1/.hngh/.hngh-night/tasks/lane.txt"
assert_file 'artifact file survives migration' "$HOME1/.hngh/.hngh-day/artifacts/artifact.bin"
if cmp -s <(printf 'lane-byte\n') "$HOME1/.hngh/.hngh-night/tasks/lane.txt"; then pass; else fail 'lane bytes changed'; fi
if cmp -s <(printf '\001artifact-byte\n') "$HOME1/.hngh/.hngh-day/artifacts/artifact.bin"; then pass; else fail 'artifact bytes changed'; fi

night_inode=$(stat -c '%i' "$HOME1/.hngh/.hngh-night")
day_inode=$(stat -c '%i' "$HOME1/.hngh/.hngh-day")
expect_success 'migrate is idempotent' "$SCRIPT" --home "$HOME1" --migrate
if [[ $(stat -c '%i' "$HOME1/.hngh/.hngh-night") == "$night_inode" ]]; then pass; else fail 'idempotent migrate changed night target'; fi
if [[ $(stat -c '%i' "$HOME1/.hngh/.hngh-day") == "$day_inode" ]]; then pass; else fail 'idempotent migrate changed day target'; fi
expect_success 'check reports migrated fixture' "$SCRIPT" --home "$HOME1" --check
assert_contains 'migrated check reports night state' "$EXPECTED_OUTPUT" '.hngh-night: migrated'
assert_contains 'migrated check reports day state' "$EXPECTED_OUTPUT" '.hngh-day: migrated'

expect_success 'rollback restores both roots' "$SCRIPT" --home "$HOME1" --rollback
assert_dir 'night source restored' "$HOME1/.hngh-night"
assert_dir 'day source restored' "$HOME1/.hngh-day"
assert_absent 'night target removed on rollback' "$HOME1/.hngh/.hngh-night"
assert_absent 'day target removed on rollback' "$HOME1/.hngh/.hngh-day"
if cmp -s <(printf 'lane-byte\n') "$HOME1/.hngh-night/tasks/lane.txt"; then pass; else fail 'rollback changed lane bytes'; fi
if cmp -s <(printf '\001artifact-byte\n') "$HOME1/.hngh-day/artifacts/artifact.bin"; then pass; else fail 'rollback changed artifact bytes'; fi
expect_success 'rollback is idempotent on fresh roots' "$SCRIPT" --home "$HOME1" --rollback

HOME2="$TMP/home-absent-canonical"
mkdir -p -- "$HOME2/.hngh-night/tasks"
printf 'must-stay\n' >"$HOME2/.hngh-night/tasks/file"
expect_failure 'missing canonical root fails closed' "$SCRIPT" --home "$HOME2" --migrate
assert_file 'missing canonical root leaves source' "$HOME2/.hngh-night/tasks/file"
assert_absent 'missing canonical root creates no target' "$HOME2/.hngh/.hngh-night"

HOME3="$TMP/home-source-symlink"
make_home "$HOME3"
mkdir -p -- "$TMP/unexpected-source"
ln -s -- "$TMP/unexpected-source" "$HOME3/.hngh-night"
expect_failure 'unexpected source symlink fails closed' "$SCRIPT" --home "$HOME3" --migrate
assert_symlink 'unexpected source symlink remains' "$HOME3/.hngh-night" "$TMP/unexpected-source"
assert_absent 'unexpected source creates no target' "$HOME3/.hngh/.hngh-night"

HOME4="$TMP/home-destination-file"
make_home "$HOME4"
mkdir -p -- "$HOME4/.hngh-night"
printf 'conflict\n' >"$HOME4/.hngh/.hngh-night"
expect_failure 'destination file conflict fails closed' "$SCRIPT" --home "$HOME4" --migrate
assert_dir 'destination conflict leaves source' "$HOME4/.hngh-night"
assert_file 'destination conflict remains' "$HOME4/.hngh/.hngh-night"

HOME5="$TMP/home-partial"
make_home "$HOME5"
mkdir -p -- "$HOME5/.hngh/.hngh-night/tasks"
printf 'partial\n' >"$HOME5/.hngh/.hngh-night/tasks/file"
expect_failure 'missing source with existing target fails closed' "$SCRIPT" --home "$HOME5" --migrate
assert_dir 'partial target remains' "$HOME5/.hngh/.hngh-night"
assert_absent 'partial migration does not recreate source' "$HOME5/.hngh-night"

HOME6="$TMP/home-mixed"
make_home "$HOME6"
mkdir -p -- "$HOME6/.hngh-night/tasks" "$HOME6/.hngh-day"
printf 'night\n' >"$HOME6/.hngh-night/tasks/file"
printf 'day-conflict\n' >"$HOME6/.hngh/.hngh-day"
expect_failure 'any root conflict blocks all moves' "$SCRIPT" --home "$HOME6" --migrate
assert_dir 'mixed conflict leaves night source' "$HOME6/.hngh-night"
assert_absent 'mixed conflict does not create night target' "$HOME6/.hngh/.hngh-night"

HOME7="$TMP/home-rollback-conflict"
make_home "$HOME7"
mkdir -p -- "$HOME7/.hngh-night" "$HOME7/.hngh/.hngh-night"
expect_failure 'rollback source conflict fails closed' "$SCRIPT" --home "$HOME7" --rollback
assert_dir 'rollback source conflict remains' "$HOME7/.hngh-night"
assert_dir 'rollback target conflict remains' "$HOME7/.hngh/.hngh-night"

HOME8="$TMP/home-destination-symlink"
make_home "$HOME8"
mkdir -p -- "$HOME8/.hngh-night" "$TMP/unexpected-target"
ln -s -- "$TMP/unexpected-target" "$HOME8/.hngh/.hngh-night"
expect_failure 'destination symlink conflict fails closed' "$SCRIPT" --home "$HOME8" --migrate
assert_dir 'destination symlink leaves source' "$HOME8/.hngh-night"
assert_symlink 'destination symlink remains' "$HOME8/.hngh/.hngh-night" "$TMP/unexpected-target"

HOME9="$TMP/home-migrate-link-failure"
mkdir -p -- "$HOME9/.hngh-night/tasks" "$HOME9/.hngh-day/artifacts"
make_home "$HOME9"
printf 'recover-night\n' >"$HOME9/.hngh-night/tasks/file"
printf 'recover-day\n' >"$HOME9/.hngh-day/artifacts/file"
expect_failure 'migrate link failure is injected' env HNGH_WORKSPACE_MIGRATE_FAIL_ONCE=migrate-ln "$SCRIPT" --home "$HOME9" --migrate
assert_dir 'migrate link failure restores night source' "$HOME9/.hngh-night"
assert_dir 'migrate link failure restores day source' "$HOME9/.hngh-day"
assert_absent 'migrate link failure removes night target' "$HOME9/.hngh/.hngh-night"
assert_absent 'migrate link failure removes day target' "$HOME9/.hngh/.hngh-day"
expect_success 'migrate resumes after link failure' "$SCRIPT" --home "$HOME9" --migrate
assert_symlink 'resumed night compatibility root' "$HOME9/.hngh-night" "$HOME9/.hngh/.hngh-night"
assert_symlink 'resumed day compatibility root' "$HOME9/.hngh-day" "$HOME9/.hngh/.hngh-day"

HOME10="$TMP/home-rollback-mv-failure"
mkdir -p -- "$HOME10/.hngh-night/tasks" "$HOME10/.hngh-day/artifacts"
make_home "$HOME10"
printf 'rollback-night\n' >"$HOME10/.hngh-night/tasks/file"
printf 'rollback-day\n' >"$HOME10/.hngh-day/artifacts/file"
expect_success 'rollback failure fixture migrates' "$SCRIPT" --home "$HOME10" --migrate
expect_failure 'rollback move failure is injected' env HNGH_WORKSPACE_MIGRATE_FAIL_ONCE=rollback-mv "$SCRIPT" --home "$HOME10" --rollback
assert_symlink 'rollback move failure restores night link' "$HOME10/.hngh-night" "$HOME10/.hngh/.hngh-night"
assert_dir 'rollback move failure leaves night target' "$HOME10/.hngh/.hngh-night"
assert_symlink 'rollback move failure leaves day link' "$HOME10/.hngh-day" "$HOME10/.hngh/.hngh-day"
assert_dir 'rollback move failure leaves day target' "$HOME10/.hngh/.hngh-day"
expect_success 'rollback resumes after move failure' "$SCRIPT" --home "$HOME10" --rollback
assert_dir 'resumed rollback restores night source' "$HOME10/.hngh-night"
assert_dir 'resumed rollback restores day source' "$HOME10/.hngh-day"
assert_absent 'resumed rollback removes night target' "$HOME10/.hngh/.hngh-night"
assert_absent 'resumed rollback removes day target' "$HOME10/.hngh/.hngh-day"

if ! grep -Eq '(^|[[:space:]])(cp|rsync)([[:space:]]|$)' "$SCRIPT"; then
  pass
else
  fail 'script contains a copy or rsync fallback'
fi
if grep -q 'mv --' "$SCRIPT"; then pass; else fail 'script does not use atomic mv'; fi

if [[ $failures -eq 0 ]]; then
  printf '%d checks passed\n' "$checks"
else
  printf '%d checks, %d failures\n' "$checks" "$failures" >&2
  exit 1
fi
