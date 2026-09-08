#!/usr/bin/env bash
# 20-model-saturation -- Tier 3 saturation instrument (model-free): measure
# how much of the desktop unsloth model server the automation actually
# used over the last 24h, so idle-governor acceleration is bounded by
# measured headroom, never by schedule for its own sake.
#
# Reads dashboard/telemetry.db directly (telemetry.py has no query
# interface; the session-cost analysis reads the store the same way).
# kind=model events carry no wall-s today (lib/model.sh emits only the
# paid legs -- remote/kimi/lobehub -- without --wall-s), so busy seconds
# per UTC hour = sum(wall_s) when an hour has any, else model-call count
# times the mean measured research-call wall (telemetry kind=research;
# falls back to MODEL_TIMEOUT=300s, config.env, when the store has no
# measured calls in the window). The basis used is named in the row.
# Utilization = busy_s / 3600 against ONE server: the desktop unsloth.
# The deck leg is a second server but only receives overflow today and
# is not counted. One identity-deduped report-queue row per UTC day
# (kind progress, identity model-saturation:<date>, window 86400), so
# "no data yet" files once. Fail-closed: every path exits 0.
#
# usage: cadence/day/20-model-saturation.sh   (via jobs/cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/params.sh"
. "$AUTOMATION_ROOT/lib/failfirst.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
JOB_NAME="${JOB_NAME:-20-model-saturation}"
DB="${HNGH_TELEMETRY_DB:-$AUTOMATION_ROOT/dashboard/telemetry.db}" # seam for hermetic tests
day="$(date -u +%Y-%m-%d)"
ident="model-saturation:$day"

file_report() { # kind text identity
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
  --identity "$3" --window 86400 >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$1" "$2"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $2"
 fi
}

failfirst_summary() { # -> calibration line over the failfirst state files
 # The fail-first machine tunes itself to just below its observed
 # ceiling; this line is the calibration record: current speed per
 # operation, outcome counts, and the speed at which degradation first
 # occurred (ceiling=0 = never degraded). Read directly from the state
 # files -- the day instrument stays model-free.
 local dir="${FAILFIRST_STATE_DIR:-/tmp/hngh-failfirst}" f op out="" speed name
 local oks deg fail ceiling k v
 for f in "$dir"/failfirst-*; do
  [ -f "$f" ] || continue
  op="${f##*/failfirst-}"
  speed=1 oks=0 deg=0 fail=0 ceiling=0
  while IFS='=' read -r k v; do
   case "$k" in
   speed) speed="$v" ;;
   n_ok) oks="$v" ;;
   n_deg) deg="$v" ;;
   n_fail) fail="$v" ;;
   ceiling) ceiling="$v" ;;
   esac
  done <"$f"
  case "$speed" in 2) name=standard ;; 3) name=cautious ;; *) name=full ;; esac
  out="$out $op=$name(ok=$oks,degraded=$deg,failed=$fail,ceiling=$ceiling);"
 done
 [ -n "$out" ] &&
  printf 'failfirst tuning (ceiling = speed at first degradation):%s' "$out"
}
ff="$(failfirst_summary)"

cutoff="$(date -u -d '24 hours ago' +%Y-%m-%dT%H:00:00Z 2>/dev/null)" || cutoff=""
if [ -z "$cutoff" ] || [ ! -r "$DB" ]; then
 file_report progress "model-saturation $day: no data yet${ff:+; $ff}" "$ident"
 exit 0
fi

# est: typical per-call wall in seconds, for hours whose model events
# carry no wall-s. Measured mean of research-call walls in the window;
# MODEL_TIMEOUT (300s) as the unmeasured ceiling.
est="$(sqlite3 "$DB" \
 "select cast(avg(wall_s) as int) from events
   where kind='research' and wall_s is not null and ts >= '$cutoff'" 2>/dev/null)"
est="${est:-300}"
case "$est" in '' | *[!0-9]* | 0) est=300 ;; esac

# per UTC hour: "<hour>|<wall_sum>|<calls>"
rows="$(sqlite3 -separator '|' "$DB" \
 "select substr(ts,1,13), coalesce(sum(wall_s),0), count(*)
    from events where kind='model' and ts >= '$cutoff'
    group by substr(ts,1,13) order by 1" 2>/dev/null)"
if [ -z "$rows" ]; then
 file_report progress "model-saturation $day: no data yet${ff:+; $ff}" "$ident"
 exit 0
fi

summary="$(printf '%s\n' "$rows" | awk -F'|' -v est="$est" '
 { wall = $2 + 0; calls = $3 + 0
   busy = (wall > 0) ? wall : calls * est
   if (wall > 0) measured = 1
   s[$1] += busy; total += busy }
 END {
   peak = ""; peakv = -1
   for (h in s) if (s[h] > peakv) { peakv = s[h]; peak = h }
   printf "%s %.1f %.1f %d %d %d\n", peak, peakv / 36.0, total / 36.0,
     peakv, total, measured + 0
 }')"
read -r peak peak_pct total_pct peak_s total_s measured <<<"$summary"
basis="calls x ${est}s estimate (model events carry no wall-s)"
[ "$measured" = "1" ] && basis="measured wall-s"
if awk -v p="$peak_pct" 'BEGIN{exit !(p > 80)}'; then
 verdict="saturated (>80%) - acceleration has hit the model-server ceiling"
elif awk -v p="$peak_pct" 'BEGIN{exit !(p >= 50)}'; then
 verdict="approaching saturation (50-80%)"
else
 verdict="headroom ok (<50%)"
fi
file_report progress \
 "model-saturation $day (24h, desktop unsloth; deck leg is overflow-only, not counted): peak hour $peak UTC at $peak_pct% utilization, daily total $total_pct% ($total_s s busy; basis: $basis) - $verdict${ff:+; $ff}" \
 "$ident"
exit 0
