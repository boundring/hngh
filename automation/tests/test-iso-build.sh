#!/usr/bin/env bash
# test-iso-build.sh — iso/build-live-iso.sh, hermetic: mkarchiso is a PATH
# seam stub (records exact argv, honors MK_STUB_RC, drops a fake .iso in
# the -o dir); ISO_PROFILE_DIR points the broken-profile case at a sandbox
# copy so the repo profile is never touched. Asserts: exact mkarchiso
# argv, artifact printed on stdout, default work/out under HNGH_HOME_DIR,
# usage rc 2, missing-mkarchiso rc 3, broken-profile rc 3 with NO stub
# invocation, failure rc propagation. No network, no real build, no sudo,
# no system mutations.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
fails=0
ok() { echo "ok: $*"; }
bad() {
  echo "NOT OK: $*"
  fails=$((fails + 1))
}

JOB="$ROOT/iso/build-live-iso.sh"

# --- sandbox seams --------------------------------------------------------
CORE="$SANDBOX/core"
BIN="$SANDBOX/bin"
mkdir -p "$CORE" "$BIN"
for t in bash dirname basename mkdir date cat ls head; do
  p="$(command -v "$t" 2>/dev/null)" && ln -sf "$p" "$CORE/$t"
done

# mkarchiso stub: records argv to $MK_LOG, exits $MK_STUB_RC, drops a fake
# artifact into the -o directory
cat >"$BIN/mkarchiso" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$MK_LOG"
OUT_DIR=""
prev=""
for a in "$@"; do
  [ "$prev" = "-o" ] && OUT_DIR="$a"
  prev="$a"
done
[ -n "$OUT_DIR" ] && mkdir -p -- "$OUT_DIR" && : >"$OUT_DIR/hngh-stub-x86_64.iso"
exit "${MK_STUB_RC:-0}"
STUB
chmod +x "$BIN/mkarchiso"

MK_LOG="$SANDBOX/mkarchiso.log"
HOME_DIR="$SANDBOX/home"

run() { # [VAR=VAL ...] args — job with stubbed PATH
  PATH="$CORE:$BIN" HNGH_HOME_DIR="$HOME_DIR" MK_LOG="$MK_LOG" "$@"
}

# --- (a) happy path: exact argv, artifact printed -------------------------
run "$JOB" --work "$SANDBOX/work" --out "$SANDBOX/out" \
  >"$SANDBOX/a.out" 2>"$SANDBOX/a.err"
rc=$?
EXPECT_ARGV="-v -w $SANDBOX/work -o $SANDBOX/out $ROOT/iso/profile"
if [ "$rc" -eq 0 ]; then ok "happy: rc 0"; else bad "happy rc=$rc err=$(cat "$SANDBOX/a.err")"; fi
[ "$(cat "$MK_LOG")" = "$EXPECT_ARGV" ] &&
  ok "happy: EXACT mkarchiso argv (-v -w WORK -o OUT PROFILE)" ||
  bad "argv got: $(cat "$MK_LOG")"
[ -f "$SANDBOX/out/hngh-stub-x86_64.iso" ] &&
  ok "happy: stub artifact exists in --out" ||
  bad "artifact missing in --out"
grep -q "build-live-iso: $SANDBOX/out/hngh-stub-x86_64.iso" "$SANDBOX/a.out" &&
  ok "happy: artifact path printed" ||
  bad "stdout got: $(cat "$SANDBOX/a.out")"

# --- (b) defaults: work/out under HNGH_HOME_DIR/db/iso --------------------
rm -f "$MK_LOG"
run "$JOB" >"$SANDBOX/b.out" 2>"$SANDBOX/b.err"
rc=$?
[ "$rc" -eq 0 ] &&
  [ "$(cat "$MK_LOG")" = "-v -w $HOME_DIR/db/iso/work -o $HOME_DIR/db/iso/out $ROOT/iso/profile" ] &&
  ok "defaults: work/out land under HNGH_HOME_DIR/db/iso" ||
  bad "defaults rc=$rc argv=$(cat "$MK_LOG" 2>/dev/null)"

# --- (c) usage: unknown flag -> rc 2, no build ------------------------------
rm -f "$MK_LOG"
run "$JOB" --destroy >"$SANDBOX/c.out" 2>"$SANDBOX/c.err"
rc=$?
[ "$rc" -eq 2 ] && grep -q "usage: build-live-iso.sh" "$SANDBOX/c.err" &&
  ok "usage: unknown flag rc 2 + usage line" ||
  bad "usage rc=$rc err=$(cat "$SANDBOX/c.err")"
[ ! -e "$MK_LOG" ] && ok "usage: mkarchiso not invoked" || bad "usage ran mkarchiso"

# --- (d) missing prereq: no mkarchiso on PATH -> rc 3 ----------------------
PATH="$CORE" HNGH_HOME_DIR="$HOME_DIR" "$JOB" \
  >"$SANDBOX/d.out" 2>"$SANDBOX/d.err"
rc=$?
[ "$rc" -eq 3 ] && grep -q "mkarchiso not found" "$SANDBOX/d.err" &&
  ok "prereq: missing mkarchiso rc 3 + remediation line" ||
  bad "prereq rc=$rc err=$(cat "$SANDBOX/d.err")"

# --- (e) broken profile: validation names the file, stub untouched --------
rm -f "$MK_LOG"
cp -r "$ROOT/iso/profile" "$SANDBOX/broken"
rm "$SANDBOX/broken/pacman.conf"
ISO_PROFILE_DIR="$SANDBOX/broken" run "$JOB" --work "$SANDBOX/w2" --out "$SANDBOX/o2" \
  >"$SANDBOX/e.out" 2>"$SANDBOX/e.err"
rc=$?
[ "$rc" -eq 3 ] && grep -q "profile missing: pacman.conf" "$SANDBOX/e.err" &&
  ok "profile: missing file named, rc 3" ||
  bad "profile rc=$rc err=$(cat "$SANDBOX/e.err")"
[ ! -e "$MK_LOG" ] &&
  ok "profile: validation fires before any build" ||
  bad "profile: mkarchiso ran despite broken profile"

# --- (f) failure propagation: stub rc 7 -> wrapper rc 7 --------------------
MK_STUB_RC=7 run "$JOB" --work "$SANDBOX/w3" --out "$SANDBOX/o3" \
  >"$SANDBOX/f.out" 2>"$SANDBOX/f.err"
rc=$?
[ "$rc" -eq 7 ] &&
  ok "propagate: mkarchiso failure rc passes through" ||
  bad "propagate rc=$rc"

# --- summary ----------------------------------------------------------------
if [ "$fails" -eq 0 ]; then
  echo "PASS: test-iso-build"
  exit 0
fi
echo "FAIL: test-iso-build ($fails)"
exit 1
