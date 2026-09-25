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
# 'cadence/calendar/weekly/02' refs), then ONE bounded fresh-eyes model call
# (model_call 1024, evidence capped 6000 chars) under the house
# registers (hngh docs/design/writing-register.md +
# display-register-spec.md). Each parsed finding files ONE report-queue
# row (identity ux-review:<surface>:<slug>, kind alert, window 7d —
# identity-dedup). Zero findings file a single clean row per window.
# Fail-closed: model down -> breadcrumb + exit 0. Missing surface ->
# pre-check row + exit 0.
#
# usage: cadence/calendar/daily/19-ux-review.sh   (via cadence-tick.sh TIER=calendar)
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/model.sh"
[ -f "$AUTOMATION_ROOT/lib/redact.sh" ] && . "$AUTOMATION_ROOT/lib/redact.sh" || :

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../../.." && pwd)}"
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

# slug-mint guard (2026-09-18, plan 2026-09-18-backlog-p0-security-fixes
# step 4, gap-slug-residual-mints): alert-identity slugs are scrubbed at
# the source (single-source guard, lib/redact.sh) so a pathy or
# credential-shaped finding fragment cannot bake into the identity.
# Fail-closed: guard unavailable -> the raw text slugifies as before
# (identity dedup unchanged) but the row still files.
slugify() {
  local t
  if type redact_home >/dev/null 2>&1; then
    t="$(redact_home "$1")" || t=""
  else
    t="$1"
  fi
  [ -n "$t" ] || t="$1"
  if type scrub_truncate >/dev/null 2>&1; then
    t="$(scrub_truncate "$t")"
  fi
  [ -n "$t" ] || t="finding"
  printf '%s' "$t" | tr -cs 'A-Za-z0-9' '-' | cut -c1-40 |
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

# --- typed-first register pass (O6b typed lever): ONE ask_nouls call
# over the two registers the brief names (writing-register,
# display-register) -- the review's judgment targets. Fire bar 0.7 (the
# steer precedent): one report row per fired register, text
# `ux: <register> risk p=N.NN`, and no chat call. Every answer None (no
# key/offline), or an unjudged register with nothing fired -> fall
# through to the existing chat call byte-identical (fail-open legacy);
# every register answered below 0.7 -> one `ux: no findings (typed)`
# row, no chat call.
typed_rows="$(printf '%s' "$prompt" | python3 -c "
import os, sys
sys.path.insert(0, os.path.join('$AUTOMATION_ROOT', 'lib'))
from typesafe import ask_nouls
dims = ['writing-register', 'display-register']
ans = ask_nouls({'surface': '$surface', 'review_brief': sys.stdin.read()},
                {d: 'Is there a real UX problem in ' + d + '?' for d in dims})
fired = [d for d in dims if ans.get(d) is not None and ans[d] >= 0.7]
if fired:
    for d in fired:
        print('%s\tux: %s risk p=%.2f' % (d, d, ans[d]))
elif not any(v is None for v in ans.values()):
    print('clean\tux: no findings (typed)')
" 2>/dev/null)"
if [ -n "$typed_rows" ]; then
  printf '%s\n' "$typed_rows" | while IFS=$'\t' read -r did dtext; do
    file_report alert "$dtext" "ux-review:$surface:$did"
  done
  exit 0
fi

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
