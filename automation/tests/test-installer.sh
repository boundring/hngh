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
# (e) sentinel: sudo never INVOKED, no curl|bash of third-party scripts
#     anywhere in the installer (install.sh + lib/platform.sh). The
#     word-boundary form lets the installer MENTION the sudoers.d
#     template (a pointer the operator follows) without calling sudo.
#     bootstrap --install's sudo path is out of scope (it predates the
#     installer and is fail-closed).
# (f) presentation degradation: piped, NO_COLOR, and --no-color runs emit
#     zero escape bytes (CI/hermetic logs stay greppable);
# (g) colored pty run carries the Winamp masthead, playlist numbers 01-05
#     in execution order, and the moss-mapped accent codes.
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

# --- (e) sentinel: no sudo outside the operator-prompted grant block, -------
# no curl|bash anywhere. The ONE sanctioned sudo surface is the interactive
# phase-5b grant (the operator answers y at a TTY; non-interactive runs never
# reach it - (f) and test-permissions (g) prove that behaviorally).
sentinel_hits=""
grant_block=""
if [ -f "$INSTALLER" ]; then
  grant_block="$(sed -n '/# --- phase 6b: scoped sudo grant/,/^step_row 06 permissions ok$/p' "$INSTALLER")"
  rest="$(sed '/# --- phase 6b: scoped sudo grant/,/^step_row 06 permissions ok$/d' "$INSTALLER")"
  # comments are prose, not invocation - judge code lines only
  sentinel_hits="$(grep -v '^[[:space:]]*#' <<<"$rest" |
    grep -nE '\bsudo\b|curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh')"
  case "$grant_block" in
  *"sudo visudo -cf"*) ok "grant block: visudo -cf validation precedes install" ;;
  *) bad "grant block missing visudo -cf validation" ;;
  esac
  case "$grant_block" in
  *chmod\ 440*) ok "grant block: installs mode 0440" ;;
  *) bad "grant block missing chmod 440" ;;
  esac
fi
if [ -f "$PLATFORM" ]; then
  sentinel_hits="$sentinel_hits$(grep -nE '\bsudo\b|curl[^|]*\|[[:space:]]*(ba)?sh|wget[^|]*\|[[:space:]]*(ba)?sh' "$PLATFORM")"
fi
if [ -z "$sentinel_hits" ]; then
  ok "sentinel: no sudo / curl|bash in install.sh or lib/platform.sh"
else
  bad "sentinel tripped: $sentinel_hits"
fi

# --- (f) degradation: piped / NO_COLOR / --no-color -> no escape bytes ------
# The presentation layer must strip cleanly: escape-free output keeps CI and
# hermetic logs greppable (masthead/playlist render only on a color TTY).
esc="$(printf '\033')"
if [ -f "$INSTALLER" ]; then
  plain="$(env -i HOME="$HOME" PATH="$SANDBOX/all:/usr/bin:/bin" \
    /bin/bash "$INSTALLER" --non-interactive --check 2>&1 </dev/null)"
  if printf '%s' "$plain" | grep -q "$esc"; then
    bad "piped run emitted escape bytes (non-TTY must be plain)"
  else
    ok "piped run is escape-free"
  fi
  noc="$(env -i HOME="$HOME" PATH="$SANDBOX/all:/usr/bin:/bin" TERM=xterm NO_COLOR=1 \
    script -qec "/bin/bash $INSTALLER --non-interactive --check" /dev/null 2>&1)"
  if printf '%s' "$noc" | grep -q "$esc"; then
    bad "NO_COLOR under a pty still colored"
  else
    ok "NO_COLOR under a pty is plain"
  fi
  flag="$(env -i HOME="$HOME" PATH="$SANDBOX/all:/usr/bin:/bin" TERM=xterm \
    script -qec "/bin/bash $INSTALLER --non-interactive --check --no-color" /dev/null 2>&1)"
  if printf '%s' "$flag" | grep -q "$esc"; then
    bad "--no-color under a pty still colored"
  else
    ok "--no-color under a pty is plain"
  fi
fi

# --- (g) colored pty run: masthead + playlist numbers + moss codes ----------
# env -i leaves COLORTERM unset -> the 256-color path is deterministic here;
# the truecolor form is accepted too in case the contract gains one.
if [ -f "$INSTALLER" ]; then
  color="$(env -i HOME="$HOME" PATH="$SANDBOX/all:/usr/bin:/bin" TERM=xterm \
    script -qec "/bin/bash $INSTALLER --non-interactive --check" /dev/null 2>&1)"
  case "$color" in
  *"keeps the llama"*) ok "masthead present (wordmark + tagline)" ;;
  *) bad "masthead missing in colored run" ;;
  esac
  prev=-1
  order=1
  for n in 01 02 03 04 05 06 07; do
    pos="$(printf '%s' "$color" | grep -abo -m1 "$n\." | cut -d: -f1)"
    if [ -z "$pos" ] || [ "$pos" -le "$prev" ]; then
      order=0
      break
    fi
    prev="$pos"
  done
  if [ "$order" -eq 1 ]; then
    ok "playlist numbers 01-07 present in execution order"
  else
    bad "playlist numbers missing or out of order in colored run"
  fi
  for w in platform prereqs stage preferences services permissions record; do
    printf '%s' "$color" | grep -q "$w" || bad "playlist step '$w' missing"
  done
  case "$color" in
  *"38;5;107m"* | *"38;2;127;160;94m"*) ok "moss-mapped accent codes present" ;;
  *) bad "moss accent code missing in colored run" ;;
  esac
fi

# --- summary ----------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
  echo "PASS: test-installer"
  exit 0
fi
echo "FAIL: test-installer ($fails)"
exit 1
