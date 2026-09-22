#!/usr/bin/env bash
# test-research-sweep-selfheal.sh -- the cadence caller for the
# research-tsv-path-sweep's orphaned --apply mode (2026-09-22 gate-flap
# cure). Overnight agent sessions committed rows with raw home tokens
# past the sealed writer seams; the sweep red-gated `make test` hourly
# and plan acceptance sat blocked until a manual back-redact landed
# (fc74aa3b, 12h later). This suite drives the self-heal script
# hermetically against a full fixture mirror (sweep + scrub +
# breadcrumbs + the four research TSVs) so the sweep's default scope
# resolves INSIDE the temp git repo: the sweep resolves its default
# scope against its own script dir, so the mirror carries scripts/ +
# lib/ + the data files.
set -u
# fixture containment: never inherit repo selection from the caller's shell
unset GIT_DIR GIT_WORK_TREE
root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/sweep-selfheal-XXXXXX")"
trap 'rm -rf "$tmp"' EXIT

fail() {
  echo "FAIL: $*"
  exit 1
}
pass() { echo "PASS: $*"; }

mkdir -p "$tmp/automation/scripts" "$tmp/automation/lib"
cp "$root/scripts/research-tsv-path-sweep.py" "$tmp/automation/scripts/"
cp "$root/scripts/research-sweep-selfheal.sh" "$tmp/automation/scripts/"
cp "$root/lib/scrub.py" "$tmp/automation/lib/"
cp "$root/lib/breadcrumbs.sh" "$tmp/automation/lib/"
git -C "$tmp" init -q
git -C "$tmp" config user.email t@t
git -C "$tmp" config user.name t

heal() { # drive the self-heal script the way the hour beat does
  (cd "$tmp" && AUTOMATION_ROOT="$tmp/automation" KERNEL="$tmp" \
    JOB_NAME="test-research-beat" \
    bash "$tmp/automation/scripts/research-sweep-selfheal.sh")
}
count() { git -C "$tmp" rev-list --count HEAD; }

# --- (a) committed raw rows: heal back-redacts and commits ONLY the
# swept paths, with a crumb and a green recheck
printf 'verdict\tevidence\tdate\n' >"$tmp/automation/research-dispositions.tsv"
printf 'l1\tadopted -- from /home/bri/x/y.md probes\t2026-09-22\n' \
  >>"$tmp/automation/research-dispositions.tsv"
: >"$tmp/automation/research-lessons.tsv"
: >"$tmp/automation/research-lines.tsv"
: >"$tmp/automation/research-subjects.txt"
git -C "$tmp" add -A
git -C "$tmp" commit -qm seed
n0="$(count)"

out="$(heal 2>&1)"
rc=$?
[ "$rc" -eq 0 ] || fail "heal should exit 0, got $rc: $out"
grep -q '/home/bri' "$tmp/automation/research-dispositions.tsv" &&
  fail "raw token survived the heal"
grep -q '~/x/y.md' "$tmp/automation/research-dispositions.tsv" ||
  fail "tilde rendering missing after heal"
[ "$(count)" -eq $((n0 + 1)) ] || fail "heal must commit exactly once, got $(count)"
[ "$(git -C "$tmp" diff-tree --no-commit-id --name-only -r HEAD)" \
  = "automation/research-dispositions.tsv" ] ||
  fail "heal must commit only the swept file, got: $(git -C "$tmp" diff-tree --no-commit-id --name-only -r HEAD)"
git -C "$tmp" log -1 --format=%s | grep -q "sweep self-heal" ||
  fail "heal commit message must carry the sweep label"
grep -q "sweep-selfheal" "$tmp/automation/STATE.md" ||
  fail "heal must leave a breadcrumb"
(cd "$tmp" && python3 "$tmp/automation/scripts/research-tsv-path-sweep.py" \
  --check) >/dev/null 2>&1 ||
  fail "recheck after heal must be green"
pass "committed raw rows back-redacted; commit confined to swept paths"

# --- (b) clean tree: no-op, no commit, no rewrite
out="$(heal 2>&1)"
[ "$(count)" -eq $((n0 + 1)) ] || fail "clean tree must not commit"
pass "clean tree is a quiet no-op"

# --- (c) dirty working-tree leak: --apply refuses it; nothing
# committed, churn left untouched for the gate alert + live-beat seams
printf 'l2\tplanned -- /home/bri/z.md fresh\n' \
  >>"$tmp/automation/research-dispositions.tsv"
out="$(heal 2>&1)"
[ "$(count)" -eq $((n0 + 1)) ] || fail "dirty leak must not commit"
grep -q '/home/bri/z.md' "$tmp/automation/research-dispositions.tsv" ||
  fail "dirty churn must stay untouched"
pass "dirty leaks left fail-closed for the gate alert"

# --- (d) staged unrelated work: the staged-index guard refuses the
# commit (the research_commit convention); the rewrite itself still runs
git -C "$tmp" checkout -q -- automation/research-dispositions.tsv
mkdir -p "$tmp/docs/research"
printf '# fail-title\nraw /home/bri/docs/w.md prose\n' >"$tmp/docs/research/gap.md"
git -C "$tmp" add docs/research/gap.md
git -C "$tmp" commit -qm mdseed
n1="$(count)"
printf 'operator staged work\n' >"$tmp/automation/operator-note.txt"
git -C "$tmp" add automation/operator-note.txt
out="$(heal 2>&1)"
[ "$(count)" -eq "$n1" ] || fail "staged-index guard must refuse the heal commit"
grep -q '~/docs/w.md' "$tmp/docs/research/gap.md" ||
  fail "clean committed md should still be rewritten"
pass "staged-index guard blocks the commit; rewrite still applied"

echo "ALL PASS"
