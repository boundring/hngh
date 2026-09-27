#!/usr/bin/env bash
# 29-arc-to-slice -- day-tier research->dev converter (the loop's dead
# edge, 2026-09-27: research arcs crystallize and get dispositioned
# parked/killed, but nothing ever converts a crystallized arc into an
# implementable dev slice; 4/4 arcs ended parked/killed with zero code
# landed from them).
#
# Scans research-dispositions.tsv for arcs whose TERMINAL disposition
# (last row per line id) is parked or killed dated today (UTC) and
# whose research-lines.tsv status says the line crystallized
# (crystallized, or reviewed = post-disposition crystallized; the real
# schema never holds "crystallized" on a dispositioned line). Each
# eligible arc gets ONE typed Jev call (lib/typesafe.py ask_choices,
# floor 0.60 per the confidence-floor table): landable-slice files one
# identity-deduped alert row (identity arc-to-slice:<id>, 7d window,
# evidence = the disposition's doc path), needs-operator files an
# operator-item alert row (arc-to-slice-op:<id>, the
# lib/operator-item.sh contract), no-slice files nothing. Deviation
# from the ticket's kind names: report-queue's KINDS whitelist
# (scripts/report-queue:92: progress/expense/optimization/scheduled/
# alert) has no plan-candidate or operator-item kind, and
# scripts/report-queue sits outside automation/ -- alert is the
# identity-deduped durable channel the router (router-tick.py) and
# operator-item shims both build on, and --evidence gives
# changed-doc-only refires. Without TYPESAFE_API_KEY the beat fails
# closed: one alert row (identity arc-to-slice:typed-unavailable, 7d
# window), no candidates. API-error detail lands via typesafe's crumb
# channel
# (26abce6d) -- never duplicated here. Decisions are recorded in the
# userspace home (db/arc-to-slice/state.tsv, arc-id TAB verdict TAB
# ts, atomic mv append) so an arc is asked once, ever; arcs older than
# 7 days (age from the arc-YYYYMMDD id) are stale residue and are left
# to the operator. Fail-closed: every path exits 0; on success only
# breadcrumbs escape.
#
# usage: cadence/calendar/daily/29-arc-to-slice.sh (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
DISPOSITIONS="$AUTOMATION_ROOT/research-dispositions.tsv"
LINES="$AUTOMATION_ROOT/research-lines.tsv"
STATE_DIR="$HNGH_HOME_DIR/db/arc-to-slice"
STATE="$STATE_DIR/state.tsv"
WEEK_S=604800   # identity window (candidates + typed-unavailable alert)
CONF_FLOOR=0.60 # typed-verdict confidence floor (lib/typesafe.py table)
AGE_CAP_D=7     # residue cap: skip arcs older than this many days
JOB_NAME="29-arc-to-slice"

file_report() { # kind text ident window [evidence]
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  ${3:+--identity "$3"} --window "${4:-$WEEK_S}" \
  ${5:+--evidence "$5"} >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

[ -f "$DISPOSITIONS" ] || exit 0
[ -f "$LINES" ] || exit 0
mkdir -p "$STATE_DIR" 2>/dev/null || true

day="$(date -u +%Y-%m-%d)"
today0="$(date -u -d "$day" +%s)"

# Terminal disposition per line (last row wins: an overturned kill is
# adopted, not convertible) restricted to parked/killed rows dated
# today. Malformed rows (fewer than 6 fields) fail closed to skipped.
eligible="$(awk -F'\t' -v today="$day" '
NR>1 && NF>=6 { last[$1]=$0 }
NR>1 && NF>=6 && ($2=="parked" || $2=="killed") && $6==today { cand[$1]=$0 }
END { for (id in cand) if (last[id]==cand[id]) print cand[id] }
' "$DISPOSITIONS")" || eligible=""
[ -n "$eligible" ] || exit 0 # nothing dispositioned today

if [ -z "${TYPESAFE_API_KEY:-}" ]; then # fail closed, one deduped alert
 n="$(printf '%s\n' "$eligible" | grep -c .)"
 file_report alert \
  "arc-to-slice: typed lane unavailable (no TYPESAFE_API_KEY); $n dispositioned arc(s) left unconverted; retry next tick. SLA: 7d window then lapse -- max one alert per week while the key is gone, lane self-ends when the key returns. Halt: 7d identity dedupe, no piling on ticks" \
  "arc-to-slice:typed-unavailable" "$WEEK_S"
 exit 0
fi

new_rows=""
while IFS= read -r row; do
 [ -n "$row" ] || continue
 id="$(printf '%s' "$row" | cut -f1)"
 action="$(printf '%s' "$row" | cut -f2)"
 ev="$(printf '%s' "$row" | cut -f5)"

 case "$id" in arc-*) ;; *) continue ;; esac # arcs only, per the beat's scope

 # residue cap: arc-YYYYMMDD-<slug> ids carry their own birth date
 arc_day="$(printf '%s' "$id" | cut -d- -f2)"
 case "$arc_day" in
 [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]) ;;
 *) arc_day="" ;;
 esac
 if [ -n "$arc_day" ]; then
  arc0="$(date -u -d "${arc_day:0:4}-${arc_day:4:2}-${arc_day:6:2}" +%s 2>/dev/null || echo "$today0")"
  if [ $(((today0 - arc0) / 86400)) -gt "$AGE_CAP_D" ]; then
   breadcrumb "$JOB_NAME" "stale-skip" "$id"
   continue
  fi
 fi

 # already decided? never re-fire (and never a second typed call)
 if awk -F'\t' -v id="$id" '$1==id{found=1} END{exit !found}' "$STATE" 2>/dev/null; then
  continue
 fi

 # line must have crystallized: crystallized, or reviewed (= the
 # post-disposition state of a crystallized line). planned never ran.
 lrow="$(awk -F'\t' -v id="$id" '$1==id{print $2"\t"$4; exit}' "$LINES")"
 lstatus="$(printf '%s' "$lrow" | cut -f1)"
 case "$lstatus" in
 crystallized | reviewed) ;;
 *) continue ;;
 esac
 topic="$(printf '%s' "$lrow" | cut -f2)"

 doc="${ev/#\~/$HOME}"                      # ledger convention: home rendered as ~
 [ -n "$doc" ] && [ -f "$doc" ] || continue # no doc, no judgment

 # one typed call per eligible arc (mirrors 33-research-beat.sh:1008);
 # below-floor or seam failure prints nothing -> arc skipped unrecorded
 # (transient: retried on a later beat; API-error crumbs via typesafe)
 typed_out="$(
  TYPESAFE_ARC="$id $topic" \
   TYPESAFE_DISP="$action: $(printf '%s' "$row" | cut -f3 | cut -c1-400)" \
   TYPESAFE_DOC="$(head -c 6000 "$doc" 2>/dev/null)" \
   python3 -c "
