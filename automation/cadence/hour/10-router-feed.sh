#!/usr/bin/env bash
# cadence/hour — router feed: the first production caller of
# scripts/router-tick.py (2026-09-01-overnight-continuity step 2).
# Reads UNREAD alert rows (report-queue --json; reading never advances the
# cursor), picks distinct routable identities newest-first up to
# ROUTER_FEED_MAX (default 3), and invokes the tick once per identity with
# the alert's first line as text. Excluded from the feed by design:
#   - operator-owned/critical classes (they only park inside the tick as
#     noise): identities matching provider|credential|token|systemd|
#     security|secret|delet|remote-posture|budget (case-insensitive);
#   - router:* (the tick's own output rows — self-feedback loop);
#   - overnight:critical-touch:* (operator-attention class);
#   - identities failing the routable charset ^[A-Za-z0-9._:-]+$
#     (they bounce as no-candidate noise).
# ROUTER_FEED_ONLY (optional regex) scopes a run to matching identities
# only (operator/demo scoping).
# Feed-once cursor (2026-09-27): state/router-fed.tsv records
# identity<TAB>fed-epoch for every identity actually ticked; an identity
# fed inside ROUTER_FED_WINDOW (default 86400s) is skipped until the
# window expires — the hourly tier converts a stale backlog once, then
# stands down. ROUTER_FEED_FORCE=1 bypasses the gate (operator/demo).
# Rows older than 7d are pruned best-effort. The report-queue cursor
# itself stays operator-owned; this ledger is router-private state.
# Hourly tier: alert sources are >=5m and every routing output dedupes on
# 86400s windows, so hourly converts the backlog gradually while re-feeds
# of still-unread rows stay cheap (window-deduped, occurrence-idempotent).
# No own flock: jobs/cadence-tick.sh already serializes the tier with its
# per-tier flock and this is the only invocation point. Fail closed: every
# path exits 0; all-clear ticks are silent (fed-only breadcrumb).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
RQ="${HNGH_REPORT_QUEUE:-$KERNEL/scripts/report-queue}"
export HNGH_REPORT_ROOT="${HNGH_REPORT_ROOT:-$KERNEL}"
# shellcheck disable=SC1091
. "$ROOT/lib/breadcrumbs.sh" 2>/dev/null || true
MAX="${ROUTER_FEED_MAX:-3}"
case "$MAX" in '' | *[!0-9]*) MAX=3 ;; esac
FED_STATE="${ROUTER_FED_STATE:-$ROOT/state/router-fed.tsv}"
FED_WINDOW="${ROUTER_FED_WINDOW:-86400}"
case "$FED_WINDOW" in '' | *[!0-9]*) FED_WINDOW=86400 ;; esac
FORCE="${ROUTER_FEED_FORCE:-0}"

tmp="$(mktemp 2>/dev/null)" || exit 0
"$RQ" --json >"$tmp" 2>/dev/null || {
 rm -f "$tmp"
 exit 0
}
feed="$(
 python3 - "$tmp" <<'PY'
import json, os, re, sys
try:
    with open(sys.argv[1]) as fh:
        rows = json.load(fh).get("reports", [])
except Exception:
    sys.exit(0)
charset = re.compile(r"^[A-Za-z0-9._:-]+$")
critical = re.compile(r"provider|credential|token|systemd|security|secret|"
                      r"delet|remote-posture|budget", re.I)
only = os.environ.get("ROUTER_FEED_ONLY") or None
seen = set()
for r in rows:  # newest-first
    if r.get("kind") != "alert":
        continue
    m = re.search(r"\*\*identity:\*\* (.+)", r.get("body") or "")
    if not m:
        continue
    ident = m.group(1).strip()
    if ident in seen:
        continue
    if only and not re.search(only, ident):
        continue
    if ident.startswith(("router:", "overnight:critical-touch",
                         "class-upgrade:")):
        continue
    # durable class channel (2026-09-22-router-alert-class-channel):
    # an operator-critical row never routes into auto-shaped candidates;
    # belt: identity-free word scan on the first line too
    first = (r.get("first") or "").replace("\t", " ")
    if critical.search(first):
        continue
    if re.search(r"\*\*class:\*\* critical", r.get("body") or ""):
        continue
    if critical.search(ident) or not charset.match(ident):
        continue
    seen.add(ident)
    print("%s\t%s" % (ident, first))
PY
)" && rm -f "$tmp" || {
 rm -f "$tmp"
 exit 0
}

n=0
now=$(date +%s)
while IFS=$'\t' read -r ident first; do
 [ -n "$ident" ] || continue
 [ "$n" -lt "$MAX" ] || break
 if [ "$FORCE" != "1" ] && [ -f "$FED_STATE" ]; then
  last=$(awk -F'\t' -v id="$ident" '$1 == id {print $2; exit}' \
   "$FED_STATE" 2>/dev/null)
  case "$last" in '' | *[!0-9]*) last=0 ;; esac
  [ $((now - last)) -lt "$FED_WINDOW" ] && continue
 fi
 python3 "$ROOT/scripts/router-tick.py" --identity "$ident" \
  --text "$first" >/dev/null 2>&1 || true
 printf '%s\t%s\n' "$ident" "$now" >>"$FED_STATE" 2>/dev/null || true
 n=$((n + 1))
done <<<"$feed"
if [ -f "$FED_STATE" ]; then
 # prune >7d rows and collapse re-feeds to the LATEST entry per
 # identity (the in-loop gate must see the most recent feed, not the
 # oldest history row)
 awk -F'\t' -v now="$now" \
  '$2 ~ /^[0-9]+$/ && $2 + 0 >= now - 604800 {last[$1] = $2}
     END {for (id in last) print id "\t" last[id]}' \
  "$FED_STATE" >"$FED_STATE.tmp" 2>/dev/null &&
  mv "$FED_STATE.tmp" "$FED_STATE" 2>/dev/null || rm -f "$FED_STATE.tmp"
fi
if [ "$n" -gt 0 ]; then
 breadcrumb "router-feed" "fed" \
  "$n identity(ies): $(printf '%s\n' "$feed" | cut -f1 | head -n "$n" | tr '\n' ' ')"
fi
exit 0
