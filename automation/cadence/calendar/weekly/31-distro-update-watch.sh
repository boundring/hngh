#!/usr/bin/env bash
# 31-distro-update-watch -- week-tier Arch Linux / CachyOS / Omarchy
# upstream release+news watch (2026-09-28 operator directive: once-a-week
# update watch, filed as report-queue rows; reports, never acts).
#
# Three independent checks per run (curl --max-time 15, UA-pinned):
#   arch:    https://archlinux.org/feeds/news/ -- newest item guid/title
#            (RSS), reusing the 28-omp-changelog-watch algorithm: new
#            items newest-first until last-seen, cap 5, re-arm alert if
#            last-seen is absent from the feed.
#   cachyos: https://api.github.com/repos/CachyOS/CachyOS/releases/latest
#            -- tag_name. No CachyOS release feed convention existed
#            in-repo (checked 2026-09-28), so GitHub releases/latest per
#            directive.
#   omarchy: https://api.github.com/repos/omacom/omarchy/releases/latest
#            -- tag_name.
# Dedupe: per-source last-seen files under
# $HNGH_HOME_DIR/db/distro-watch/ (same userspace home and format as
# 28-omp-changelog-watch). First sighting per source only arms (one
# armed row, state recorded, no flood); later new ids file one progress
# row each (identity distro-watch:<source>:<id>, 30d window). A failed
# fetch files one alert row (identity distro-watch:<source>:fetch, 7d
# window) and leaves that source's state untouched; the remaining
# sources are still checked. Fail-soft: every path exits 0; on success
# only breadcrumbs escape.
#
# usage: cadence/calendar/weekly/31-distro-update-watch.sh (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
ARCH_URL="${HNGH_DISTRO_ARCH_URL:-https://archlinux.org/feeds/news/}"
CACHYOS_URL="${HNGH_DISTRO_CACHYOS_URL:-https://api.github.com/repos/CachyOS/CachyOS/releases/latest}"
OMARCHY_URL="${HNGH_DISTRO_OMARCHY_URL:-https://api.github.com/repos/omacom/omarchy/releases/latest}"
STATE_DIR="$HNGH_HOME_DIR/db/distro-watch"
UA="hngh-distro-watch/1 (+https://github.com/boundring/hngh)"
NEW_CAP=5       # max new arch items per run before re-arm (flood guard)
MONTH_S=2592000 # per-id identity window
WEEK_S=604800   # watch-health identity window (fetch/rearm)
JOB_NAME="31-distro-update-watch"

file_report() { # kind text ident window [evidence]
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  ${3:+--identity "$3"} --window "${4:-$MONTH_S}" \
  ${5:+--evidence "$5"} >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

save_state() { # source id -> atomic write
 printf '%s\n' "$2" >"$STATE_DIR/last-$1.new" &&
  mv "$STATE_DIR/last-$1.new" "$STATE_DIR/last-$1"
}

last_id() { # source -> stored id ("" when unarmed)
 local f="$STATE_DIR/last-$1"
 if [ -f "$f" ]; then head -n1 "$f" 2>/dev/null; fi
}

mkdir -p "$STATE_DIR" 2>/dev/null || true

# --- arch linux news (RSS; sibling flood/rearm algorithm) -------------------
tmp="$(mktemp)"
if curl -fsSL --max-time 15 -A "$UA" "$ARCH_URL" >"$tmp" 2>/dev/null; then
 # "guid|title" per <item>, newest first (RSS order)
 mapfile -t items < <(awk 'BEGIN{RS="<item>"} NR>1 {
  t=""; g=""
  if (match($0, /<title>[^<]*/)) t=substr($0, RSTART+7, RLENGTH-7)
  if (match($0, /<guid[^>]*>[^<]*/)) {
   g=substr($0, RSTART, RLENGTH); sub(/^<guid[^>]*>/, "", g)
  }
  if (g != "") print g "|" t
 }' "$tmp")
 rm -f "$tmp"
 if [ "${#items[@]}" -eq 0 ]; then
  breadcrumb "$JOB_NAME" "parse-empty" "no items in fetched arch news feed"
 else
  newest="${items[0]%%|*}"
  last="$(last_id arch)"
  if [ -z "$last" ]; then
   save_state arch "$newest"
   file_report progress "distro-watch armed on Arch Linux news at $newest; future news items file one row here weekly (2026-09-28 operator directive)" \
    "distro-watch:arch:armed"
  elif [ "$newest" != "$last" ]; then
   # New = items newest-first until the last-seen match (exclusive).
   n=0
   for it in "${items[@]}"; do
    [ "${it%%|*}" = "$last" ] && break
    n=$((n + 1))
   done
   if [ "$n" -eq "${#items[@]}" ] || [ "$n" -gt "$NEW_CAP" ]; then
    # last-seen absent from the feed (history rewrite) or a deep
    # backlog: re-arm on newest rather than flood the queue.
    save_state arch "$newest"
    file_report alert "distro-watch: arch last-seen not traceable upstream ($n new since, cap $NEW_CAP) -- re-armed at $newest; read archlinux.org/news for the skipped span" \
     "distro-watch:arch:rearm" "$WEEK_S"
   else
    i=$((n - 1))
    while [ "$i" -ge 0 ]; do
     it="${items[$i]}"
     file_report progress "Arch Linux news: ${it#*|} (${it%%|*})" \
      "distro-watch:arch:${it%%|*}"
     i=$((i - 1))
    done
    save_state arch "$newest"
   fi
  fi
 fi
else
 rm -f "$tmp"
 file_report alert "distro-watch: arch news feed unreachable ($ARCH_URL); state untouched; retry next tick" \
  "distro-watch:arch:fetch" "$WEEK_S"
fi

# --- github release tags (cachyos, omarchy; identical shape) ----------------
check_release() { # source url
 local src="$1" tmp tag last
 tmp="$(mktemp)"
 if ! curl -fsSL --max-time 15 -A "$UA" "$2" >"$tmp" 2>/dev/null; then
  rm -f "$tmp"
  file_report alert "distro-watch: $src releases feed unreachable ($2); state untouched; retry next tick" \
   "distro-watch:$src:fetch" "$WEEK_S"
  return 0
 fi
 tag="$(grep -oE '"tag_name"[[:space:]]*:[[:space:]]*"[^"]+"' "$tmp" |
  head -n1 | sed -E 's/.*"([^"]+)"$/\1/')"
 rm -f "$tmp"
 if [ -z "$tag" ]; then
  breadcrumb "$JOB_NAME" "parse-empty" "no tag_name in fetched $src release payload"
  return 0
 fi
 last="$(last_id "$src")"
 if [ -z "$last" ]; then
  save_state "$src" "$tag"
  file_report progress "distro-watch armed on $src at $tag; future releases file one row here weekly (2026-09-28 operator directive)" \
   "distro-watch:$src:armed"
 elif [ "$tag" != "$last" ]; then
  file_report progress "$src $tag released (was $last)" \
   "distro-watch:$src:$tag"
  save_state "$src" "$tag"
 fi
}
check_release cachyos "$CACHYOS_URL"
check_release omarchy "$OMARCHY_URL"
exit 0
