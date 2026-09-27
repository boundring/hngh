#!/usr/bin/env bash
# 28-omp-changelog-watch -- day-tier oh-my-pi upstream changelog watch
# (2026-09-27 operator directive: integrate new oh-my-pi changes into
# hngh operations daily).
#
# Fetches packages/coding-agent/CHANGELOG.md from the oh-my-pi repo
# (UA-pinned), diffs released version headings against the last-seen
# state in the hngh userspace home (db/omp-changelog/last-seen), and
# files one identity-deduped progress row per new version (identity
# omp-changelog:<version>, 30d window) so releases surface in the
# operator newspaper and feed the daily-integration research lane.
# First run only arms the watch (records the newest version, files one
# armed row) so a fresh install never floods the queue. A failed fetch
# files one alert row (identity omp-changelog-watch:fetch, 7d window)
# and leaves state untouched. If the last-seen version goes absent from
# upstream headings (history rewrite, or more new versions than the
# per-run cap), the watch re-arms with one alert row instead of
# flooding. Fail-closed: every path exits 0; on success only
# breadcrumbs escape.
#
# usage: cadence/calendar/daily/28-omp-changelog-watch.sh (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
URL="${HNGH_OMP_CHANGELOG_URL:-https://raw.githubusercontent.com/can1357/oh-my-pi/main/packages/coding-agent/CHANGELOG.md}"
STATE_DIR="$HNGH_HOME_DIR/db/omp-changelog"
STATE="$STATE_DIR/last-seen"
UA="hngh-changelog-watch/1 (+https://github.com/boundring/hngh)"
NEW_CAP=5       # max new versions per run before re-arm (flood guard)
MONTH_S=2592000 # per-version identity window
WEEK_S=604800   # watch-health identity window
JOB_NAME="28-omp-changelog-watch"

file_report() { # kind text ident window
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  ${3:+--identity "$3"} --window "${4:-$MONTH_S}" >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

save_state() { # version -> atomic write
 printf '%s\n' "$1" >"$STATE.new" && mv "$STATE.new" "$STATE"
}

mkdir -p "$STATE_DIR" 2>/dev/null || true

tmp="$(mktemp)"
if ! curl -fsSL --max-time 30 -A "$UA" "$URL" >"$tmp" 2>/dev/null; then
 rm -f "$tmp"
 file_report alert "omp-changelog-watch: fetch failed -- $URL; state untouched; retry next tick" \
  "omp-changelog-watch:fetch" "$WEEK_S"
 exit 0
fi

# Released version headings, newest first: "## [x.y.z] - date".
mapfile -t vers < <(grep -E '^## \[' "$tmp" |
 grep -v '\[Unreleased\]' |
 sed -E 's/^## \[([^]]+)\].*/\1/')
rm -f "$tmp"
if [ "${#vers[@]}" -eq 0 ]; then
 breadcrumb "$JOB_NAME" "parse-empty" "no version headings in fetched changelog"
 exit 0
fi
newest="${vers[0]}"

last=""
[ -f "$STATE" ] && last="$(head -n1 "$STATE" 2>/dev/null)"

if [ -z "$last" ]; then
 save_state "$newest"
 file_report progress "omp-changelog-watch armed at oh-my-pi coding-agent $newest; each future release files one row here for the daily-integration lane (2026-09-27 operator directive)" \
  "omp-changelog-watch:armed"
 exit 0
fi

# New = headings newest-first until the last-seen match (exclusive).
n=0
for v in "${vers[@]}"; do
 [ "$v" = "$last" ] && break
 n=$((n + 1))
done
if [ "$n" -eq 0 ]; then
 exit 0 # nothing new
fi
if [ "$n" -eq "${#vers[@]}" ] || [ "$n" -gt "$NEW_CAP" ]; then
 # last-seen absent upstream (history rewrite) or a deep backlog:
 # re-arm on newest rather than flood the queue.
 save_state "$newest"
 file_report alert "omp-changelog-watch: last-seen $last not traceable upstream ($n new since, cap $NEW_CAP) -- re-armed at $newest; read CHANGELOG.md for the skipped span" \
  "omp-changelog-watch:rearm" "$WEEK_S"
 exit 0
fi

i=$((n - 1))
while [ "$i" -ge 0 ]; do
 v="${vers[$i]}"
 file_report progress "oh-my-pi coding-agent $v released -- see packages/coding-agent/CHANGELOG.md; evaluate hngh integration (2026-09-27 directive: daily oh-my-pi integration)" \
  "omp-changelog:$v"
 i=$((i - 1))
done
save_state "$newest"
exit 0
