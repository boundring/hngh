#!/usr/bin/env bash
# test-omarchy-config-adopt.sh — automation/jobs/omarchy-config-adopt.sh,
# hermetic: a FAKE upstream tree plus a FAKE home live only in the sandbox
# (the real clone and the operator's real ~/.config are never touched).
# Asserts: missing clone rc 3 with remediation line, happy adopt (hypr tree
# with nested rel paths + omarchy/shell.json + hooks samples + foot/, and the
# uwsm env.d hook with the exact OMARCHY_PATH line), differing target ->
# .bak then new content, identical target skipped with no .bak, dry-run
# (--dry-run flag and HNGH_CONFIG_ADOPT_DRY=1 env) writes nothing, idempotent
# second run reports zero copies/backups, unknown flag rc 2.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
fails=0
ok() { echo "ok: $*"; }
bad() {
  echo "BAD: $*"
  fails=$((fails + 1))
}

JOB="$ROOT/jobs/omarchy-config-adopt.sh"

# --- sandbox seams ----------------------------------------------------------
CORE="$SANDBOX/core"
mkdir -p "$CORE"
for t in bash dirname basename mkdir cat cp cmp mv find realpath sort; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$CORE/$t"
done

UP="$SANDBOX/upstream"
HOMES="$SANDBOX/homes"

mkup() { # rebuild the fake upstream tree
  rm -rf "$UP"
  mkdir -p "$UP/config/hypr/deep" "$UP/config/omarchy/hooks/post-boot.d" \
    "$UP/config/foot"
  echo "lua top" >"$UP/config/hypr/hyprland.lua"
  echo "lua input" >"$UP/config/hypr/input.lua"
  echo "lua deep" >"$UP/config/hypr/deep/nested.lua"
  echo '{"bar":1}' >"$UP/config/omarchy/shell.json"
  echo "# hook" >"$UP/config/omarchy/hooks/post-boot.d/sample.sh"
  echo "foot cfg" >"$UP/config/foot/foot.ini"
}
mkup

run() { # UPSTREAM HOME [VAR=VAL ...] args — job with sandboxed PATH + seams
  local up="$1" h="$2"
  shift 2
  PATH="$CORE" OMARCHY_UPSTREAM_DIR="$up" HNGH_CONFIG_ADOPT_HOME="$h" "$@"
}

upreal="$(realpath "$UP")"
CONF_BODY="OMARCHY_PATH=$upreal
# PATH: \$OMARCHY_PATH/bin is prepended by upstream env-bootstrap in dev-link mode"

# --- (a) missing clone: rc 3 + remediation naming path + git clone ----------
H="$HOMES/a"
run "$SANDBOX/nope" "$H" "$JOB" >"$SANDBOX/a.out" 2>"$SANDBOX/a.err"
rc=$?
[ "$rc" -eq 3 ] && grep -q "git clone" "$SANDBOX/a.err" &&
  grep -q "$SANDBOX/nope" "$SANDBOX/a.err" &&
  ok "missing clone: rc 3 + path + git clone hint" ||
  bad "missing clone rc=$rc err=$(cat "$SANDBOX/a.err")"

# --- (b) happy adopt: full tree + exact env.d conf ---------------------------
H="$HOMES/b"
mkup
run "$UP" "$H" "$JOB" >"$SANDBOX/b.out" 2>"$SANDBOX/b.err"
rc=$?
[ "$rc" -eq 0 ] && ok "happy: rc 0" || bad "happy rc=$rc err=$(cat "$SANDBOX/b.err")"
for f in hypr/hyprland.lua hypr/input.lua hypr/deep/nested.lua \
  omarchy/shell.json omarchy/hooks/post-boot.d/sample.sh foot/foot.ini; do
  src="$UP/config/$f" dst="$H/.config/$f"
  [ -f "$dst" ] && [ "$(cat "$dst")" = "$(cat "$src")" ] &&
    ok "happy: $f copied with content" || bad "happy: $f missing/wrong"
done
CONF="$H/.config/uwsm/env.d/10-hngh-omarchy.conf"
[ -f "$CONF" ] && [ "$(cat "$CONF")" = "$CONF_BODY" ] &&
  ok "happy: env.d conf exact two-line body (OMARCHY_PATH pinned)" ||
  bad "happy: conf body got: $(cat "$CONF" 2>/dev/null)"
! grep -q '^PATH=' "$CONF" &&
  ok "happy: conf has no PATH line (upstream env-bootstrap owns it)" ||
  bad "happy: conf leaked a PATH line"
grep -q "copied=6" "$SANDBOX/b.out" &&
  ok "happy: summary counts 6 copies" ||
  bad "happy summary: $(cat "$SANDBOX/b.out")"
grep -q "copied hypr/hyprland.lua" "$SANDBOX/b.err" &&
  ok "happy: per-file action log on stderr" ||
  bad "happy stderr: $(cat "$SANDBOX/b.err")"

