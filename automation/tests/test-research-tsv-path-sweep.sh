#!/usr/bin/env bash
# test-research-tsv-path-sweep.sh -- the GAP-B follow-through sweep
# (2026-09-17): committed research-TSV rows that landed raw are
# back-redacted through lib/scrub.py's redact_home (tilde family), the
# SAME convention as the writer-seam cures, never a new token family.
# Hermetic: runs the sweep against a temp git repo seeded with raw
# rows; red-first against the tool's own refusal paths.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/tsv-sweep-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() { echo "FAIL: $*"; exit 1; }
pass() { echo "PASS: $*"; }

git -C "$tmp" init -q
git -C "$tmp" config user.email t@t
git -C "$tmp" config user.name t

# (a) --check reports the leak and exits non-zero on a raw file
printf 'line\taction\tverdict\treviewer\tevidence\tdate\tsupport\toppose\tfollowons\n' >"$tmp/disp.tsv"
printf 'l1\tadopted\tadopted -- from /home/bri/x/y.md probes\tmodel:t\t/home/bri/Projects/hngh/docs/r.md\t2026-09-17\ts\to\t\n' >>"$tmp/disp.tsv"
printf 'clean row with ~/tilde and https://x.io/home/u/f stays\n' >>"$tmp/disp.tsv"
git -C "$tmp" add disp.tsv
git -C "$tmp" commit -qm seed

out="$(AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --check --files "$tmp/disp.tsv" 2>&1)"
rc=$?
echo "$out" | grep -q "1 raw-token line" || fail "check should report 1 raw line: $out"
[ "$rc" -eq 1 ] || fail "check rc must be 1 on a raw file, got $rc"
pass "check reports leaks and fails closed"

# (b) --apply rewrites HEAD content through redact_home; tilde forms
# and URL home components survive
out="$(AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --apply --files "$tmp/disp.tsv" 2>&1)"
[ "$?" -eq 0 ] || fail "apply should succeed: $out"
grep -q '/home/bri' "$tmp/disp.tsv" && fail "raw path survived apply"
grep -q '~/x/y.md probes' "$tmp/disp.tsv" || fail "verdict tilde rendering missing"
grep -q '~/Projects/hngh/docs/r.md' "$tmp/disp.tsv" || fail "evidence tilde rendering missing"
grep -qF 'https://x.io/home/u/f' "$tmp/disp.tsv" || fail "URL home component must survive"
grep -q '~/tilde' "$tmp/disp.tsv" || fail "existing tilde must survive"
pass "apply back-redacts; tilde family preserved; URLs untouched"

# (c) re-check on the swept file is green
AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --check --files "$tmp/disp.tsv" >/dev/null 2>&1 \
  || fail "recheck after apply must be green"
pass "recheck green after apply"

# (d) refuse dirty files: a live-beat append between read and write
printf 'fresh\tplanned\tts\tnew raw /home/bri/z.md\n' >>"$tmp/disp.tsv"
out="$(AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --apply --files "$tmp/disp.tsv" 2>&1)"
rc=$?
[ "$rc" -eq 2 ] || fail "dirty refusal must rc=2, got $rc"
echo "$out" | grep -q "dirty" || fail "refusal must name the dirty file"
pass "refuses dirty working-tree files (live-beat race guard)"

# (e) missing HEAD blob refuses
out="$(AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --apply --files "$tmp/absent.tsv" 2>&1)"
rc=$?
[ "$rc" -eq 2 ] || fail "absent-file refusal must rc=2, got $rc"
pass "refuses files with no HEAD blob"

echo "test-research-tsv-path-sweep: all assertions passed"
