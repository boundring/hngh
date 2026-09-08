# news-importance.sh — interest screen for the news pipeline.
# The operator's interest screen lives in ONE place: edit the list, not the
# logic. <=12 concrete alternates, matched case-insensitively over the raw
# text of the NEW snapshots. "outage" is scoped to the tracked service set
# by SOURCES in config.env; CVE-[0-9] covers CVE id mentions.
NEWS_IMPORTANCE_PATTERNS='actively exploited|CVE-[0-9]|\bRCE\b|zero-day|taken down|breach|outage|hngh|boundring|supply chain|sanction'

# Escalation bookkeeping, same ephemeral-stamp pattern as
# cadence/hour/31-heartbeat.sh: worst case after a reboot is one extra
# summarization.
NEWS_ESCALATE_STAMP="${NEWS_ESCALATE_STAMP:-/tmp/.hngh-news-escalate-last}"
NEWS_ESCALATE_DAY="${NEWS_ESCALATE_DAY:-/tmp/.hngh-news-escalate-day}"

screen_importance() { # snapshot-dir-or-files... -> prints ESCALATE or empty
  local target f
  for target in "$@"; do
    [ -e "$target" ] || continue
    if [ -d "$target" ]; then
      for f in "$target"/*.json; do
        [ -e "$f" ] || continue
        grep -q -i -E "$NEWS_IMPORTANCE_PATTERNS" "$f" 2>/dev/null && {
          printf 'ESCALATE\n'
          return 0
        }
      done
    else
      grep -q -i -E "$NEWS_IMPORTANCE_PATTERNS" "$target" 2>/dev/null && {
        printf 'ESCALATE\n'
        return 0
      }
    fi
  done
  return 0
}

# first_run_of_day -> rc 0 when no escalation has run yet this UTC day, so
# the morning block is never gated stale by the digest window.
first_run_of_day() {
  [ "$(cat "$NEWS_ESCALATE_DAY" 2>/dev/null)" != "$(date -u +%F)" ]
}

# escalate_rate_limited -> rc 0 when an escalation ran less than an hour ago
# (at most one escalation summarization per hour).
escalate_rate_limited() {
  local now last
  now="$(date +%s)"
  last="$(cat "$NEWS_ESCALATE_STAMP" 2>/dev/null || printf 0)"
  last="${last//[!0-9]/}"
  last="${last:-0}"
  [ $((now - last)) -lt 3600 ]
}
