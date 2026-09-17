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

# --- (f) crystallized research docs (2026-09-17 writer-gap follow-
# through): the docs/research/*.md glob scope, multi-line md docs, the
# same redact_home fixpoint + URL-preservation invariants.
mkdir -p "$tmp/docs/research"
cat >"$tmp/docs/research/2026-09-17-fail-x.md" <<'EOF'
# If the probe returns a clean negative for /home/bri/Projects/etc/hngh does the gate pass?

Status: crystallized from research line `fail-x`.

The gate lives at /home/bri/Projects/etc/hngh/tests and prior note
~/Projects/notes.md already uses the ledger convention; see
https://x.io/home/u/f (wire data).
EOF
printf 'clean doc, no paths at all\n' >"$tmp/docs/research/2026-09-17-clean.md"
git -C "$tmp" add docs
git -C "$tmp" commit -qm docs

# (f1) check: raw lines counted in the md doc, clean doc silent-zero
out="$(cd "$tmp" && AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --check --files "docs/research/*.md" 2>&1)"
rc=$?
echo "$out" | grep -q "2026-09-17-fail-x.md: 2 raw-token line(s)" \
 || fail "check must count 2 raw md lines (tilde line is clean by the fixpoint): $out"
[ "$rc" -eq 1 ] || fail "check rc must be 1 with a raw md doc, got $rc"
pass "check counts raw lines in tracked md docs via glob"

# (f2) apply: title + body tilde-rendered, tilde + URL untouched.
# (A deleted or modified worktree file would be dirty -> refused, so
# the apply runs on the clean raw committed doc, blob = worktree here.)
out="$(cd "$tmp" && AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --apply --files "docs/research/*.md" 2>&1)"
[ "$?" -eq 0 ] || fail "md apply should succeed: $out"
grep -q '/home/bri' "$tmp/docs/research/2026-09-17-fail-x.md" \
 && fail "raw path survived md apply"
grep -q 'negative for ~/Projects/etc/hngh does the gate pass' \
 "$tmp/docs/research/2026-09-17-fail-x.md" \
 || fail "md title tilde rendering missing"
grep -qF '~/Projects/notes.md' "$tmp/docs/research/2026-09-17-fail-x.md" \
 || fail "md pre-existing tilde clobbered"
grep -qF 'https://x.io/home/u/f' "$tmp/docs/research/2026-09-17-fail-x.md" \
 || fail "md URL home component clobbered"
pass "apply back-redacts md docs from HEAD blobs; invariants hold"

# (f3) re-check green after the md sweep
out="$(cd "$tmp" && AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --check --files "docs/research/*.md" 2>&1)"
[ "$?" -eq 0 ] || fail "md recheck must be green: $out"
pass "md recheck green after apply"

# (f4) dirty md doc refuses with rc=2
printf 'fresh raw /home/bri/z.md line\n' >>"$tmp/docs/research/2026-09-17-clean.md"
out="$(cd "$tmp" && AUTOMATION_ROOT="$root" python3 "$root/scripts/research-tsv-path-sweep.py" \
  --apply --files "docs/research/*.md" 2>&1)"
rc=$?
[ "$rc" -eq 2 ] || fail "dirty md refusal must rc=2, got $rc"
echo "$out" | grep -q "dirty" || fail "dirty md refusal must name the file"
pass "refuses dirty tracked md docs"

# --- (g) 2026-09-17 gate-spec redesign (gap-g2-predicate-false-
# positives): the dash-form predicate is DISCRIMINATING (stem followed
# by a path-shaped segment) and check/apply are two-phase. A dash-only
# finding parks (report-only, exit 0); only an actionable redact_home
# delta turns --check red; --apply rewrites tilde deltas only and
# never rewrites a committed dash-only id. Deployment stem defaults
# from config.env when the env seam is unset (make test runs env-less).
# Plumbing first: --apply never commits, so HEAD still holds the RAW
# seed blob; commit the redacted baseline (plus (d)'s raw probe row,
# itself re-swept) so (g) starts from a clean committed state.
git -C "$tmp" add disp.tsv
git -C "$tmp" commit -qm d-leftover
out="$(env -u HNGH_ROUTER_PATHY_STEMS AUTOMATION_ROOT="$root" \
  python3 "$root/scripts/research-tsv-path-sweep.py" --apply --files "$tmp/disp.tsv" 2>&1)"
[ "$?" -eq 0 ] || fail "baseline re-sweep should succeed: $out"
git -C "$tmp" add disp.tsv
git -C "$tmp" commit -qm g-baseline
# (g1) dash-only leak: parked, rc=0, zero raw-token lines
printf 'disp-dash\tadopted\tadopted -- findings sound\tmodel:t\t# SUPPORTIVE fail-20260914-Where-exactly-in-home-bricker-Projects-e review pass\t2026-09-17\t\t\t\n' >>"$tmp/disp.tsv"
out="$(env -u HNGH_ROUTER_PATHY_STEMS AUTOMATION_ROOT="$root" \
  python3 "$root/scripts/research-tsv-path-sweep.py" --check --files "$tmp/disp.tsv" 2>&1)"
rc=$?
[ "$rc" -eq 0 ] || fail "dash-only check must park with rc=0, got $rc: $out"
echo "$out" | grep -q "0 raw-token line(s)" || fail "dash-only must report zero raw-token lines: $out"
echo "$out" | grep -q "1 dash-form finding(s) (report-only" \
 || fail "dash-only finding must be reported as parked: $out"
pass "dash-only finding parks: rc=0, report-only, no raw-token count"
# (g2) tilde leak: still actionable red
printf 'disp-tilde\tadopted\tadopted -- from /home/bri/x/y.md probes\tmodel:t\t\t2026-09-17\t\t\t\n' >>"$tmp/disp.tsv"
out="$(env -u HNGH_ROUTER_PATHY_STEMS AUTOMATION_ROOT="$root" \
  python3 "$root/scripts/research-tsv-path-sweep.py" --check --files "$tmp/disp.tsv" 2>&1)"
rc=$?
[ "$rc" -eq 1 ] || fail "tilde check must rc=1, got $rc: $out"
echo "$out" | grep -q "1 raw-token line" || fail "tilde check must count 1 raw line: $out"
pass "redact_home delta is the actionable rc=1 signal"
# (g3) apply rewrites the tilde row; the dash-only id survives verbatim.
# Commit both (g1)+(g2) rows so HEAD carries them; apply reads that
# HEAD blob and rewrites tilde deltas only.
git -C "$tmp" add disp.tsv
git -C "$tmp" commit -qm g-seed
out="$(env -u HNGH_ROUTER_PATHY_STEMS AUTOMATION_ROOT="$root" \
  python3 "$root/scripts/research-tsv-path-sweep.py" --apply --files "$tmp/disp.tsv" 2>&1)"
[ "$?" -eq 0 ] || fail "apply should succeed: $out"
grep -q '/home/bri' "$tmp/disp.tsv" && fail "raw path survived apply"
grep -q '~/x/y.md probes' "$tmp/disp.tsv" || fail "tilde row not rewritten"
grep -q 'fail-20260914-Where-exactly-in-home-bricker-Projects-e' "$tmp/disp.tsv" \
 || fail "committed dash-only research id must survive apply untouched"
pass "apply rewrites tilde deltas only; dash-only id survives"
# (g4) re-check green; the parked dash finding still reports
out="$(env -u HNGH_ROUTER_PATHY_STEMS AUTOMATION_ROOT="$root" \
  python3 "$root/scripts/research-tsv-path-sweep.py" --check --files "$tmp/disp.tsv" 2>&1)"
rc=$?
[ "$rc" -eq 0 ] || fail "recheck after apply must stay parked-green: $out"
echo "$out" | grep -q "1 dash-form finding(s) (report-only" \
 || fail "parked dash finding must still report after apply: $out"
pass "recheck parked-green; park report persists for the operator"
# (g5) the discriminating predicate keeps the real payload class red
# when it rides WITH a raw slash token, and keeps the prose FP classes
# silent (the corpus false-positive classes from the retired predicate)
printf 'disp-both\tadopted\tadopted -- fail-20260916-Do-any-files-in-home-bricker-Projects-et /home/bri/q.md\tmodel:t\t\t2026-09-17\t\t\t\n' >>"$tmp/disp.tsv"
printf 'prose\tadopted\tadopted -- root cause: the network-down headroom predicate; use tmp dir for fixtures\tmodel:t\t\t2026-09-17\t\t\t\n' >>"$tmp/disp.tsv"
out="$(env -u HNGH_ROUTER_PATHY_STEMS AUTOMATION_ROOT="$root" \
  python3 "$root/scripts/research-tsv-path-sweep.py" --check --files "$tmp/disp.tsv" 2>&1)"
rc=$?
[ "$rc" -eq 1 ] || fail "payload+raw check must rc=1, got $rc: $out"
echo "$out" | grep -q "1 raw-token line" || fail "prose FP rows must stay silent: $out"
pass "discriminating predicate: payload class caught, prose classes silent"

echo "test-research-tsv-path-sweep: all assertions passed"
