#!/usr/bin/env bash
# test-cadence-collapse.sh — firing-equivalence pin for the cadence tier
# collapse (B3 of the 2026-09-24 unresolved-matters pass): 8 timers
# (1m/5m/10m/30m/hour/day/week/month) -> 3 (subhour/hour/calendar).
#
# Pure bash. For every mounted drop-in it simulates minutes 0..1439 of a
# UTC day under (a) the OLD per-tier OnCalendar specs
#   1m `*:*:00` 5m `*:0/5:00` 10m `*:0/10:00` 30m `*:00/30:00`
#   hour `*:00:10` day `05:00:00` week `Mon 06:00:00` month `01 06:00:00`
# and (b) the NEW 3-unit firing set + the stamp gates + the calendar
# subdir pick, asserting identical firing minutes per job. The calendar
# pick is asserted through the real cadence-tick seam
# (CADENCE_PICK_ECHO=1): 2026-09-24 (Thu) -> daily only; 2026-09-28 (Mon)
# -> daily+weekly; 2026-10-01 (the 1st) -> daily+monthly; 2026-06-01 (a
# Monday the 1st) -> daily+weekly+monthly.
# usage: bash automation/tests/test-cadence-collapse.sh
set -u

AUTOMATION="$(cd "$(dirname "$0")/.." && pwd)"
TICK="$AUTOMATION/jobs/cadence-tick.sh"
CAD="$AUTOMATION/cadence"
fails=0
ok() { echo "ok: $*"; }
bad() {
  echo "FAIL: $*"
  fails=$((fails + 1))
}
ck() { # label expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (want '$2' got '$3')"; fi
}

# ---- historical mapping: job -> its OLD tier (pre-collapse record) ----
declare -A OLD_TIER
set_old() {
  local t=$1 j
  shift
  for j in "$@"; do OLD_TIER[$j]=$t; done
}
set_old 1m 05-operator-items 10-sessions-feed 15-crumbs-sync
set_old 5m 00-time-ledger 01-oversight 01-system 02-agent-supervision
set_old 10m 01-evolve-ui
set_old 30m 05-readout 10-system-feed 15-schedule-feed 20-config-backup \
  25-research-feed 35-plan-feed 45-agent-respawn 46-beat-watchdog \
  50-research-overflow 54-feedback-ingest 55-feedback-apply \
  56-imap-poll 58-patrol 59-unsloth-observe
set_old hour 00-dashboard-self-review 05-ui-audit 10-router-feed 16-remote-push \
  20-workbeat 25-bead-beat 25-session-cost 30-kernel-ledger-sync \
  31-heartbeat 32-deck-facts 33-research-beat 40-gdelt-news \
  41-newspaper-edition
set_old day 01-activity-tick 01-lesson-harvest 02-ledger-prune 03-gate-check \
  04-review-prep 06-remote-posture 06-review-disposition \
  07-budget-digest 08-doc-suite-check 09-email-digest 10-bench-fresh \
  11-service-recovery 13-email-qa 14-plan-ledger-sync 15-resume-pass \
  16-curator-beat 17-torch-audit 18-mimic-drill 19-ux-review \
  20-model-saturation 21-context-ratio 22-ttsr-fit 23-bctx-canary \
  25-wiki-health 26-publication-review 27-patrol 50-hygiene
set_old week 01-roadmap-review 02-bench-trigger
set_old month 01-zoom-out

# ---- unit specs (the NEW firing set is modeled from these) ----
count_lines() { grep -c "$1" "$2"; }
sub_t="$AUTOMATION/systemd/hngh-cadence-subhour.timer"
hour_t="$AUTOMATION/systemd/hngh-cadence-hour.timer"
cal_t="$AUTOMATION/systemd/hngh-cadence-calendar.timer"
ck "subhour timer fires every minute" "1" \
  "$(grep -c '^OnCalendar=\*:\*:00$' "$sub_t")"
ck "subhour timer has one OnCalendar" "1" "$(count_lines '^OnCalendar=' "$sub_t")"
ck "hour timer offset unchanged" "1" \
  "$(grep -c '^OnCalendar=\*-\*-\* \*:00:10$' "$hour_t")"
ck "hour timer has one OnCalendar" "1" "$(count_lines '^OnCalendar=' "$hour_t")"
ck "calendar timer daily 05:00" "1" \
  "$(grep -c '^OnCalendar=\*-\*-\* 05:00:00$' "$cal_t")"
ck "calendar timer weekly Mon 06:00" "1" \
  "$(grep -c '^OnCalendar=Mon \*-\*-\* 06:00:00$' "$cal_t")"
