#!/usr/bin/env bash
# ping-hourly — fetch sources hourly (procedural, free); summarize NEW items
# only on the digest window (news-digest-hours, default 3) or on an
# importance escalation (lib/news-importance.sh), append digest, update
# dashboard, dogfood hngh. Fail-closed: always exits 0.
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/sources.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
. "$AUTOMATION_ROOT/lib/hngh-record.sh"
. "$AUTOMATION_ROOT/lib/news-importance.sh"
. "$AUTOMATION_ROOT/lib/news-screen.sh"
DATE="$(date +%F)"
TS="$(date +%H%M)"
DIGEST="$AUTOMATION_ROOT/digest/$DATE.md"

# --- 1. fetch (never fails) ---
body="$(fetch_sources)"
new_names="$(printf '%s' "$body" | jq -r '.new[]?')"
nnew="$(printf '%s' "$new_names" | grep -c . || true)"
breadcrumb "$JOB_NAME" "fetch" "sources fetched; new=${nnew:-0}"

# --- 1.5 mention watch: hngh/boundring appearing in fetched news ---
mention_hits="$(grep -h -o -i -E '\b(hngh|boundring)\b' \
  "$AUTOMATION_ROOT/snapshots/$DATE"/*.json 2>/dev/null || true)"
if [ -n "$mention_hits" ]; then
  mention_sig="$(printf '%s' "$mention_hits" | sort -u | md5sum | cut -d' ' -f1)"
  if [ "$mention_sig" != "$(cat "$AUTOMATION_ROOT/tmp-mention-sig" 2>/dev/null || true)" ]; then
    mention_files="$(grep -l -i -E '\b(hngh|boundring)\b' \
      "$AUTOMATION_ROOT/snapshots/$DATE"/*.json 2>/dev/null | wc -l || true)"
    printf '%s' "$mention_sig" >"$AUTOMATION_ROOT/tmp-mention-sig"
    breadcrumb "$JOB_NAME" "mention" "hngh/boundring mentioned in ${mention_files:-0} of today's snapshots — check digest"
  fi
fi

# --- 2. summarize new items: 3h digest cadence, importance escalation ---
# The model call is the cost; it runs when new items exist AND either the
# interest screen escalates (immediately, at most one per hour, plus the
# first run of the UTC day so the morning block is never stale) or
# news-digest-hours have passed since the last summarization.
summary=""
reason=""
if [ "$nnew" -gt 0 ] 2>/dev/null; then
  new_files=""
  for n in $new_names; do
    f="$(newest_snapshot "$AUTOMATION_ROOT/snapshots/$DATE" "$n")"
    [ -n "$f" ] && new_files="$new_files $f"
  done
  # pre-ingest screening (lib/news-screen.sh): quarantined snapshots are
  # dropped from the model input list BEFORE the importance screen (quarantine
  # takes precedence) and before build_prompt; files stay on disk (evidence),
  # alert rows are filed inside screen_day_names.
  new_names="$(screen_day_names "$DATE" $new_names)"
  nnew="$(printf '%s' "$new_names" | grep -c . || true)"
  if [ "$nnew" -gt 0 ] 2>/dev/null; then
    hit="$(screen_importance $new_files)"
    now="$(date +%s)"
    digest_hours="${NEWS_DIGEST_HOURS:-$(get_param news-digest-hours 3)}"
    digest_secs=$((digest_hours * 3600))
    digest_stamp="${NEWS_DIGEST_STAMP:-/tmp/.hngh-news-digest-last}"
    last_digest="$(cat "$digest_stamp" 2>/dev/null || printf 0)"
    last_digest="${last_digest//[!0-9]/}"
    last_digest="${last_digest:-0}"
    reason=""
    if { [ -n "$hit" ] || first_run_of_day; } && ! escalate_rate_limited; then
      reason="escalation"
    elif [ $((now - last_digest)) -ge $digest_secs ]; then
      reason="cadence"
    fi
  fi
fi
if [ -n "$reason" ]; then
  prompt="$(build_prompt "$DATE" "$new_names" "$MAX_PING_WORDS" "ping")"
  # dedup: pull CRITICAL/NOTABLE lines from the previous hour block so the
  # model does not restate old items. Last block of today's file (the run
  # before this one); at day rollover fall back to yesterday's file.
  prev_digest="$AUTOMATION_ROOT/digest/$DATE.md"
  [ -s "$prev_digest" ] || prev_digest="$AUTOMATION_ROOT/digest/$(date -d yesterday +%F).md"
  prev_items="$(awk '/^## /{blk=""} {blk=blk $0 "\n"} END{printf "%s", blk}' \
    "$prev_digest" 2>/dev/null | grep -E '^(CRITICAL|NOTABLE):' || true)"
  if [ -n "$prev_items" ]; then
    prompt+="

ALREADY REPORTED:
$prev_items

These items are old; repeat one only if its state changed (new severity,
resolution, escalation, or a material fact added)."
  fi
  # news content is low-stakes — quota legs are reserved for bounded
  # high-value completions. MODEL_PIN support lands in lib/model.sh in a
  # sibling lane tonight and is inert until then.
  export MODEL_PIN="${MODEL_PIN:-local}"
  summary="$(printf '%s' "$prompt" | model_call "$MODEL_MAX_TOKENS")"
  summary="$(printf '%s' "$summary" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  used="$(last_model_used)"
  if [ -n "$summary" ]; then
    {
      printf '\n## %s %s\n' "$TS" "$DATE"
      printf '_sources: %s | model: %s_\n' "$(printf '%s' "$new_names" | tr '\n' ',' | sed 's/,$//')" "$used"
      printf '%s\n' "$summary"
    } >>"$DIGEST"
    # grounded megastructure block: real feeds only, sources cited in
    # HTML comments; best-effort, never breaks the news block.
    python3 "$AUTOMATION_ROOT/jobs/digest-ledger.py" "$DATE" >>"$DIGEST" 2>/dev/null || true
  fi
  printf '%s\n' "$now" >"$digest_stamp" 2>/dev/null || true
  if [ "$reason" = "escalation" ]; then
    printf '%s\n' "$now" >"$NEWS_ESCALATE_STAMP" 2>/dev/null || true
    printf '%s\n' "$(date -u +%F)" >"$NEWS_ESCALATE_DAY" 2>/dev/null || true
  fi
  breadcrumb "$JOB_NAME" "ping" "summarized ${nnew} new items via $used ($reason)"
elif [ "${nnew:-0}" -gt 0 ] 2>/dev/null; then
  h=$(((digest_secs - (now - last_digest) + 3599) / 3600))
  breadcrumb "$JOB_NAME" "ping" "fetch ok; summarization deferred (next window in ${h}h)"
else
  breadcrumb "$JOB_NAME" "ping" "no new items; nothing to summarize"
fi

# --- 3. dashboard + dogfood ---
update_dashboard "$JOB_NAME" "$DATE" "$TS"
record_hngh_run "hourly research ping $DATE $TS"

# --- 4. sweep: commit job artifacts so nothing is left to the operator ---
bash "$AUTOMATION_ROOT/jobs/sweep-artifacts.sh"
exit 0
