#!/usr/bin/env bash
# 04-review-prep — day-tier self-improvement drop-in: fresh-eyes review of
# the last 36h of commits in BOTH repos (hngh + hngh-automation) via the
# sanctioned local model path (model_call; unsloth -> ollama fallback; no
# remote API keys). Writes digest/REVIEW-<date>.md (range + response),
# files a progress row per repo and an alert row per P0/P1 finding.
# Local-model failure files an alert and exits 0 — never hangs the tick.
#
# usage: cadence/day/04-review-prep.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
TELEMETRY="$AUTOMATION_ROOT/jobs/telemetry.py"

file_report() {
  local kind="$1" text="$2" ident="${3:-}" win="${4:-86400}"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
    ${ident:+--identity "$ident"} --window "$win" >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$text"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $text"
  fi
}

day="$(date -u +%Y-%m-%d)"

packet=""
ranges=""
repo_review() { # dir — append this repo's 36h commit packet + range summary
  local dir="$1" log n oldest newest
  log="$(git -C "$dir" log --since='36 hours ago' --oneline 2>/dev/null)"
  [ -n "$log" ] || return 1
  n="$(printf '%s\n' "$log" | wc -l)"
  oldest="$(printf '%s\n' "$log" | tail -n 1 | cut -d' ' -f1)"
  newest="$(printf '%s\n' "$log" | head -n 1 | cut -d' ' -f1)"
  ranges+="- $(basename "$dir"): ${oldest}^..${newest} (${n} commits)
"
  packet+="## $(basename "$dir")
$(git -C "$dir" log --since='36 hours ago' --stat -p 2>/dev/null | marked_cut 60000)
"
}
repo_review "$KERNEL"
repo_review "$AUTOMATION_ROOT"
if [ -z "$packet" ]; then
  breadcrumb "$JOB_NAME" "review-skip" "no commits in either repo in the last 36h"
  exit 0
fi

prompt="You are doing a fresh-eyes review of the recent commits pasted below.
Review EACH repo section separately. Output ONLY a terse markdown list of
findings, one per line, each classified P0 (must fix now), P1 (should fix
soon), P2 (nice to have), or nit. Name any scope violations explicitly.
Use this exact shape, one section per repo, in this order:

## hngh
- P1: <finding>
## hngh-automation
- nit: <finding>

If a repo has no findings, write exactly: no findings
If a section's evidence ends with an explicit "[truncated at N bytes]"
marker, that is this packet's cap — never report it as a truncated,
corrupted, or partially-written file.

$packet"

# operator quota directive (2026-09-07): intelligence-shaped bounded work
# rotates onto the quota models -- fresh-eyes review pins the kimi leg
# primary; a pace-blocked or failing kimi falls through to unsloth/ollama
# inside model_call, so the review never blocks on quota state.
MODEL_PIN="${MODEL_PIN:-kimi}"

t0=$(date +%s)
response="$(printf '%s' "$prompt" | model_call 4096)"
t1=$(date +%s)
wall=$(awk "BEGIN{printf \"%.1f\", $t1 - $t0}")
used="$(last_model_used)"

if [ "$used" = "none:archive-only" ] || [ -z "$response" ]; then
  # chain-accurate: with pin=kimi the alert fires only when the whole
  # pinned chain (kimi -> unsloth -> ollama) has failed.
  file_report alert "review unavailable: model chain down (pin=kimi exhausted through local) ($used)"
  exit 0
fi

mkdir -p "$AUTOMATION_ROOT/digest"
{
  printf '# fresh-eyes review %s\n\n_model: %s | wall_s: %s_\n\nreviewed (36h window):\n%s\n---\n\n%s\n' \
    "$day" "$used" "$wall" "$ranges" "$response"
} >"$AUTOMATION_ROOT/digest/REVIEW-$day.md"

# parse per-repo verdicts: sections "## <repo>", findings "- P0/P1/...: text"
verdicts="$(printf '%s\n' "$response" | awk '
  /^## /  { repo=substr($0,4); next }
  /^- /   { if (repo != "") print repo "\t" substr($0,3) }
')"
if [ -z "$verdicts" ]; then
  for repo in "$(basename "$KERNEL")" "$(basename "$AUTOMATION_ROOT")"; do
    file_report progress "review: $repo response did not match the expected format (see digest/REVIEW-$day.md)"
  done
  file_report alert "review: model response unparseable — read digest/REVIEW-$day.md" "review:parse" 86400
  python3 "$TELEMETRY" emit --kind review --model "$used" --wall-s "$wall" --source review-prep
  breadcrumb "$JOB_NAME" "review-done" "digest/REVIEW-$day.md written (unparseable response)"
  exit 0
fi

total_p01=0
while IFS="$(printf '\t')" read -r repo finding; do
  [ -n "$repo" ] || continue
  case "$finding" in
  P0* | P1*)
    total_p01=$((total_p01 + 1))
    slug="$(printf '%s' "$finding" | tr -cs 'a-zA-Z0-9' '-' | sed 's/^-*//; s/-*$//' | cut -c1-30)"
    file_report alert "review P0/P1 ($repo): $finding" "review:$repo:$slug" 86400
    ;;
  esac
done <<EOF
$verdicts
EOF

for repo in "$(basename "$KERNEL")" "$(basename "$AUTOMATION_ROOT")"; do
  n="$(printf '%s\n' "$verdicts" | awk -F'\t' -v r="$repo" '$1==r{n++}END{print n+0}')"
  p01="$(printf '%s\n' "$verdicts" | awk -F'\t' -v r="$repo" '$1==r && $2~/^P[01]:/{n++}END{print n+0}')"
  if printf '%s\n' "$verdicts" | grep -q "^$repo$(printf '\t')no findings"; then
    file_report progress "review: $repo clean (no findings)"
  else
    file_report progress "review: $repo $n findings ($p01 P0/P1) -> digest/REVIEW-$day.md"
  fi
done

python3 "$TELEMETRY" emit --kind review --model "$used" --wall-s "$wall" \
  --source review-prep --subject "digest/REVIEW-$day.md"
breadcrumb "$JOB_NAME" "review-done" "digest/REVIEW-$day.md written via $used ($total_p01 P0/P1)"
exit 0
