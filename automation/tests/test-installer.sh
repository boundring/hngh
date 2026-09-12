#!/usr/bin/env bash
# test-installer.sh — install.sh contract, hermetic (sandboxed PATH, no
# network, no system mutations). Extends test-bootstrap.sh: the installer is
# bootstrap (prereqs/env contract/machine profile) + platform checks +
# interactive layer. Covers:
# (a) --non-interactive --check passes the SAME checks bootstrap --check
#     passes on this box (sandbox PATH with every prereq), exit 0;
# (b) platform detection: detect_pm returns pacman here (seamed PATH with a
#     pacman stub ahead of everything);
# (c) the per-manager package map has an entry for EVERY bootstrap prereq;
# (d) interactive prompts are SKIPPED when stdin is not a TTY (no prompt
#     markers, run completes, choices record written with mode
#     non-interactive);
# (e) sentinel: no sudo, no curl|bash of third-party scripts anywhere in the
#     installer (install.sh + lib/platform.sh). bootstrap --install's sudo
#     path is out of scope (it predates the installer and is fail-closed).
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
fails=0
ok() { echo "ok: $*"; }
bad() {
  echo "FAIL: $*"
  fails=$((fails + 1))
}

INSTALLER="$REPO/install.sh"
PLATFORM="$ROOT/lib/platform.sh"

# --- (a) --non-interactive --check passes bootstrap's checks ----------------
if [ -f "$INSTALLER" ] && [ -f "$PLATFORM" ]; then
  ok "installer + platform lib exist"
else
  bad "install.sh or automation/lib/platform.sh missing"
fi
# sandbox PATH holding every prerequisite (same shape as test-bootstrap (c)).
mkdir -p "$SANDBOX/all"
have_all=1
for t in python3 git curl jq flock sqlite3 sbcl; do
  if p="$(command -v "$t")"; then ln -sf "$p" "$SANDBOX/all/$t"; else have_all=0; fi
done
if [ "$have_all" -eq 1 ] && [ -f "$INSTALLER" ]; then
  out="$(env -i HOME="$HOME" PATH="$SANDBOX/all:/usr/bin:/bin" /bin/bash "$INSTALLER" --non-interactive --check 2>&1)"
  rc=$?
  if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'prerequisites ok'; then
    ok "installer --non-interactive --check passes with prereqs present"
  else
    bad "installer --non-interactive --check rc=$rc (want 0 + 'prerequisites ok'): $out"
  fi
else
  bad "skipped (a): prereqs or installer missing"
fi

# --- (b) platform detection: pacman on this box (seamed PATH) ---------------
if [ -f "$PLATFORM" ]; then
  mkdir -p "$SANDBOX/pm"
  printf '#!/usr/bin/env bash\nexit 0\n' >"$SANDBOX/pm/pacman"
  chmod +x "$SANDBOX/pm/pacman"
  pm="$(env PATH="$SANDBOX/pm:/usr/bin:/bin" /bin/bash -c '. "'"$PLATFORM"'" && detect_pm')"
  if [ "$pm" = "pacman" ]; then
    ok "detect_pm -> pacman with pacman stub on PATH"
  else
    bad "detect_pm returned '$pm' (want pacman)"
  fi
  # no package manager on PATH -> empty (fail-closed: no guessing)
  pm="$(env PATH="$SANDBOX/empty" /bin/bash -c '. "'"$PLATFORM"'" && detect_pm' 2>/dev/null)"
  [ -d "$SANDBOX/empty" ] || mkdir -p "$SANDBOX/empty"
  pm="$(env PATH="$SANDBOX/empty" /bin/bash -c '. "'"$PLATFORM"'" && detect_pm')"
  if [ -z "$pm" ]; then
    ok "detect_pm -> empty when no supported manager on PATH"
  else
    bad "detect_pm returned '$pm' with no manager on PATH (want empty)"
  fi
fi

# --- (c) package map covers every prereq per manager ------------------------
if [ -f "$PLATFORM" ]; then
  gap="$(env PATH="$SANDBOX/empty" /bin/bash -c '
    . "'"$PLATFORM"'"
    for pm in pacman apt-get dnf zypper apk; do
      for t in python3 git curl jq flock sqlite3 sbcl; do
        p="$(pkg_for "$pm" "$t")"
        [ -n "$p" ] || echo "$pm/$t"
      done
    done')"
  if [ -z "$gap" ]; then
    ok "package map covers all 7 prereqs across pacman/apt-get/dnf/zypper/apk"
  else
    bad "package map gaps: $gap"
  fi
fi

# --- (d) prompts skipped when stdin is not a TTY -----------------------------
if [ -f "$INSTALLER" ]; then
  choices="$SANDBOX/installer-choices.json"
  out="$(env -i HOME="$HOME" PATH="$SANDBOX/all:/usr/bin:/bin" HNGH_CHOICES_FILE="$choices" \
    /bin/bash "$INSTALLER" --non-interactive 2>&1 </dev/null)"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    ok "installer full run completes without a TTY"
  else
    bad "installer full run rc=$rc without TTY: $out"
  fi
  if printf '%s' "$out" | grep -qi 'prompt\|choose\|\[y/n\]'; then
    bad "installer emitted prompt text without a TTY: $out"
  else
    ok "no prompt text without a TTY"
  fi
  if [ -f "$choices" ] && python3 -c '
import json, sys
c = json.load(open(sys.argv[1]))
sys.exit(0 if c.get("installer_mode") == "non-interactive" else 1)
' "$choices" 2>/dev/null; then
    ok "choices record written with installer_mode=non-interactive"
  else
    bad "choices record missing or wrong mode at $choices"
  fi
fi

# --- (e) sentinel: no sudo, no curl|bash in the installer -------------------
sentinel_hits=""
if [ -f "$INSTALLER" ]; then
  sentinel_hits="$(grep -nE 'sudo|curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$INSTALLER")"
fi
if [ -f "$PLATFORM" ]; then
  sentinel_hits="$sentinel_hits$(grep -nE 'sudo|curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$PLATFORM")"
fi
if [ -z "$sentinel_hits" ]; then
  ok "sentinel: no sudo / curl|bash in install.sh or lib/platform.sh"
else
  bad "sentinel tripped: $sentinel_hits"
fi

# --- summary ----------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
  echo "PASS: test-installer"
  exit 0
fi
echo "FAIL: test-installer ($fails)"
exit 1
