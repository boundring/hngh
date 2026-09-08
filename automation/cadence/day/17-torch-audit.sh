#!/usr/bin/env bash
# 02-torch-audit — week-tier Audit station (Descent station 6): the
# consumption audit + STATE-OF-PROJECT numbers refresh.
#
# For every torch-ledger.tsv row, re-verify the reader claim cheaply and
# deterministically (no model): grep -rlE the reader pattern over the
# automation scripts/jobs/cadence/lib/tests trees plus the kernel
# scripts tree, subtract the row's writer files, and count the
# remaining non-writer consumers. Verdicts: live (consumer found),
# write-only (none — the artifact-consumer invariant says wire or
# delete), unknown (pattern or writer path went stale — the ledger row
# is flagged for human curation, never guessed).
#
# Output: logs/torch-<date>.md (class table + verdicts + delta vs
# expected) and report-queue rows: one alert per class whose actual
# verdict is write-only but expected live ("wire or delete"), one alert
# per unknown row, one deduped progress row when every verdict matches.
# The script then regenerates ONLY the sentinel-bounded "Verified
# numbers" block in the kernel's docs/project/STATE-OF-PROJECT.md from
# live ledgers and commits that one file (skip when clean, refuse when
# staged work exists, never push).
#
# Fail-closed: exits 0 on every path.
#
# usage: cadence/day/17-torch-audit.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
LEDGER="$AUTOMATION_ROOT/torch-ledger.tsv"
STATE_PROJECT="$KERNEL/docs/project/STATE-OF-PROJECT.md"
day="${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"
LOG="$AUTOMATION_ROOT/logs/torch-$day.md"

file_report() {
 local kind="$1" text="$2" ident="$3"
 if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
  --identity "$ident" --window 604800 >/dev/null 2>&1; then
  breadcrumb "$JOB_NAME" "$kind" "$ident"
 else
  breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $ident"
 fi
}

[ -f "$LEDGER" ] || {
 breadcrumb "$JOB_NAME" "no-ledger" "torch-ledger.tsv missing"
 exit 0
}

# search set: every place a consumer could plausibly live
SEARCH_DIRS=("$AUTOMATION_ROOT/scripts" "$AUTOMATION_ROOT/jobs"
 "$AUTOMATION_ROOT/cadence" "$AUTOMATION_ROOT/lib"
 "$AUTOMATION_ROOT/tests" "$KERNEL/scripts")

# consumers PATTERN WRITERS -> "<count> <writer-seen>"; count = files
# referencing the pattern minus the row's writer files; writer-seen = 1
# when at least one writer file still matches (else 0).
consumers() {
 local pattern="$1" writers="$2" hits f base seen=0 n=0
 hits="$(grep -rlE --include='*.sh' --include='*.py' --include='*.mjs' \
  -- "$pattern" "${SEARCH_DIRS[@]}" 2>/dev/null || true)"
 [ -n "$hits" ] || {
  printf '0 0\n'
  return 0
 }
 while IFS= read -r f; do
  base="$(basename "$f")"
  if printf '%s\n' "$writers" | tr ',' '\n' | grep -qxF "$base"; then
   seen=1
  else
   n=$((n + 1))
  fi
 done <<<"$hits"
 printf '%d %d\n' "$n" "$seen"
}

mkdir -p "$AUTOMATION_ROOT/logs"
table="$AUTOMATION_ROOT/logs/.torch-table-$day.tmp"
: >"$table"
live_n=0 write_only_n=0 unknown_n=0 delta=0

while IFS=$'\t' read -r class pattern writers expected note; do
 case "$class" in "" | \#* | artifact-class) continue ;; esac
 read -r n writer_seen <<<"$(consumers "$pattern" "$writers")"
 actual="live"
 if [ "$n" -eq 0 ]; then
  # a healthy write-only class still has its writer matching the
  # pattern; if not, the pattern or writer path went stale
  if [ "$writer_seen" -eq 0 ]; then
   actual="unknown"
   file_report "alert" "torch audit: ledger row $class needs human curation (reader pattern or writer path stale — zero hits)" \
    "torch:unknown:$class"
   unknown_n=$((unknown_n + 1))
  else
   actual="write-only"
   write_only_n=$((write_only_n + 1))
  fi
 else
  live_n=$((live_n + 1))
 fi
 if [ "$actual" != "$expected" ]; then
  delta=$((delta + 1))
  if [ "$actual" = "write-only" ]; then
   file_report "alert" "wire or delete: $class — zero non-writer consumers" \
    "torch:write-only:$class"
  fi
 fi
 printf '| %s | %d | %s | %s | %s |\n' \
  "$class" "$n" "$expected" "$actual" "$note" >>"$table"
done <"$LEDGER"

total=$((live_n + write_only_n + unknown_n))
{
 printf '# Torch audit %s\n\n' "$day"
 printf 'Artifact-consumer invariant re-verification (Descent station 6).\n'
 printf 'Consumer = a non-writer file in automation scripts/jobs/cadence/lib/tests\n'
 printf 'or kernel scripts matching the ledger reader pattern.\n\n'
 printf '| class | consumers | expected | actual | note |\n'
 printf '|---|---|---|---|---|\n'
 cat "$table"
 printf '\nVerdicts: %d live, %d write-only, %d unknown of %d classes; %d row(s) diverge from the ledger.\n' \
  "$live_n" "$write_only_n" "$unknown_n" "$total" "$delta"
} >"$LOG"
rm -f "$table"

