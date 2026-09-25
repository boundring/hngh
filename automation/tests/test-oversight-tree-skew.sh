#!/usr/bin/env bash
# test-oversight-tree-skew.sh — the tree-skew probe carries NO path
# whitelist (2026-09-25 P1e, L3: monitoring never hides state). A dirty
# file is exempt only when its uncommitted delta is append-only machine
# rows with writer stamps ([w=<name>@<rowid>]) younger than 24h.
# Stale stamps, deletions, and un-stamped edits -- docs/project/plans/
# included -- must surface as tree-skew. Hermetic: sandbox git repo with
# a 5h-old commit + fake report-queue.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { rm -rf "$sb"; }
trap cleanup EXIT
fails=0
ck() {
  if [ "$2" = "$3" ]; then echo "ok: $1"; else
    echo "FAIL: $1 (want [$2] got [$3])"
    fails=$((fails + 1))
  fi
}

export FAKE_QUEUE_LOG="$sb/calls.log"
: >"$FAKE_QUEUE_LOG"
export AUTOMATION_ROOT="$root"
export STATE_FILE="$sb/STATE.md"
: >"$STATE_FILE"
export JOB_NAME="tree-skew-test"
export ALERT_LAST="$sb/alert-last"
: >"$ALERT_LAST"

# source the job header through the end of probe_working_tree_skew (its
# closing brace at column 1) so alert() and machine_appended() come along
# but no probe ever runs at source time.
awk '
  /^probe_working_tree_skew\(\)/ {in_p = 1}
  in_p && /^\}/ {print; exit}
  {print}
' "$root/jobs/oversight-tick.sh" |
  sed -e "s#^ROOT=.*#ROOT=\"$root\"#" \
    -e "s#^STATE_FILE=.*#STATE_FILE=\"\$STATE_FILE\"#" \
    >"$sb/job-head.sh"
# shellcheck disable=SC1090
. "$sb/job-head.sh" || exit 1
type probe_working_tree_skew >/dev/null 2>&1 || {
  echo "FAIL: probe_working_tree_skew not sourced"
  exit 1
}
type machine_appended >/dev/null 2>&1 || {
  echo "FAIL: machine_appended not sourced"
  exit 1
}

# fake report-queue: log argv, exit 0
cat >"$sb/rq" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_QUEUE_LOG"
exit 0
EOF
chmod +x "$sb/rq"
REPORT_QUEUE="$sb/rq"

# sandbox repo: committed baseline, commit 5h old (> the 4h skew bar)
mkdir -p "$sb/repo/docs/project/plans"
git -C "$sb/repo" init -q
git -C "$sb/repo" config user.email t@t
git -C "$sb/repo" config user.name t
printf 'base\n' >"$sb/repo/docs/project/plans/routed-x.plan.md"
printf 'base\n' >"$sb/repo/notes.md"
git -C "$sb/repo" add -A
old="$(date -u -d '5 hours ago' --iso-8601=seconds)"
GIT_AUTHOR_DATE="$old" GIT_COMMITTER_DATE="$old" \
  git -C "$sb/repo" commit -qm base
export TREE_SKEW_REPOS="$sb/repo"

fresh="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
stale="$(date -u -d '25 hours ago' +%Y-%m-%dT%H:%M:%SZ)"
p="$sb/repo/docs/project/plans/routed-x.plan.md"

run_probe() {
  : >"$FAKE_QUEUE_LOG"
  : >"$ALERT_LAST"
  probe_working_tree_skew
  grep -q "tree-skew" "$FAKE_QUEUE_LOG" && echo alert || echo none
}

# 1. fresh stamped machine row on a plans/ path is exempt
printf '%s | job | event | detail [w=writer.py@2]\n' "$fresh" >>"$p"
ck "fresh stamped row exempt" none "$(run_probe)"
git -C "$sb/repo" checkout -q -- .

# 2. stamped row older than 24h is skew (freshness, not stamp, is the bar)
printf '%s | job | event | detail [w=writer.py@2]\n' "$stale" >>"$p"
ck "stale stamped row visible" alert "$(run_probe)"
git -C "$sb/repo" checkout -q -- .

# 3. un-stamped edit in docs/project/plans/ is skew (no path whitelist)
printf 'hand edit\n' >>"$p"
ck "plans/ edit visible" alert "$(run_probe)"
git -C "$sb/repo" checkout -q -- .

# 4. deletion alongside stamps is skew (append-only exemption)
sed -i '/base/d' "$sb/repo/notes.md"
ck "deletion visible" alert "$(run_probe)"
git -C "$sb/repo" checkout -q -- .

if [ "$fails" -eq 0 ]; then
  echo "ALL OK"
  exit 0
fi
echo "$fails FAILURES"
exit 1
