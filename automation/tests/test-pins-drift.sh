#!/usr/bin/env bash
# test-pins-drift.sh -- hermetic proofs for the pins-vs-pacman drift
# checker (jobs/pins-drift.py + 30-pins-drift.sh beat, 2026-09-27,
# design docs/research/2026-09-26-arc-20260925-os-package-pairing.md).
#   m1) no pins file -> created with header + prereq_pkg seed, exit 0.
#   m2) clean match -> ok:true, drift empty, unpinned counted.
#   m3) --json shape: {drift:[{name,pin,db,kind}],unpinned_count,ok}.
#   m4) pinned-missing -> kind=missing, db null, --check still exits 0.
#   m5) version below floor -> kind=older counted, exit 0.
#   m6) epoch-aware-enough compare: 1: floor beats epochless db;
#       higher epoch floor stays clean vs lower-epoch db.
#   m7) malformed 2-field pins row -> skipped with a stderr count,
#       well-formed rows still checked.
#   m8) pacman stub fails both -Q and -Qq -> exit 2, stderr has repr.
#   m9) pacman binary absent (PATH without it) -> exit 2.
#   b0) beat with no pins file -> seeds it, clean match, no rows.
#   b1) clean beat -> exit 0, nothing filed.
#   b2) drift beat -> ONE alert row identity pins-drift:summary with
#       counts + package names.
#   b3) rerun within the identity window -> no duplicate row.
#   b4) module error beat -> exit 0, pins-drift:error row, no summary.
#   b5) summary and error stay distinct identities (2 bodies total).
# Hermetic: sandbox repo copy, stub pacman FIRST ON PATH driven by a
# fixture file, env overrides HNGH_HOME/HNGH_HOME_DIR/HNGH_REPORT_ROOT,
# no network, no ~/.hngh writes, no live host pacman.
set -u
umask 022 # default 0177 breaks mktemp nesting (report-queue body dir)
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
fx="$(mktemp -d)"
pass=0
fail=0
trap 'rm -rf "$sb" "$fx"' EXIT

mkdir -p "$sb/lib" "$sb/jobs" "$sb/config" "$sb/kernel/scripts" \
 "$sb/report-root" "$sb/hnghhome" "$sb/cadence/calendar/daily" \
 "$sb/bin" "$sb/nopac"
cp -r "$root/lib/." "$sb/lib/"
cp "$root/../scripts/report-queue" "$sb/kernel/scripts/"
cp "$root/jobs/pins-drift.py" "$sb/jobs/" 2>/dev/null || true
cp "$root/cadence/calendar/daily/30-pins-drift.sh" \
 "$sb/cadence/calendar/daily/" 2>/dev/null || true

# deterministic pacman stub FIRST ON PATH: -Q / -Qq read the fixture;
# PACMAN_FAIL=1 makes both subcommands fail (fail-closed path).
cat >"$sb/bin/pacman" <<'EOF'
#!/usr/bin/env bash
[ -n "${PACMAN_FAIL:-}" ] && exit 1
case "$1" in
-Q) cat "$PACMAN_FIXTURE" || exit 1 ;;
-Qq) cut -d' ' -f1 "$PACMAN_FIXTURE" || exit 1 ;;
*) exit 1 ;;
esac
EOF
chmod +x "$sb/bin/pacman"

set_db() { # "name version" lines on stdin -> pacman -Q fixture
 printf '%s\n' "$@" >"$fx/q.txt"
}
default_db() {
 set_db "python 3.13.2" "sqlite 3.46.1" "util-linux 2.41.1" \
  "bash 5.2.37" "linux 6.16.8"
}
write_pins() { # rows on stdin (header added)
 {
  printf 'name\tmin_version\tnote\n'
  cat
 } >"$sb/config/hngh-pins.tsv"
}
seed_pins() { printf 'python\t\t\nsqlite\t\t\nutil-linux\t\t\n' | write_pins; }

ok() { pass=$((pass + 1)); }
bad() {
 fail=$((fail + 1))
 echo "FAIL: $1"
}
chk() { # desc got want
 if [ "$2" = "$3" ]; then ok; else bad "$1 (got '$2' want '$3')"; fi
}