if [ "$delta" -eq 0 ] && [ "$unknown_n" -eq 0 ]; then
 file_report "progress" \
  "torch audit: $total artifact classes re-verified, all verdicts match the ledger" \
  "torch:audit-ok"
fi
breadcrumb "$JOB_NAME" "torch-audit" \
 "live=$live_n write-only=$write_only_n unknown=$unknown_n delta=$delta"

# --- STATE-OF-PROJECT: regenerate ONLY the sentinel-bounded block ------
BLOCK="$(mktemp)"
SPLICED="$(mktemp)"
{
 printf 'Regenerated weekly from live ledgers by\n'
 printf 'hngh-automation `cadence/day/17-torch-audit.sh` — do not hand-edit\n'
 printf 'inside the sentinels.\n\n'
 # research line states
 lines="research-lines.tsv unreadable"
 [ -f "$AUTOMATION_ROOT/research-lines.tsv" ] &&
  lines="$(awk -F'\t' '{c[$2]++} END{s=""; for (k in c) s=s (s?", ":"") c[k]" "k; print s}' \
   "$AUTOMATION_ROOT/research-lines.tsv")"
 printf -- '- Research lines: %s (hngh-automation/research-lines.tsv).\n' "${lines:-(none seeded)}"
 # queue Next age
 qnext="$(sed -n '/^## Next/,/^## /p' "$KERNEL/docs/project/queue.md" 2>/dev/null |
  grep -m1 -oE '\*\*[^*]+\*\*' | tr -d '*')"
 qdate="$(sed -n '/^## Next/,/^## /p' "$KERNEL/docs/project/queue.md" 2>/dev/null |
  grep -m1 -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}')"
 if [ -n "$qnext" ] && [ -n "$qdate" ]; then
  qage=$((($(date -u +%s) - $(date -u -d "$qdate" +%s 2>/dev/null || echo 0)) / 86400))
  printf -- '- Queue Next: %s, set %s (%d days old) (hngh docs/project/queue.md).\n' \
   "$qnext" "$qdate" "$qage"
 else
  printf -- '- Queue Next: empty or unparsable (hngh docs/project/queue.md).\n'
 fi
 # plan ledger size
 ptotal="$(ls "$KERNEL/docs/project/plans/" 2>/dev/null | grep -c '\.plan\.md$')"
 prouted="$(ls "$KERNEL/docs/project/plans/" 2>/dev/null | grep -c 'routed.*\.plan\.md$')"
 printf -- '- Plan ledger: %s plan files, %s routed candidates (hngh docs/project/plans/).\n' \
  "${ptotal:-0}" "${prouted:-0}"
 # open operator items
 oopen="$(jq '[.items[] | select(.status == "open")] | length' \
  "$AUTOMATION_ROOT/dashboard/operator-items.json" 2>/dev/null)"
 printf -- '- Operator items: %s open (hngh-automation/dashboard/operator-items.json; display cap 40).\n' \
  "${oopen:-unknown}"
 # last make-test breadcrumb
 gate="$(grep 'make test' "$AUTOMATION_ROOT/STATE.md" 2>/dev/null | tail -1)"
 if [ -n "$gate" ]; then
  printf -- '- Gates: %s (hngh-automation/STATE.md crumb tail).\n' \
   "$(printf '%s' "$gate" | sed 's/^[^|]*| //; s/ | / — /g')"
 else
  printf -- '- Gates: no make-test breadcrumb found (hngh-automation/STATE.md).\n'
 fi
} >"$BLOCK"

if [ ! -f "$STATE_PROJECT" ] || ! grep -q '<!-- torch:begin -->' "$STATE_PROJECT"; then
 breadcrumb "$JOB_NAME" "state-skip" "STATE-OF-PROJECT sentinels missing; numbers not regenerated"
 rm -f "$BLOCK" "$SPLICED"
 exit 0
fi

awk 'NR==FNR { blk = blk $0 "\n"; next }
     /<!-- torch:begin -->/ { print; printf "%s", blk; inh = 1; next }
     inh && /<!-- torch:end -->/ { inh = 0; print; next }
     inh { next }
     { print }' "$BLOCK" "$STATE_PROJECT" >"$SPLICED"

if mv "$SPLICED" "$STATE_PROJECT" 2>/dev/null; then
 breadcrumb "$JOB_NAME" "state-regen" "verified-numbers block regenerated"
 # commit the one file: refuse on staged work, skip when clean, never push
 if git -C "$KERNEL" diff --cached --quiet; then
  git -C "$KERNEL" add -- docs/project/STATE-OF-PROJECT.md
  if git -C "$KERNEL" diff --cached --quiet; then
   breadcrumb "$JOB_NAME" "state-clean" "numbers unchanged; nothing to commit"
  else
   if git -C "$KERNEL" commit -m "automation: torch numbers refresh ($day)" \
    -- docs/project/STATE-OF-PROJECT.md >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "state-commit" "torch numbers refresh committed"
   else
    breadcrumb "$JOB_NAME" "state-commit-fail" "git commit failed; leaving changes uncommitted"
   fi
  fi
 else
  breadcrumb "$JOB_NAME" "state-refused" "kernel repo has staged work; refresh left uncommitted"
 fi
else
 breadcrumb "$JOB_NAME" "state-splice-fail" "sentinel splice failed; STATE-OF-PROJECT left untouched"
fi
rm -f "$BLOCK" "$SPLICED" 2>/dev/null
exit 0
