#!/usr/bin/env bash
# 19-ux-review — day-tier antagonistic UX-review cycle. The operator
# asked for a daily rotating review of operator-facing surfaces: one
# surface per run, chosen deterministically by UTC day number
# (day_of_epoch % 5 — no state file to own). Surfaces:
#   dashboard-camp     landing view, verdict visibility, click depth
#   dashboard-logs     logs view slice-first presentation, findability
#   email-digest       live email-digest.py stdout composition
#   kernel-docs        hngh docs README read-order + state-of-project
#   overnight-report   newest overnight-report-*.md
# Per run: cheap procedural pre-checks (existence, ASCII, stale
# 'cadence/week/02' refs), then ONE bounded fresh-eyes model call
# (model_call 1024, evidence capped 6000 chars) under the house
# registers (hngh docs/design/writing-register.md +
# display-register-spec.md). Each parsed finding files ONE report-queue
# row (identity ux-review:<surface>:<slug>, kind alert, window 7d —
# identity-dedup). Zero findings file a single clean row per window.
# Fail-closed: model down -> breadcrumb + exit 0. Missing surface ->
# pre-check row + exit 0.
#
# usage: cadence/day/19-ux-review.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

file_report() { # kind text ident
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$1" "$2" \
    --identity "$3" --window 604800 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$1" "$3"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $1: $3"
  fi
}

slugify() {
  printf '%s' "$1" | tr -cs 'A-Za-z0-9' '-' | cut -c1-40 |
    sed 's/^-*//; s/-*$//'
}

# --- rotation (deterministic from UTC day; no state file) -------------
NSURFACES=5
idx=$(($(date -u +%s) / 86400 % NSURFACES))
surface="$(printf 'dashboard-camp\ndashboard-logs\nemail-digest\nkernel-docs\novernight-report\n' |
  sed -n "$((idx + 1))p")"

# --- gather evidence + surface file list ------------------------------
evidence=""
case "$surface" in
dashboard-camp)
  files="$AUTOMATION_ROOT/dashboard/index.html $AUTOMATION_ROOT/dashboard/overview-view.js"
  [ -f "$AUTOMATION_ROOT/dashboard/index.html" ] &&
    [ -f "$AUTOMATION_ROOT/dashboard/overview-view.js" ] &&
    evidence="$(cat $files)"
  ;;
dashboard-logs)
  files="$AUTOMATION_ROOT/dashboard/app.js $AUTOMATION_ROOT/dashboard/research-view.js"
  [ -f "$AUTOMATION_ROOT/dashboard/app.js" ] &&
    [ -f "$AUTOMATION_ROOT/dashboard/research-view.js" ] &&
    evidence="$(cat $files)"
  ;;
email-digest)
  evidence="$(python3 "$AUTOMATION_ROOT/scripts/email-digest.py" 2>/dev/null)" || evidence=""
  ;;
kernel-docs)
  files="$KERNEL/docs/README.md $KERNEL/docs/project/STATE-OF-PROJECT.md"
  [ -f "$KERNEL/docs/README.md" ] && [ -f "$KERNEL/docs/project/STATE-OF-PROJECT.md" ] &&
    evidence="$(cat "$KERNEL/docs/README.md" "$KERNEL/docs/project/STATE-OF-PROJECT.md")"
  ;;
overnight-report)
  file="$(ls -1t "$AUTOMATION_ROOT"/logs/overnight-report-*.md 2>/dev/null | head -1)"
  if [ -n "${file:-}" ]; then
    evidence="$(cat "$file")"
  fi
  ;;
esac

# --- procedural pre-checks (cheap, no model) --------------------------
if [ -z "$evidence" ]; then
  file_report alert \
    "ux-review $surface: surface evidence unavailable (missing files or empty compose) fix or park with cause" \
    "ux-review:$surface:surface-missing"
  exit 0
fi
defects=""
case "$(printf '%s' "$evidence" | LC_ALL=C grep -c '[^ -~\t]' || true)" in
0) ;;
*) defects="non-ASCII byte in $surface evidence" ;;
esac
if printf '%s' "$evidence" | grep -q 'cadence/week/02'; then
  defects="${defects:+$defects; }stale cadence/week/02 reference in $surface"
fi
if [ -n "$defects" ]; then
  file_report alert \
    "ux-review $surface precheck: $defects fix or park with cause" \
    "ux-review:$surface:precheck-$(slugify "$defects")"
fi

# --- one bounded fresh-eyes model call --------------------------------
evidence="$(printf '%s' "$evidence" | marked_cut 6000)"
prompt="You are the antagonistic reviewer of this operator surface.
Register law: writing-register — concrete nouns, active verbs, name the thing; cut dead metaphor, hedging, and significance adjectives. Display register — quiet, evidence-first: the literal fact renders first, one caption per state, never chatter.
Evidence:
$evidence
List up to 3 CONCRETE defects a reader would hit, each one line: defect -> why it fails the register or the task -> the file that would change. If none: exactly NONE"

response="$(printf '%s' "$prompt" | model_call 1024)" || {
  breadcrumb "$JOB_NAME" "ux-review-model-down" "$surface"
  exit 0
}

# --- parse + file: non-empty lines not equal to NONE are findings -----
findings="$(printf '%s\n' "$response" |
  grep -v '^[[:space:]]*$' | grep -vx 'NONE' || true)"
if [ -n "$findings" ]; then
  printf '%s\n' "$findings" | head -3 |
    while IFS= read -r finding; do
      file_report alert "$finding fix or park with cause" \
        "ux-review:$surface:$(slugify "$finding")"
    done
  breadcrumb "$JOB_NAME" "ux-review-done" "$surface: findings filed"
  exit 0
fi
file_report alert \
  "ux-review $surface: clean — no defects found" \
  "ux-review:$surface:clean"
exit 0