import os, sys
sys.path.insert(0, os.path.join('$AUTOMATION_ROOT', 'lib'))
from typesafe import ask_choices
st = {'arc': os.environ.get('TYPESAFE_ARC', ''),
      'disposition': os.environ.get('TYPESAFE_DISP', ''),
      'doc': os.environ.get('TYPESAFE_DOC', '')}
res = ask_choices(st, {'slice_verdict': (
    'This research arc crystallized into a doc but was dispositioned parked or killed, so no dev work ever started from it. Decide whether the doc names an implementable dev slice. landable-slice: the doc pins concrete, buildable work (named files/surfaces/mechanisms) that an implementer could start from the doc alone. needs-operator: the work is real but blocked on an operator decision (scope, priority, spend, or a policy call). no-slice: the doc names no buildable work (unverified claims, empty crystallization, pure prior-art survey).',
    ['landable-slice', 'needs-operator', 'no-slice'])}).get('slice_verdict', (None, None))
if res[0] in ('landable-slice', 'needs-operator', 'no-slice') and \
        isinstance(res[1], (int, float)) and res[1] >= $CONF_FLOOR:
    print(res[0], '%.2f' % res[1])
" 2>/dev/null || true
 )"
 [ -n "$typed_out" ] || continue
 verdict="${typed_out%% *}"

 # doc-derived one-line proposed slice: the crystallization H1, else
 # the research-line topic
 slice="$(grep -m1 -E '^# ' "$doc" 2>/dev/null | sed 's/^#[[:space:]]*//' | cut -c1-200)"
 [ -n "$slice" ] || slice="$topic"

 reldoc="${doc#"$KERNEL"/}" # text names the repo-relative doc path
 [ "$reldoc" = "$doc" ] && reldoc="${doc##*/}"

 case "$verdict" in
 landable-slice)
  file_report alert \
   "arc-to-slice: research arc $id ($action) names a landable dev slice -- $slice (doc: $reldoc). SLA: 7d then expire -- window lapses, decision stands in state.tsv, never re-files. Halt: one filing per arc, ever (state dedupe stops the lane)" \
   "arc-to-slice:$id" "$WEEK_S" "$ev"
  ;;
 needs-operator)
  file_report alert \
   "arc-to-slice: research arc $id ($action) needs an operator call before any slice -- $slice (doc: $reldoc). SLA: 7d then expire -- window lapses, decision stands in state.tsv, never re-files; an ignored call parks the arc as needs-operator, it does not re-alert. Halt: one filing per arc, ever (state dedupe stops the lane)" \
   "arc-to-slice-op:$id" "$WEEK_S" "$ev"
  ;;
 no-slice) : ;;
 *) continue ;;
 esac
 new_rows="${new_rows}${id}	$verdict	$(date -u +%Y-%m-%dT%H:%M:%SZ)
"
done < <(printf '%s\n' "$eligible" | sort)

# atomic append: decisions survive reruns; no partial state on crash
if [ -n "$new_rows" ]; then
 {
  [ -f "$STATE" ] && cat "$STATE"
  printf '%s' "$new_rows"
 } >"$STATE.new" &&
  mv "$STATE.new" "$STATE" 2>/dev/null || :
fi
exit 0
