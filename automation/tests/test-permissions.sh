#!/usr/bin/env bash
# test-permissions.sh — the privilege-model surfaces, hermetic (sandboxed
# HOME/paths, no network, no system mutations). Covers:
# (a) the shipped default profile parses fail-closed (all grants denied);
# (b) enum validation rejects every malformed variant, and perm_load stays
#     at minimum grants after a rejected profile (fail-closed);
# (c) missing profile -> minimum grants, rc 0;
# (d) a granted profile flips exactly its classes;
# (e) sudoers template: no NOPASSWD:ALL, visudo -cf parses it;
# (f) installer --profile non-interactive: resolved grant file written,
#     choices record carries permissions_profile;
# (g) installer TTY checkbox path: answers flip only the granted class.
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

. "$ROOT/lib/permissions.sh"
PERM_DEFAULT_PROFILE="$ROOT/config/permissions-profile.json"

# load_profile FILE -> capture rc + PERM_* in a subshell-free way
load_profile() { perm_load "$1" >/dev/null 2>&1; }

# --- (a) shipped default parses, everything denied ---------------------------
if load_profile "$PERM_DEFAULT_PROFILE"; then
  if [ "$PERM_SECRET_ACCESS" = none ] && [ "$PERM_SNAPSHOTS" = 0 ] &&
    [ "$PERM_PACKAGE_UPDATES" = 0 ] && [ "$PERM_WOL" = 0 ] &&
    [ "$PERM_SOCIAL_POSTING" = 0 ] &&
    [ -z "$PERM_FILE_PATHS" ]; then
    ok "shipped default profile: minimum grants"
  else
    bad "shipped default profile loaded non-minimum grants"
  fi
else
  bad "shipped default profile failed to parse"
fi
perm_granted snapshots && bad "snapshots granted in default" || ok "snapshots denied in default"
perm_secret_ok && bad "secret tier granted in default" || ok "secret tier denied in default"

# --- (b) enum validation: malformed variants are rejected, stay minimum ------
mk() { # NAME JSON -> path
  printf '%s' "$2" >"$SANDBOX/$1.json"
  printf '%s' "$SANDBOX/$1.json"
}
check_reject() { # NAME JSON EXPECTED_FRAG
  local f
  f="$(mk "$1" "$2")"
  reason="$(perm_validate "$f" 2>/dev/null)" && {
    bad "$1: accepted invalid profile"
    return
  }
  case "$reason" in
  *"$3"*) ok "$1 rejected: $reason" ;;
  *) bad "$1: wrong reason '$reason'" ;;
  esac
  if load_profile "$f"; then
    bad "$1: perm_load rc0 on invalid profile"
  elif [ "$PERM_SECRET_ACCESS" = none ] && [ "$PERM_SNAPSHOTS" = 0 ]; then
    ok "$1: perm_load stays fail-closed minimum"
  else
    bad "$1: perm_load leaked grants after rejection"
  fi
}
check_reject badsecret '{"version":1,"secret-access":"keychain","host-actions":{},"file-paths":[],"social-posting":false,"kernel-gates":"operator-only"}' secret-access
check_reject badgates '{"version":1,"secret-access":"none","host-actions":{},"file-paths":[],"social-posting":false,"kernel-gates":"hngh-discretion"}' kernel-gates
check_reject relpath '{"version":1,"secret-access":"none","host-actions":{},"file-paths":["etc/tmp"],"social-posting":false,"kernel-gates":"operator-only"}' file-paths
check_reject dotdot '{"version":1,"secret-access":"none","host-actions":{},"file-paths":["/srv/../etc"],"social-posting":false,"kernel-gates":"operator-only"}' file-paths
check_reject badver '{"version":2,"secret-access":"none","host-actions":{},"file-paths":[],"social-posting":false,"kernel-gates":"operator-only"}' version
check_reject notjson 'not json at all' 'JSON'
check_reject badbool '{"version":1,"secret-access":"none","host-actions":{"snapshots":"yes"},"file-paths":[],"social-posting":false,"kernel-gates":"operator-only"}' booleans

# --- (c) missing profile: minimum grants, rc 0 --------------------------------
if load_profile "$SANDBOX/does-not-exist.json"; then
  perm_granted snapshots && bad "missing profile granted snapshots" ||
    ok "missing profile: rc 0, minimum grants"
else
  bad "missing profile should load fail-closed, not error"
fi

