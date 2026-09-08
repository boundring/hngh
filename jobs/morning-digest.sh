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
MORNING_FILE="$AUTOMATION_ROOT/digest/MORNING-$DATE.md"

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
summary="$(printf '%s' "$prompt" | model_call "$MODEL_MAX_TOKENS")"
summary="$(printf '%s' "$summary" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
used="$(last_model_used)"

if [ -n "$summary" ]; then
  {
    printf '# Morning digest %s\n' "$DATE"
    printf '_compiled %s | model: %s_\n' "$TS" "$used"
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
