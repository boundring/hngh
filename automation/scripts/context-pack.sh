#!/usr/bin/env bash
# context-pack.sh -- the cached per-UTC-day orientation pack (refoundation
# P6): gathers EXACTLY the demand synthesizer's orientation inputs
# (cadence/hour/33-research-beat.sh demand_synthesize) once per day and
# writes them under five fixed section headers so the synthesizer (and any
# other consumer) reads a file instead of re-running the gathers. A second
# run the same day reuses the pack (exists + non-empty -> exit 0, print
# nothing). Fail-soft: a missing input degrades to an empty section; the
# script always exits 0. The logs dir is runtime data, never committed.
set -u

AUTOMATION_ROOT="${AUTOMATION_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
AUTOMATION_ROOT="$(cd "$AUTOMATION_ROOT" && pwd)"
# same kernel seam as the beat: HNGH_HOME wins, else the repo root that
# contains automation/ (two dirs up from this script in the real layout)
KERNEL="${HNGH_HOME:-$(cd "$AUTOMATION_ROOT/.." && pwd)}"
KERNEL="$(cd "$KERNEL" 2>/dev/null && pwd || printf '%s' "$KERNEL")"
REPORT="${REPORT:-python3 $KERNEL/scripts/report-queue}"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"
DISPOSITIONS="$AUTOMATION_ROOT/research-dispositions.tsv"

out="$AUTOMATION_ROOT/logs/context-pack-$(date -u +%F).txt"
mkdir -p "$AUTOMATION_ROOT/logs" 2>/dev/null
[ -s "$out" ] && exit 0 # today's pack already built: reuse

disp="$(tail -n 20 "$DISPOSITIONS" 2>/dev/null || true)"
les="$(tail -n 20 "$KERNEL/docs/project/lessons-index.md" 2>/dev/null || true)"
backlog="$(tac "$AUTOMATION_ROOT/docs/BACKLOG.md" 2>/dev/null |
 awk '/^## /{c++} c<=3' | tac || true)"
alerts="$(HNGH_REPORT_ROOT="$report_root" $REPORT --json 2>/dev/null | python3 -c '
import json, sys
try:
    rows = json.load(sys.stdin).get("reports", [])
except Exception:
    rows = []
out = []
for r in [x for x in rows if x.get("kind") == "alert"][:5]:
    ident = ""
    for ln in (r.get("body") or "").splitlines():
        if ln.startswith("identity:"):
            ident = ln.split(":", 1)[1].strip()
            break
    out.append(ident or r.get("id", ""))
print("\n".join(x for x in out if x))' || true)"
# source tokens: disposition line ids, lesson ids, backlog section
# titles, alert identities. A question citing none is recorded as a
# question, never a beat.
srcs="$(
 { [ -f "$DISPOSITIONS" ] && cut -f1 "$DISPOSITIONS" | grep -vx 'line'; } 2>/dev/null
 awk -F'|' '/^\|[^-]/ && $2 !~ /^ *Lesson *$/ {gsub(/^ +| +$/, "", $2); print $2}' \
  "$KERNEL/docs/project/lessons-index.md" 2>/dev/null
 grep '^## ' "$AUTOMATION_ROOT/docs/BACKLOG.md" 2>/dev/null |
  sed 's/^## //; s/ *([0-9][^)]*) *$//'
 printf '%s\n' "$alerts"
)"

# atomic publish: same-dir temp + mv (a reader never sees a half pack)
tmp="$out.tmp.$$"
{
 printf '== dispositions ==\n%s\n' "$disp"
 printf '== lessons ==\n%s\n' "$les"
 printf '== backlog ==\n%s\n' "$backlog"
 printf '== alerts ==\n%s\n' "$alerts"
 printf '== srcs ==\n%s\n' "$srcs"
} >"$tmp" 2>/dev/null && mv -f "$tmp" "$out" 2>/dev/null ||
 rm -f "$tmp" 2>/dev/null
exit 0
