#!/usr/bin/env bash
# test-config-backup-fail-redact.sh — the config-backup fail() backstop
# must redact /home/<user>/ and /tmp/ path prefixes before an alert row
# or a breadcrumb is written (2026-09-16 boundary redaction). Sources
# the job's real fail() seam against a fake report-queue; hermetic (no
# real ledger writes, no lanes read). fail() exits, so every case runs
# it in a subshell and inspects the recorded seams afterwards.
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
export HNGH_CRUMBS_DB="$sb/crumbs.db"
crumbs() { python3 "$root/lib/crumbs-db.py" export --db "$HNGH_CRUMBS_DB" 2>/dev/null; }
crumbs_reset() { rm -f "$HNGH_CRUMBS_DB" "$HNGH_CRUMBS_DB-wal" "$HNGH_CRUMBS_DB-shm"; }
export JOB_NAME="config-backup-test"
export HNGH_HOME="$sb/hngh-home" # kernel root as the job sees it
mkdir -p "$HNGH_HOME/scripts"

# fake report-queue at the path the job computes: log argv, exit 0
cat >"$HNGH_HOME/scripts/report-queue" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FAKE_QUEUE_LOG"
exit 0
EOF
chmod +x "$HNGH_HOME/scripts/report-queue"

# extract exactly the job's fail() seam (single source of truth): from
# the top of the file through fail()'s closing brace (first column-1
# brace after the fail() header) — carries set -u, report(), and
# fail(); the sourcing lines are rewritten so nothing real is touched.
# Brace-based so line drift above fail() cannot break the cut.
awk '
  /^fail\(\)/ {in_fail = 1}
  in_fail && /^\}/ {print; exit}
  {print}
' "$root/jobs/config-backup.sh" |
 sed -e "s#^\. \"\$(cd \"\$(dirname \"\$0\")/..\" && pwd)/lib/common.sh\"#: #" \
  -e "s#^\. \"\$AUTOMATION_ROOT/lib/breadcrumbs.sh\"#. \"$root/lib/breadcrumbs.sh\" #" \
  -e "s#^report_queue=.*#report_queue=\"\$HNGH_HOME/scripts/report-queue\"#" \
  >"$sb/job-head.sh" || {
 echo "FAIL: cannot extract job head"
 exit 1
}
# shellcheck disable=SC1090
. "$sb/job-head.sh" || {
 echo "FAIL: job head sourcing rc=$?"
 exit 1
}
type fail >/dev/null 2>&1 || {
 echo "FAIL: fail() not sourced"
 exit 1
}

# 1. alert row redacts an absolute home path
(fail "lane1" "missing source: /home/aubergine/dots/vimrc") \
 2>"$sb/err.log"
got="$(cat "$FAKE_QUEUE_LOG")"
case "$got" in
*'~/dots/vimrc'*) ck "alert row home-redacted" clean clean ;;
*) ck "alert row home-redacted" "~/dots/vimrc present" "leak: $got" ;;
esac

# 2. breadcrumb (crumbs journal) is redacted too
crumbs | grep -q '/home/aubergine' && got=leak || got=clean
ck "breadcrumb home-redacted" "clean" "$got"
crumbs | grep -q '~/dots/vimrc' || fails=$((fails + 1))

# 3. alert row redacts a /tmp path
: >"$FAKE_QUEUE_LOG"
crumbs_reset
(fail "lane1" "scratch missing: /tmp/gbd-lane-checkpoint") 2>/dev/null
grep -q '/tmp/gbd-lane-checkpoint' "$FAKE_QUEUE_LOG" && got=leak || got=clean
ck "alert row tmp-redacted" "clean" "$got"
grep -q '~tmp/gbd-lane-checkpoint' "$FAKE_QUEUE_LOG" || fails=$((fails + 1))

# 4. non-path detail text passes through unharmed
: >"$FAKE_QUEUE_LOG"
(fail "lane1" "unknown lane (see manifest)") 2>/dev/null
grep -q 'config-backup lane1: unknown lane (see manifest)' \
 "$FAKE_QUEUE_LOG" || fails=$((fails + 1))

# 5. fail() still exits 1
rc=0
(fail "lane1" "copy failed: /tmp/x") 2>/dev/null || rc=$?
ck "fail exits 1" "1" "$rc"

echo "---"
[ "$fails" -eq 0 ] && echo "ALL PASS" || {
 echo "$fails FAILED"
 exit 1
}
