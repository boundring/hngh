#!/usr/bin/env bash
# bootstrap.sh — the stranger path for the automation tier (peer-review
# finding 1: "no stranger can install hngh").
#
# usage:
#   bash bootstrap.sh --check    validate prerequisites only; writes nothing
#   bash bootstrap.sh            validate + stage the repo-local machine profile
#   bash bootstrap.sh --install  additionally install missing prerequisites via
#                                the SYSTEM package manager only (never
#                                curl|bash of a third-party script)
#
# Idempotent: safe to re-run; never overwrites config/machine.env. No
# secrets are read, created, or inlined — the secret path is the 1Password
# service account interface
# (docs/records/2026-09-09-1password-service-account-interface.md); the full
# env contract (key names only) is env.example.
set -u
case "$0" in */*) ROOT="$(cd "${0%/*}" && pwd)" ;; *) ROOT="$PWD" ;; esac
KERNEL="$(cd "$ROOT/.." && pwd)"
. "$ROOT/lib/prereqs.sh"

MODE=setup
case "${1:-}" in
--check) MODE=check ;;
--install) MODE=install ;;
"") ;;
*)
  echo "usage: bootstrap.sh [--check|--install]" >&2
  exit 2
  ;;
esac

# 1. prerequisites. bash is running us; the rest must be on PATH.
#    sbcl runs the KERNEL's test suite (cd repo && make test), not the
#    automation tier — listed because the kernel is what hngh is.
PREQS=(python3 git curl jq flock sqlite3 sbcl)
missing="$(missing_bins "${PREQS[@]}")"
if [ -n "$missing" ]; then
  echo "hngh-automation prerequisites:" >&2
  for t in $missing; do
    echo "  missing: $t  (system package: $(prereq_pkg "$t"))" >&2
  done
  echo "note: sbcl runs the KERNEL's test suite (cd repo && make test)" >&2
  echo "install with your system package manager (pacman -S / apt install / dnf install ...)," >&2
  echo "  or re-run: bash bootstrap.sh --install" >&2
  [ "$MODE" = install ] || exit 1
fi

# 2. --install: via the system package manager ONLY, never curl|bash.
if [ "$MODE" = install ] && [ -n "$missing" ]; then
  pkgs=""
  for t in $missing; do pkgs="$pkgs $(prereq_pkg "$t")"; done
  install_cmd=""
  if command -v pacman >/dev/null 2>&1; then
    install_cmd="pacman -S --needed"
  elif command -v apt-get >/dev/null 2>&1; then
    install_cmd="apt-get install -y"
  elif command -v dnf >/dev/null 2>&1; then
    install_cmd="dnf install -y"
  elif command -v zypper >/dev/null 2>&1; then
    install_cmd="zypper install -y"
  elif command -v apk >/dev/null 2>&1; then
    install_cmd="apk add"
  else
    echo "--install: no supported system package manager (pacman/apt-get/dnf/zypper/apk)" >&2
    exit 1
  fi
  sudo=""
  [ "$(id -u)" -eq 0 ] || sudo="sudo"
  echo "installing:$pkgs  via: $sudo $install_cmd"
  $sudo $install_cmd $pkgs || {
    echo "package install failed" >&2
    exit 1
  }
  missing="$(missing_bins "${PREQS[@]}")"
  if [ -n "$missing" ]; then
    echo "still missing after install:$missing" >&2
    exit 1
  fi
fi

# 3. repo-local machine profile (host identity; gitignored).
if [ "$MODE" != check ]; then
  mkdir -p "$ROOT/config"
  if [ ! -f "$ROOT/config/machine.env" ]; then
    cp "$ROOT/config/machine.env.example" "$ROOT/config/machine.env"
    echo "staged config/machine.env from the example - edit it for THIS machine"
  else
    echo "machine profile present: config/machine.env"
  fi
fi

echo "prerequisites ok: ${PREQS[*]}"
echo "env contract: $ROOT/env.example (key names only - no values, no secrets)"
echo "secret path: 1Password service account interface -"
echo "  $KERNEL/docs/records/2026-09-09-1password-service-account-interface.md"
echo "next: cd $ROOT && make test ; then see README.md 'Run it live'"
echo "  for what still needs a human (secrets, systemd units, machine profile)."
exit 0
