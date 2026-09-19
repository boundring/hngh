#!/usr/bin/env bash
# morning-digest — runs at 06/07/08/09: fresh fetch + cumulative digest of
# everything since 00:00 today, model writes 3-tier summary, updates dashboard.
# Fail-closed: always exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/sources.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
. "$AUTOMATION_ROOT/lib/hngh-record.sh"
. "$AUTOMATION_ROOT/lib/news-screen.sh"

DATE="$(date +%F)"
TS="$(date +%H%M)"
MORNING_FILE="$DIGEST_DIR/MORNING-$DATE.md"

# --- 0. Jev triage fan-out (hngh-1de): one call, hottest lane + heat +
# collapse Noul over live city-state. Fail-open: without key or on any
# error the digest proceeds untriaged; verdicts land as a header block.
TRIAGE_BLOCK=""
if _city_json="$(python3 "$AUTOMATION_ROOT/jobs/city-state.py" 2>/dev/null)"; then
 _beats_state="$(printf '%s' "$_city_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print('beats ' + d['timers']['beats'])" 2>/dev/null)"
 _beads_state="$(printf '%s' "$_city_json" | python3 -c "import json,sys; d=json.load(sys.stdin); print(str(d['beads']['closed']) + ' closed ' + str(d['beads']['open']) + ' open')" 2>/dev/null)"
 if _triage="$(TYPESAFE_BEATS="$_beats_state" TYPESAFE_BEADS="$_beads_state" python3 -c "
import os, sys
sys.path.insert(0, os.path.join('$AUTOMATION_ROOT', 'lib'))
from typesafe import ask_choice, ask_noul
st = {'beats': os.environ.get('TYPESAFE_BEATS', '?'), 'beads': os.environ.get('TYPESAFE_BEADS', '?')}
hot = ask_choice(st, 'hottest', 'Which work lane most needs attention next?', ['reviewer-gates', 'acp-probes', 'contexts-redesign', 'tiger-specs', 'triage-wiring', 'roles'])
col = ask_noul(st, 'collapse_ready', 'Is there absorbable completed work that should collapse now?')
print(('hottest=' + str(hot)) if hot else 'hottest=?', ('collapse=' + str(col)) if col is not None else 'collapse=?')
" 2>/dev/null)"; then
  TRIAGE_BLOCK="_Jev triage (one call): $_triage _"
  breadcrumb "$JOB_NAME" "triage" "jev fan-out: $_triage"
 fi
fi

# --- 1. fresh fetch (also lands in today's snapshots) ---
body="$(fetch_sources)"
breadcrumb "$JOB_NAME" "fetch" "morning sources fetched"

# --- 2. cumulative corpus: newest snapshot per source taken today ---
names="$(printf '%s\n' "$SOURCES" | cut -d: -f1 | tr '\n' ' ' | sed 's/ $//')"
# pre-ingest screening (lib/news-screen.sh): quarantined snapshots never
# reach the morning prompt — same rule and alert rows as ping-hourly.
names="$(screen_day_names "$DATE" $names)"
n="$(printf '%s\n' "$names" | grep -c . || true)"
if [ "${n:-0}" -le 0 ] 2>/dev/null; then
  breadcrumb "$JOB_NAME" "morning" "no sources configured; nothing to summarize"
  update_dashboard "$JOB_NAME" "$DATE" "$TS"
  exit 0
fi

prompt="$(build_prompt "$DATE" "$names" "$MAX_MORNING_WORDS" "morning")"
# digest model leg rides the same quota-ladder lane as the fresh-eyes
# review (stall-recovery step 10): deck -> kimi -> zai -> ocgo, the local
# bench LAST resort; unarmed legs skip fail-closed.
MODEL_PIN="${MODEL_PIN:-review}"
summary="$(printf '%s' "$prompt" | model_call "$MODEL_MAX_TOKENS")"
summary="$(printf '%s' "$summary" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
used="$(last_model_used)"

if [ -n "$summary" ]; then
  {
    printf '# Morning digest %s\n' "$DATE"
    printf '_compiled %s | model: %s_\n' "$TS" "$used"
    [ -n "$TRIAGE_BLOCK" ] && printf '\n%s\n' "$TRIAGE_BLOCK"
    printf '\n%s\n' "$summary"
  } >"$MORNING_FILE"
  breadcrumb "$JOB_NAME" "morning" "MORNING-$DATE.md written via $used"
else
  breadcrumb "$JOB_NAME" "morning" "no model output; MORNING-$DATE.md not updated"
fi

# --- 3. dashboard + dogfood ---
update_dashboard "$JOB_NAME" "$DATE" "$TS"
record_hngh_run "morning digest $DATE $TS"
# --- 4. best-effort daily write-ups (kernel generators; never fatal) ---
if [ -x "$AUTOMATION_ROOT/jobs/daily-writeups.sh" ]; then
  "$AUTOMATION_ROOT/jobs/daily-writeups.sh" ||
    breadcrumb "$JOB_NAME" "writeups" "daily-writeups exited nonzero (data)"
fi
exit 0