runmod() { # [VAR=V ...] -- module flags... -> one module run
 local envs=()
 while [ "$#" -gt 0 ] && [ "${1#*=}" != "$1" ]; do
  envs+=("$1")
  shift
 done
 env PATH="$sb/bin:$PATH" PACMAN_FIXTURE="$fx/q.txt" \
  HNGH_HOME_DIR="$sb/hnghhome" "${envs[@]+"${envs[@]}"}" \
  python3 -B "$sb/jobs/pins-drift.py" "$@"
}
run() { # [VAR=V ...] -> one beat run in the sandbox
 local envs=()
 while [ "$#" -gt 0 ] && [ "${1#*=}" != "$1" ]; do
  envs+=("$1")
  shift
 done
 env PATH="$sb/bin:$PATH" PACMAN_FIXTURE="$fx/q.txt" \
  HNGH_HOME="$sb/kernel" HNGH_HOME_DIR="$sb/hnghhome" \
  HNGH_REPORT_ROOT="$sb/report-root" "${envs[@]+"${envs[@]}"}" \
  bash "$sb/cadence/calendar/daily/30-pins-drift.sh" >/dev/null 2>&1
}
reset_run() { # fresh queue + userspace home between case groups
 rm -rf "$sb/report-root" "$sb/hnghhome"
 mkdir -p "$sb/report-root" "$sb/hnghhome/db"
}
bodies() { ls "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '; }
ident_count() { # identity-substring -> body files carrying it
 grep -rl "$1" "$sb/report-root/docs/project/report-bodies/" 2>/dev/null | wc -l | tr -d ' '
}
js() { # json-string python-expr -> extracted value on stdout
 printf '%s' "$1" | python3 -c "import json,sys;d=json.load(sys.stdin);print($2)"
}
PINS="$sb/config/hngh-pins.tsv"

# --- m1) no pins file -> created with header + prereq seed ----------------
rm -f "$PINS"
default_db
rc=0
runmod --check >/dev/null 2>&1 || rc=$?
chk "m1: exit 0 on seed" "$rc" "0"
chk "m1: header row" "$(sed -n '3p' "$PINS")" "$(printf 'name\tmin_version\tnote')"
chk "m1: util-linux seeded" "$(grep -c '^util-linux' "$PINS")" "1"
chk "m1: sqlite seeded" "$(grep -c '^sqlite' "$PINS")" "1"
chk "m1: python seeded" "$(grep -c '^python' "$PINS")" "1"
chk "m1: wildcard branch not seeded" \
 "$(grep -c '^\*.*\$\|^"\$1"' "$PINS")" "0"

# --- m2) clean match -> ok, unpinned counted ------------------------------
seed_pins
default_db
j="$(runmod --json 2>/dev/null)"
rc=$?
chk "m2: exit 0" "$rc" "0"
chk "m2: ok true" "$(js "$j" 'd["ok"]')" "True"
chk "m2: drift empty" "$(js "$j" 'len(d["drift"])')" "0"
chk "m2: unpinned counted" "$(js "$j" 'd["unpinned_count"]')" "2"

# --- m3) --json shape ------------------------------------------------------
printf '%s' "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin)
assert sorted(d) == ["drift","ok","unpinned_count"], sorted(d)
assert all(sorted(r) == ["db","kind","name","pin"] for r in d["drift"])' \
 >/dev/null 2>&1 && ok || bad "m3: json shape"

# --- m4) pinned-missing -> kind=missing ------------------------------------
printf 'ghost-pkg\t\tnot installed\n' | write_pins
j="$(runmod --json 2>/dev/null)"
chk "m4: kind missing" "$(js "$j" 'd["drift"][0]["kind"]')" "missing"
chk "m4: db null" "$(js "$j" 'd["drift"][0]["db"]')" "None"
rc=0
runmod --check >/dev/null 2>&1 || rc=$?
chk "m4: --check exit 0 on drift" "$rc" "0"

# --- m5) version below floor -> kind=older ---------------------------------
printf 'python\t3.14\tneed 3.14+\n' | write_pins
j="$(runmod --json 2>/dev/null)"
chk "m5: kind older" "$(js "$j" 'd["drift"][0]["kind"]')" "older"
chk "m5: db captured" "$(js "$j" 'd["drift"][0]["db"]')" "3.13.2"
chk "m5: pin captured" "$(js "$j" 'd["drift"][0]["pin"]')" "3.14"
chk "m5: ok false" "$(js "$j" 'd["ok"]')" "False"

# --- m3b) shape with mixed drift rows --------------------------------------
printf 'python\t3.14\t\nghost-pkg\t\t\n' | write_pins
j="$(runmod --json 2>/dev/null)"
printf '%s' "$j" | python3 -c 'import json,sys;d=json.load(sys.stdin)
assert sorted(d) == ["drift","ok","unpinned_count"], sorted(d)
assert all(sorted(r) == ["db","kind","name","pin"] for r in d["drift"]), d
assert sorted(r["kind"] for r in d["drift"]) == ["missing","older"], d' \
 >/dev/null 2>&1 && ok || bad "m3b: json shape with drift rows"

# --- m6) epoch-aware-enough compare ----------------------------------------
printf 'python\t1:1.0\tepoch floor\n' | write_pins
j="$(runmod --json 2>/dev/null)"
chk "m6: epoch floor beats epochless db" "$(js "$j" 'd["drift"][0]["kind"]')" "older"
set_db "python 1:9.9-1"
printf 'python\t2:0.1\thigher epoch floor\n' | write_pins
j="$(runmod --json 2>/dev/null)"
chk "m6: epoch-1 db sits below epoch-2 floor" \
 "$(js "$j" 'd["drift"][0]["kind"]')" "older"
set_db "python 1:0.5-1"
printf 'python\t9.9\tepochless floor\n' | write_pins
j="$(runmod --json 2>/dev/null)"
chk "m6: epoched db satisfies epochless floor" "$(js "$j" 'len(d["drift"])')" "0"

# --- m7) malformed 2-field row skipped, good rows still checked ------------
{
 printf 'python\t3.11\tgood floor\n'
 printf 'broken-row\t1.0\n'
 printf 'sqlite\t\t\n'
} |
 write_pins
set_db "python 3.0" "sqlite 3.46.1"
err="$(runmod --json 2>&1 >/dev/null)"
j="$(runmod --json 2>/dev/null)"
chk "m7: exit 0 past malformed row" "$?" "0"
case "$err" in
*"skipped 1"*) ok ;;
*) bad "m7: skipped count on stderr (got '$err')" ;;
esac
chk "m7: good row still checked" "$(js "$j" 'd["drift"][0]["name"]')" "python"