ck "calendar timer monthly 01 06:00" "1" \
  "$(grep -c '^OnCalendar=\*-\*-01 06:00:00$' "$cal_t")"
ck "calendar timer has three OnCalendar" "3" "$(count_lines '^OnCalendar=' "$cal_t")"
ck "subhour service tier" "1" \
  "$(grep -c '^Environment=TIER=subhour$' "$AUTOMATION/systemd/hngh-cadence-subhour.service")"
ck "calendar service tier" "1" \
  "$(grep -c '^Environment=TIER=calendar$' "$AUTOMATION/systemd/hngh-cadence-calendar.service")"
for old in 1m 5m 10m 30m day week month; do
  for ext in timer service; do
    if [ -e "$AUTOMATION/systemd/hngh-cadence-$old.$ext" ]; then
      bad "obsolete unit still present: hngh-cadence-$old.$ext"
    fi
  done
done
ok "obsolete 1m/5m/10m/30m/day/week/month units removed"

# ---- tree vs historical table: every job accounted for exactly once ----
declare -A JOB_PATH
for d in subhour hour calendar/daily calendar/weekly calendar/monthly; do
  for f in "$CAD/$d"/*.sh; do
    [ -e "$f" ] || continue
    name="$(basename "$f" .sh)"
    if [ -n "${JOB_PATH[$name]:-}" ]; then
      bad "job mounted twice: $name"
    fi
    JOB_PATH[$name]="$f"
  done
done
for j in "${!JOB_PATH[@]}"; do
  [ -n "${OLD_TIER[$j]:-}" ] || bad "mounted job not in the old table: $j"
done
for j in "${!OLD_TIER[@]}"; do
  [ -n "${JOB_PATH[$j]:-}" ] || bad "old-table job not mounted: $j"
done
ck "mounted drop-ins match the old table" "${#OLD_TIER[@]}" "${#JOB_PATH[@]}"

# ---- new-side kind per job: location + stamp-gate window ----
declare -A KIND
for j in "${!JOB_PATH[@]}"; do
  f="${JOB_PATH[$j]}"
  case "$f" in
  */subhour/*)
    win="$(sed -n 's/.*now - last)) -ge \([0-9][0-9]*\).*/\1/p' "$f" | head -n1)"
    case "$win" in
    "") KIND[$j]=ungated ;;
    300 | 600 | 1800) KIND[$j]="g$win" ;;
    *) bad "$j: stamp gate window '$win' is not 300/600/1800" ;;
    esac
    ;;
  */hour/*) KIND[$j]=hour ;;
  */calendar/daily/*) KIND[$j]=daily ;;
  */calendar/weekly/*) KIND[$j]=weekly ;;
  */calendar/monthly/*) KIND[$j]=monthly ;;
  esac
done

# ---- calendar pick through the real seam (date shim + CADENCE_PICK_ECHO) ----
SHIM="$(mktemp -d)"
trap 'rm -rf "$SHIM"' EXIT
printf '#!/bin/sh\nprintf "%%s\\n" "$FAKE_TRIPLE"\n' >"$SHIM/date"
chmod +x "$SHIM/date"
pick_for() { # hh dow dom -> sorted subdir names, space-joined
  FAKE_TRIPLE="$1 $2 $3" PATH="$SHIM:$PATH" CADENCE_PICK_ECHO=1 bash "$TICK" |
    sort | tr '\n' ' ' | sed 's/ $//'
}
in_pick() { # picklist name
  case " $1 " in
  *" $2 "*) return 0 ;;
  esac
  return 1
}

ck "pick Thu non-1st 05:00" "daily" "$(pick_for 05 4 24)"
ck "pick Thu non-1st 06:00 (no firing)" "" "$(pick_for 06 4 24)"
ck "pick Mon 06:00" "weekly" "$(pick_for 06 1 28)"
ck "pick 1st 06:00" "monthly" "$(pick_for 06 4 01)"
ck "pick Monday 1st 06:00" "monthly weekly" "$(pick_for 06 1 01)"
ck "pick non-firing hour runs nothing" "" "$(pick_for 14 4 24)"

# ---- firing simulation 0..1439: old expansions vs new set per job ----
old_minutes() { # tier dow dom -> minute list
  local t=$1 dow=$2 dom=$3 m out="" hit
  for ((m = 0; m < 1440; m++)); do
    hit=0
    case "$t" in
    1m) hit=1 ;;
    5m) ((m % 5 == 0)) && hit=1 ;;
    10m) ((m % 10 == 0)) && hit=1 ;;
    30m) ((m % 30 == 0)) && hit=1 ;;
    hour) ((m % 60 == 0)) && hit=1 ;;
    day) ((m == 300)) && hit=1 ;;
    week) [ "$dow" = 1 ] && [ "$m" = 360 ] && hit=1 ;;
    month) [ "$dom" = 01 ] && [ "$m" = 360 ] && hit=1 ;;
    esac
    [ "$hit" = 1 ] && out="$out $m"
  done
  printf '%s' "$out"
}

gate_minutes() { # window seconds -> minute list (stamp gate, fresh at day start)
  local win=$1 m last=-100000 out=""
  for ((m = 0; m < 1440; m++)); do
    if (((m - last) * 60 >= win)); then
      out="$out $m"
      last=$m
    fi
  done
  printf '%s' "$out"
}

new_minutes() { # kind dow dom -> minute list
  local kind=$1 dow=$2 dom=$3 out=""
  case "$kind" in
  ungated) gate_minutes 0 ;;
  g300) gate_minutes 300 ;;
  g600) gate_minutes 600 ;;
  g1800) gate_minutes 1800 ;;
  hour) old_minutes hour "$dow" "$dom" ;;
  daily)
    in_pick "$(pick_for 05 "$dow" "$dom")" daily && out=" 300"
    ;;
  weekly)
    in_pick "$(pick_for 06 "$dow" "$dom")" weekly && out=" 360"
    ;;
  monthly)
    in_pick "$(pick_for 06 "$dow" "$dom")" monthly && out=" 360"
    ;;
  esac
  printf '%s' "$out"
}

old_get() { # tier -> cached minute list
  case "$1" in
  1m) printf '%s' "$old_1m" ;;
  5m) printf '%s' "$old_5m" ;;
  10m) printf '%s' "$old_10m" ;;
  30m) printf '%s' "$old_30m" ;;
  hour) printf '%s' "$old_hour" ;;
  day) printf '%s' "$old_day" ;;
  week) printf '%s' "$old_week" ;;
  month) printf '%s' "$old_month" ;;
  esac
}
new_get() { # kind -> cached minute list
  case "$1" in
  ungated) printf '%s' "$new_ungated" ;;
  g300) printf '%s' "$new_g300" ;;
  g600) printf '%s' "$new_g600" ;;
  g1800) printf '%s' "$new_g1800" ;;
  hour) printf '%s' "$new_hour" ;;
  daily) printf '%s' "$new_daily" ;;
  weekly) printf '%s' "$new_weekly" ;;
  monthly) printf '%s' "$new_monthly" ;;
  esac
}

for fx in "2026-09-24 4 24 daily" "2026-09-28 1 28 daily weekly" \
  "2026-10-01 4 01 daily monthly" "2026-06-01 1 01 daily monthly weekly"; do
  set -- $fx
  date=$1 dow=$2 dom=$3
  shift 3
  want="$*"
  ck "fixture $date dow" "$dow" "$(date -u -d "$date" +%u)"
  ck "fixture $date dom" "$dom" "$(date -u -d "$date" +%d)"
  union="$(pick_for 05 "$dow" "$dom") $(pick_for 06 "$dow" "$dom")"
  union="$(printf '%s\n' $union | sort -u | tr '\n' ' ' | sed 's/ $//')"
  ck "calendar picks $date ($want)" "$want" "$union"
  for t in 1m 5m 10m 30m hour day week month; do
    eval "old_$t=\"\$(old_minutes $t $dow $dom)\""
  done
  for k in ungated g300 g600 g1800 hour daily weekly monthly; do
    eval "new_$k=\"\$(new_minutes $k $dow $dom)\""
  done
  mism=0
  for j in "${!JOB_PATH[@]}"; do
    if [ "$(old_get "${OLD_TIER[$j]}")" != "$(new_get "${KIND[$j]:-BADWIN}")" ]; then
      bad "firing minutes differ: $j (old tier ${OLD_TIER[$j]}, new ${KIND[$j]:-BADWIN}, $date)"
      mism=$((mism + 1))
    fi
  done
  [ "$mism" = 0 ] &&
    ok "firing minutes identical for all ${#JOB_PATH[@]} jobs ($date)"
done

echo
if [ "$fails" = 0 ]; then
  echo "PASS: test-cadence-collapse (8 timers -> 3, firing-equivalent)"
  exit 0
fi
echo "FAIL: $fails check(s) red"
exit 1