# --- (c) differing target: .bak created, new content landed ------------------
H="$HOMES/c"
mkdir -p "$H/.config/hypr"
echo "old local" >"$H/.config/hypr/hyprland.lua"
run "$UP" "$H" "$JOB" >"$SANDBOX/c.out" 2>"$SANDBOX/c.err"
rc=$?
[ "$rc" -eq 0 ] &&
  [ "$(cat "$H/.config/hypr/hyprland.lua")" = "lua top" ] &&
  [ "$(cat "$H/.config/hypr/hyprland.lua.bak")" = "old local" ] &&
  grep -q "backed-up=1" "$SANDBOX/c.out" &&
  ok "differing: .bak kept old, upstream landed, counted" ||
  bad "differing rc=$rc out=$(cat "$SANDBOX/c.out")"

# --- (d) identical target: skipped, no .bak ----------------------------------
H="$HOMES/d"
mkdir -p "$H/.config/hypr"
echo "lua input" >"$H/.config/hypr/input.lua"
run "$UP" "$H" "$JOB" >"$SANDBOX/d.out" 2>"$SANDBOX/d.err"
rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$H/.config/hypr/input.lua.bak" ] &&
  grep -q "skipped=1" "$SANDBOX/d.out" && grep -q "copied=5" "$SANDBOX/d.out" &&
  ok "identical: skipped in place, no .bak, counted" ||
  bad "identical rc=$rc out=$(cat "$SANDBOX/d.out")"

# --- (e) dry-run: flag and env both plan-only, nothing written ---------------
H="$HOMES/e"
run "$UP" "$H" "$JOB" --dry-run >"$SANDBOX/e.out" 2>"$SANDBOX/e.err"
rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$H/.config" ] && grep -qi "would" "$SANDBOX/e.err" &&
  ok "dry-run flag: rc 0, plan printed, nothing written" ||
  bad "dry-run flag rc=$rc err=$(cat "$SANDBOX/e.err")"
H="$HOMES/e2"
HNGH_CONFIG_ADOPT_DRY=1 run "$UP" "$H" "$JOB" >"$SANDBOX/e2.out" 2>"$SANDBOX/e2.err"
rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$H/.config" ] &&
  ok "dry-run env: HNGH_CONFIG_ADOPT_DRY=1 writes nothing" ||
  bad "dry-run env rc=$rc err=$(cat "$SANDBOX/e2.err")"

# --- (f) idempotent second run: zero copied/backed-up ------------------------
H="$HOMES/f"
run "$UP" "$H" "$JOB" >/dev/null 2>&1
run "$UP" "$H" "$JOB" >"$SANDBOX/f.out" 2>"$SANDBOX/f.err"
rc=$?
[ "$rc" -eq 0 ] && grep -q "copied=0" "$SANDBOX/f.out" &&
  grep -q "backed-up=0" "$SANDBOX/f.out" &&
  ! find "$H/.config" -name '*.bak' | grep -q . &&
  ok "idempotent: rerun copies and backs up nothing" ||
  bad "idempotent rc=$rc out=$(cat "$SANDBOX/f.out")"

# --- (g) unknown flag: rc 2, nothing written ----------------------------------
H="$HOMES/g"
run "$UP" "$H" "$JOB" --destroy >"$SANDBOX/g.out" 2>"$SANDBOX/g.err"
rc=$?
[ "$rc" -eq 2 ] && grep -q "usage" "$SANDBOX/g.err" && [ ! -e "$H/.config" ] &&
  ok "usage: unknown flag rc 2 + usage line, nothing written" ||
  bad "usage rc=$rc err=$(cat "$SANDBOX/g.err")"

# --- (h) pre-existing .bak: refuse the backup, skip the file ------------------
H="$HOMES/h2"
run "$UP" "$H" "$JOB" >/dev/null 2>&1
printf 'operator edit\n' >>"$H/.config/foot/foot.ini"
printf 'stale backup\n' >"$H/.config/foot/foot.ini.bak"
run "$UP" "$H" "$JOB" >"$SANDBOX/h2.out" 2>"$SANDBOX/h2.err"
rc=$?
[ "$rc" -eq 0 ] && grep -q "refusing" "$SANDBOX/h2.err" &&
  [ "$(cat "$H/.config/foot/foot.ini.bak")" = "stale backup" ] &&
  grep -q "operator edit" "$H/.config/foot/foot.ini" &&
  grep -q "backed-up=0" "$SANDBOX/h2.out" &&
  ok ".bak refusal: existing .bak preserved, target untouched" ||
  bad ".bak refusal rc=$rc err=$(cat "$SANDBOX/h2.err")"

# --- (i) clone path with embedded newline: rc 3 -------------------------------
H="$HOMES/h3"
UP="$SANDBOX/nl
up"
run "$UP" "$H" "$JOB" >"$SANDBOX/h3.out" 2>"$SANDBOX/h3.err"
rc=$?
[ "$rc" -eq 3 ] && grep -q "newline" "$SANDBOX/h3.err" &&
  ok "newline clone path: rc 3" ||
  bad "newline rc=$rc err=$(cat "$SANDBOX/h3.err")"

# --- summary -------------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
  echo "PASS: test-omarchy-config-adopt"
  exit 0
fi
echo "FAIL: test-omarchy-config-adopt ($fails)"
exit 1
