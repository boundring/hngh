#!/usr/bin/env bash
# 03-mimic-drill — week-tier red-team beat (Descent station 6): prove
# the detection machinery actually detects, in mktemp sandbox copies
# ONLY — the live ledgers are never touched. Three legs:
#
#   (a) duplicate-refusal  — lib/causes.sh append_research_subject with
#       AUTOMATION_ROOT pointed at the sandbox must refuse a
#       duplicate-id research subject (and still admit a fresh one).
#   (b) router-second-candidate — an accepted zero-progress plan plus a
#       same-identity alert occurrence: scripts/router-tick.py (env
#       seams HNGH_HOME / STATE_FILE / HNGH_REPORT_QUEUE pointed at the
#       sandbox) must NOT mint a second candidate. Skipped honestly
#       with a "detection not yet landed" breadcrumb when the
#       plan-disposition machinery is absent from the tree.
#   (c) operator-items recurring — a dismissed-then-re-emitted item id
#       must come back marked recurring:true from
#       jobs/operator-items-feed.py run against sandbox roots.
#
# Each leg writes pass/fail into logs/mimic-<date>.md; any fail files
# one report-queue row ("mimic survived: <leg> — detection missed").
# Fail-closed: exits 0 always; every sandbox write stays inside the
# mktemp dir, cleaned by a trap.
#
# usage: cadence/day/18-mimic-drill.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
. "$AUTOMATION_ROOT/lib/causes.sh"

KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
day="${HNGH_TICK_TS:-$(date -u +%Y-%m-%d)}"
LOG="$AUTOMATION_ROOT/logs/mimic-$day.md"

file_report() {
  local kind="$1" text="$2" ident="$3"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
    --identity "$ident" --window 604800 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$ident"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $ident"
  fi
}

SB="$(mktemp -d)" || {
  breadcrumb "$JOB_NAME" "mimic-skip" "no mktemp dir"
  exit 0
}
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/jobs" "$SB/dashboard" "$SB/docs/project/plans"
now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

results="$AUTOMATION_ROOT/logs/.mimic-$day.tmp"
: >"$results"
leg() { # leg result detail
  printf '| %s | %s | %s |\n' "$1" "$2" "$3" >>"$results"
  [ "$2" = "fail" ] && file_report "alert" \
    "mimic survived: $1 — detection missed ($3)" "mimic:$1"
  return 0
}

# --- leg (a): duplicate research subject refused -----------------------
a_result="fail" a_detail=""
aid="fail-$(date -u +%Y%m%d)-mimic-dup"
printf '%s\tWhy does the mimic recurrence go undetected?\n' "$aid" \
  >"$SB/research-subjects.txt"
printf '%s\tplanned\t%s\tmimic fixture line\n' "$aid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  >"$SB/research-lines.tsv"
if AUTOMATION_ROOT="$SB" append_research_subject "mimic-dup" \
  "duplicate copy that must be refused" &&
  [ "$(wc -l <"$SB/research-subjects.txt")" -eq 1 ]; then
  if AUTOMATION_ROOT="$SB" append_research_subject "mimic-fresh" \
    "fresh demand that must be admitted" &&
    [ "$(wc -l <"$SB/research-subjects.txt")" -eq 2 ]; then
    a_result="pass" a_detail="duplicate-id subject refused, fresh subject admitted"
  else
    a_detail="duplicate refused but fresh subject not admitted (over-refusal)"
  fi
else
  a_detail="duplicate-id subject was appended to research-subjects.txt"
fi
leg "duplicate-refusal" "$a_result" "$a_detail"

# --- leg (b): router never mints a second candidate --------------------
b_result="skip" b_detail=""
if [ ! -f "$AUTOMATION_ROOT/scripts/plan-dispose.py" ]; then
  b_result="skip" b_detail="detection not yet landed (no scripts/plan-dispose.py in tree)"
  breadcrumb "$JOB_NAME" "mimic-skip" "leg router-second-candidate: detection not yet landed"
else
  plan="$SB/docs/project/plans/$day-routed-mimic-zero-progress.plan.md"
  {
    printf '<!-- plan: status=accepted risk=normal accepted=%s -->\n\n' "$now"
    printf '# mimic fixture: accepted zero-progress plan\n\n## Steps\n\n'
    printf -- '- [ ] step 1\n      Verification: mimic sandbox check\n'
  } >"$plan"
  stub="$SB/stub-report-queue"
  printf '#!/bin/sh\nexit 0\n' >"$stub"
  chmod +x "$stub"
  if HNGH_HOME="$SB" HNGH_AUTOMATION_ROOT="$SB" STATE_FILE="$SB/STATE.md" \
    HNGH_REPORT_QUEUE="$stub" HNGH_REPORT_ROOT="$SB" \
    python3 "$AUTOMATION_ROOT/scripts/router-tick.py" \
    --identity "mimic:zero-progress" \
    --text "mimic drill: same-identity alert refire" >/dev/null 2>&1 &&
    [ "$(ls "$SB/docs/project/plans/" | grep -c '\.plan\.md$')" -eq 1 ]; then
    b_result="pass" b_detail="same-identity refire minted no second candidate"
  else
    b_result="fail" b_detail="same-identity refire minted a second plan candidate"
  fi
fi
leg "router-second-candidate" "$b_result" "$b_detail"

# --- leg (c): dismissed-then-re-emitted item is recurring --------------
c_result="fail" c_detail=""
cp "$AUTOMATION_ROOT/jobs/operator-items-feed.py" "$SB/jobs/" || {
  c_detail="operator-items-feed.py missing from tree"
}
if [ -z "$c_detail" ]; then
  item="needs an operator decision on the mimic fixture"
  iid="$(ITEM="$item" python3 -c 'import hashlib, os, re
t = os.environ["ITEM"]
print(hashlib.sha256(
    re.sub(r"\s+", " ", re.sub(r"\*+", "", t)).strip().lower()
    .encode()).hexdigest()[:8])')"
  printf '{"generated_at": "%s", "digest": "## For the operator\\n\\n1. %s\\n\\n## Notes\\n\\n- filler\\n"}\n' \
    "$now" "$item" >"$SB/dashboard/data.json"
  printf '{"dismissed": {"%s": {"reason": "mimic drill"}}}\n' "$iid" \
    >"$SB/dashboard/operator-dismissed.json"
  : >"$SB/STATE.md"
  if python3 "$SB/jobs/operator-items-feed.py" >/dev/null 2>&1 &&
    python3 - "$SB/dashboard/operator-items.json" <<'PY' 2>/dev/null; then
import json, sys
items = json.load(open(sys.argv[1])).get("items") or []
sys.exit(0 if any(i.get("recurring") for i in items) else 1)
PY
    c_result="pass" c_detail="dismissed id re-emitted with recurring:true"
  else
    c_detail="re-emitted dismissed id not marked recurring"
  fi
fi
leg "operator-items-recurring" "$c_result" "$c_detail"

{
  printf '# Mimic drill %s\n\n' "$day"
  printf 'Red-team legs against sandbox copies (mktemp, cleaned up). The live\n'
  printf 'ledgers were never touched. skip = detection machinery absent, never faked.\n\n'
  printf '| leg | result | detail |\n|---|---|---|\n'
  cat "$results"
} >"$LOG"
rm -f "$results"
breadcrumb "$JOB_NAME" "mimic-drill" "a=$a_result b=$b_result c=$c_result"
exit 0