# --- (d) granted profile flips exactly its classes ----------------------------
granted='{"version":1,"secret-access":"1password","host-actions":{"snapshots":true,"package-updates":false,"wol":false},"file-paths":["/srv/hngh-time-travel"],"social-posting":false,"kernel-gates":"operator-only"}'
f="$(mk granted "$granted")"
if load_profile "$f"; then
  perm_granted snapshots && ok "granted snapshots flips" || bad "snapshots grant lost"
  perm_granted package-updates && bad "package-updates flipped without grant" ||
    ok "package-updates stays denied"
  [ "$PERM_SECRET_ACCESS" = 1password ] && [ "$PERM_FILE_PATHS" = /srv/hngh-time-travel ] &&
    ok "secret tier + file paths carried" || bad "fields misread: $PERM_SECRET_ACCESS/$PERM_FILE_PATHS"
else
  bad "valid granted profile failed to parse"
fi

# --- (e) sudoers template: no NOPASSWD:ALL, visudo parses ---------------------
tmpl="$ROOT/config/hngh-automation.sudoers.example"
if grep -v '^[[:space:]]*#' "$tmpl" | grep -q 'NOPASSWD:ALL'; then
  bad "sudoers template contains NOPASSWD:ALL"
else
  ok "sudoers template: no NOPASSWD:ALL"
fi
if command -v visudo >/dev/null 2>&1; then
  if visudo -cf "$tmpl" >/dev/null 2>&1; then
    ok "sudoers template: visudo -cf parses OK"
  else
    bad "sudoers template fails visudo -cf"
  fi
else
  echo "skip: visudo absent"
fi

# --- (f) installer --profile, non-interactive ---------------------------------
INSTALLER="$REPO/install.sh"
mkdir -p "$SANDBOX/all"
for t in python3 git curl jq flock sqlite3 sbcl; do
  p="$(command -v "$t")" && ln -sf "$p" "$SANDBOX/all/$t"
done
if [ -f "$INSTALLER" ]; then
  choices="$SANDBOX/installer-choices.json"
  profout="$SANDBOX/resolved-profile.json"
  out="$(env -i HOME="$SANDBOX" PATH="$SANDBOX/all:/usr/bin:/bin" \
    HNGH_CHOICES_FILE="$choices" HNGH_PERMISSIONS_PROFILE="$profout" \
    /bin/bash "$INSTALLER" --non-interactive --profile "$f" 2>&1 </dev/null)"
  rc=$?
  [ "$rc" -eq 0 ] && ok "installer --profile non-interactive rc 0" ||
    bad "installer --profile rc=$rc: $out"
  if [ -f "$profout" ] && python3 -c '
import json, sys
p = json.load(open(sys.argv[1]))
sys.exit(0 if p["host-actions"]["snapshots"] is True and
          p["host-actions"]["package-updates"] is False and
          p["secret-access"] == "1password" and
          p["file-paths"] == ["/srv/hngh-time-travel"] else 1)
' "$profout" 2>/dev/null; then
    ok "resolved grant profile carries exactly the seed grants"
  else
    bad "resolved grant profile wrong/missing at $profout"
  fi
  grep -q '"permissions_profile"' "$choices" 2>/dev/null &&
    ok "choices record carries permissions_profile" ||
    bad "choices record missing permissions_profile"
fi

# --- (g) installer TTY checkbox path: only the granted class flips ------------
if [ -f "$INSTALLER" ] && command -v script >/dev/null 2>&1; then
  ttyout="$SANDBOX/tty-profile.json"
  # seed grants only snapshots; answers: y (keep), n n n (deny), empty tier, empty dirs
  # (piped stdin: script spins on a file-backed herestring stdin)
  tty="$(env -i HOME="$SANDBOX" PATH="$SANDBOX/all:/usr/bin:/bin" TERM=xterm \
    HNGH_EDITOR=none HNGH_BROWSER=none HNGH_DESKTOP=none HNGH_JS_PM=npm \
    HNGH_PERMISSIONS_PROFILE="$ttyout" HNGH_CHOICES_FILE="$SANDBOX/tty-choices.json" \
    script -qec "/bin/bash $INSTALLER --profile $f" /dev/null \
    < <(printf 'y\nn\nn\nn\n\n\n') 2>&1)"
  case "$tty" in
  *"[x] snapshots"*) ok "checkbox render: granted class shows [x]" ;;
  *) bad "checkbox render missing [x] snapshots: $tty" ;;
  esac
  if [ -f "$ttyout" ] && python3 -c '
import json, sys
p = json.load(open(sys.argv[1]))
sys.exit(0 if p["host-actions"]["snapshots"] is True and
          p["host-actions"]["wol"] is False and
          p["social-posting"] is False and
          p["secret-access"] == "1password" else 1)
' "$ttyout" 2>/dev/null; then
    ok "TTY answers flipped only the granted class"
  else
    bad "TTY-run profile wrong/missing at $ttyout"
  fi
fi

# --- summary ------------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
  echo "PASS: test-permissions"
  exit 0
fi
echo "FAIL: test-permissions ($fails)"
exit 1