# --- m8) pacman fails both -Q and -Qq -> exit 2 ----------------------------
seed_pins
default_db
out="$(runmod PACMAN_FAIL=1 --check --json 2>"$fx/err")"
rc=$?
chk "m8: exit 2 fail-closed" "$rc" "2"
chk "m8: stdout empty" "$(printf '%s' "$out" | grep -c .)" "0"
grep -q "CheckError\|Exception\|Error" "$fx/err" && ok || bad "m8: repr on stderr"

# --- m9) pacman binary absent -> exit 2 ------------------------------------
rc=0
env PATH="$sb/nopac" HNGH_HOME_DIR="$sb/hnghhome" \
 "$(command -v python3)" -B "$sb/jobs/pins-drift.py" --check \
 >/dev/null 2>"$fx/err" || rc=$?
chk "m9: exit 2 without pacman" "$rc" "2"
grep -q "pacman" "$fx/err" && ok || bad "m9: names the missing binary"

# --- b0) beat with no pins file -> seeds, clean, no rows -------------------
rm -f "$PINS"
seed_pins # beat copies a pre-seeded repo; b0 uses seeded pins, clean db
default_db
reset_run
run
chk "b0: beat exit 0" "$?" "0"
chk "b0: nothing filed" "$(bodies)" "0"

# --- b1) clean beat files nothing ------------------------------------------
reset_run
run
chk "b1: beat exit 0" "$?" "0"
chk "b1: no rows" "$(bodies)" "0"

# --- b2) drift beat files ONE summary alert --------------------------------
printf 'python\t9.9.9\timpossible floor\n' | write_pins
default_db
reset_run
run
chk "b2: beat exit 0" "$?" "0"
chk "b2: one summary row" "$(ident_count "pins-drift:summary")" "1"
grep -rq "drifted" "$sb/report-root/docs/project/report-bodies/" &&
 grep -rq "python" "$sb/report-root/docs/project/report-bodies/" &&
 ok || bad "b2: alert text lacks counts/names"

# --- b3) rerun within window -> dedupe -------------------------------------
run
chk "b3: no duplicate row" "$(ident_count "pins-drift:summary")" "1"

# --- b4) module error -> pins-drift:error, beat exit 0 ---------------------
reset_run
run PACMAN_FAIL=1
chk "b4: beat exits 0 on module error" "$?" "0"
chk "b4: error row filed" "$(ident_count "pins-drift:error")" "1"
chk "b4: no summary row" "$(ident_count "pins-drift:summary")" "0"

# --- b5) identities stay distinct ------------------------------------------
printf 'python\t9.9.9\t\n' | write_pins
run
chk "b5: both identities present" "$(bodies)" "2"

echo "test-pins-drift: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
