#!/usr/bin/env bash
# test-config-backup-success-quiet.sh — a successful config-backup run must
# NOT file a report-queue row (the 30-min progress spam class, 2026-10-02
# close-half refactor): the crumb journal already carries the success fact
# (including wall seconds for the time ledger). Failure paths keep filing
# alerts. Full-job hermetic run: sandbox HOME/AUTOMATION_ROOT, fake
# report-queue, real lib/ via symlink, commit-only mode (no push).
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
cleanup() { rm -rf "$sb"; }
trap cleanup EXIT
fails=0
ck() { # label want got
 if [ "$2" = "$3" ]; then
  echo "ok - $1"
 else
  echo "NOT OK - $1: want [$2] got [$3]"
  fails=$((fails + 1))
 fi
}

# sandbox tree: fake HOME, fake AUTOMATION_ROOT with fixture manifest,
# real copies of the job + lib (common.sh derives AUTOMATION_ROOT from
# BASH_SOURCE, so env overrides lose — the copy anchors it in the sandbox)
export HOME="$sb/home"
mkdir -p "$HOME/dots" "$HOME/backups/dots" "$sb/automation/jobs"
cp -r "$root/lib" "$sb/automation/lib"
cp "$root/jobs/config-backup.sh" "$sb/automation/jobs/"
cat >"$sb/automation/jobs/config-lanes.tsv" <<'EOF'
# lane	backup-repo	remote	sources
quiet-lane	backups/dots		dots/vimrc
missing-lane	backups/dots		dots/nope.conf
EOF
printf 'hostkey=1\n' >"$HOME/dots/vimrc"
git -C "$HOME/backups/dots" init >/dev/null 2>&1

export AUTOMATION_ROOT="$sb/automation"
export HNGH_CRUMBS_DB="$sb/crumbs.db"
export HNGH_HOME="$sb/hngh-home" # kernel root as the job sees it
mkdir -p "$HNGH_HOME/scripts"
export JOB_NAME="config-backup-test"
crumbs() { python3 "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }

# fake report-queue at the path the job computes (invoked via python3):
# log argv, exit 0
cat >"$HNGH_HOME/scripts/report-queue" <<'EOF'
import os, sys
with open(os.environ["FAKE_QUEUE_LOG"], "a") as fh:
    fh.write(" ".join(sys.argv[1:]) + "\n")
EOF
chmod +x "$HNGH_HOME/scripts/report-queue"
export FAKE_QUEUE_LOG="$sb/calls.log"
: >"$FAKE_QUEUE_LOG"

# 1. RED (current code): successful commit-only run files a progress row
bash "$sb/automation/jobs/config-backup.sh" quiet-lane >/dev/null 2>"$sb/err1.log"
rc1=$?
ck "success run exits 0" "0" "$rc1"
rows="$(grep -c 'progress' "$FAKE_QUEUE_LOG" 2>/dev/null || true)"
ck "success run files zero report rows" "0" "$rows"
crumbs | grep -q 'config-backup quiet-lane: ok' && got=crumbed || got=nocrumb
ck "success run still crumbs" "crumbed" "$got"
crumbs | grep -q 'wall=' && got=wall || got=nowall
ck "crumb carries wall seconds" "wall" "$got"

# 2. failure path still files an alert row
: >"$FAKE_QUEUE_LOG"
bash "$sb/automation/jobs/config-backup.sh" missing-lane >/dev/null 2>&1
rc2=$?
ck "missing-source run exits 1" "1" "$rc2"
grep -q 'alert config-backup missing-lane: missing source' \
 "$FAKE_QUEUE_LOG" && got=alerted || got=silent
ck "failure still alerts" "alerted" "$got"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
 echo "FAILED ($fails)"
 exit 1
}
