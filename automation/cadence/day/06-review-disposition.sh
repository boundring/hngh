#!/usr/bin/env bash
# 06-review-disposition — REVIEW sink: the fresh-eyes review digests
# (digest/REVIEW-<date>.md, written by 04-review-prep.sh ~09:00) have no
# consumer; this drop-in turns their P1/P2 findings into report-queue
# rows (identity review-finding:<digest-date>:<slug>, text + "fix or
# park with cause") so each finding gets a routing-loop disposition.
# nits are skipped (counted in one log line). Idempotent: report-queue
# dedups by identity+window (7d covers digest reuse across days).
# Fail-closed: missing digest -> breadcrumb + exit 0.
#
# usage: cadence/day/06-review-disposition.sh   (via cadence-tick.sh TIER=day)
set -u
. "$(cd "$(dirname "$0")/../.." && pwd)/lib/common.sh"
. "$AUTOMATION_ROOT/lib/breadcrumbs.sh"
[ -f "$AUTOMATION_ROOT/lib/redact.sh" ] && . "$AUTOMATION_ROOT/lib/redact.sh" || :

KERNEL="${HNGH_HOME:-$(cd "$(dirname "$0")/../../.." && pwd)}"
REPORT="python3 $KERNEL/scripts/report-queue"
report_root="${HNGH_REPORT_ROOT:-$KERNEL}"

file_report() {
  local kind="$1" text="$2" ident="$3"
  if HNGH_REPORT_ROOT="$report_root" $REPORT --add "$kind" "$text" \
    --identity "$ident" --window 604800 >/dev/null 2>&1; then
    breadcrumb "$JOB_NAME" "$kind" "$ident"
  else
    breadcrumb "$JOB_NAME" "report-fail" "could not file $kind: $ident"
  fi
}

day="$(date -u +%Y-%m-%d)"
file="$DIGEST_DIR/REVIEW-$day.md"
if [ ! -f "$file" ]; then
  file="$DIGEST_DIR/REVIEW-$(date -u -d yesterday +%Y-%m-%d).md"
fi
if [ ! -f "$file" ]; then
  breadcrumb "$JOB_NAME" "review-dispose-skip" "no REVIEW digest for $day or yesterday"
  exit 0
fi
digest_date="$(basename "$file" .md)"
digest_date="${digest_date#REVIEW-}"

# slug-mint guard (2026-09-18, plan 2026-09-18-backlog-p0-security-fixes
# step 4, gap-slug-residual-mints): the finding text becomes an
# alert-identity slug, not a filename — still scrubbed at the source
# (single-source guard, lib/redact.sh) so a pathy/credential-shaped
# finding fragment cannot bake into the queued identity. Fail-closed:
# when the guard is unavailable the cut slug carries no redacted
# fragment but the row still files (identity dedup unchanged).
scr_slugify() {
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

# severity policy (llm_guardrails trick): the model assesses, code owns the
# policy. severity_of is the one precedence rule -- the final severity is
# the STRICTER of the typed judgment and the parsed legacy prefix (P1 >
# P2 > nit), so a typed answer can RAISE a finding (serious work buried
# under "- nit:") but can never silently LOWER a P1 the model flagged.
severity_of() {
  local typed="$1" legacy="$2" r
  for r in P1 P2 nit; do
    if [ "$typed" = "$r" ] || [ "$legacy" = "$r" ]; then
      printf '%s\n' "$r"
      return 0
    fi
  done
  printf '\n'
}

# one typed batched request per digest (fan-out): stdin = finding lines,
# stdout = one arbiter label per line (empty = typed unavailable). Typed
# unavailable (no key / no arbiter yet / any error) -> empty output and
# the legacy prefixes alone route, identical to the pre-typed behavior.
typed_severities() {
  TYPESAFE_DIGEST="$(head -c 8000 "$1")" python3 -c "
import os, sys
sys.path.insert(0, os.path.join('$AUTOMATION_ROOT', 'lib'))
from typesafe import ask_choices, arbiter
lines = [l.rstrip('\n') for l in sys.stdin if l.strip()]
state = {'digest': os.environ.get('TYPESAFE_DIGEST', '')}
questions = {}
for i, line in enumerate(lines, 1):
    qid = 'finding_%d' % i
    state[qid] = line
    questions[qid] = (
        'Severity of the finding in \`%s\`: P1 = serious (broken behavior, data loss, security), P2 = nice to have, nit = style/minor.' % qid,
        ['P1', 'P2', 'nit'])
typed = ask_choices(state, questions)
labels = ['P1', 'P2', 'nit']
for i, line in enumerate(lines, 1):
    legacy = line[2:].split(':', 1)[0].strip()
    t, _c = typed.get('finding_%d' % i, (None, None))
    print(arbiter((t, _c), legacy if legacy in labels else None, labels, 0.5) or '')
" 2>/dev/null
}

# finding lines are markdown list items: "- P1: text" / "- P2: text" /
# "- nit: text"; the scan now sees all three so nits stop being silently
# dropped by accident -- skipping them is the named policy constant here.
route_findings() {
  local f="$1" finding text legacy slug final nits=0 i=0
  local -a findings typed
  mapfile -t findings < <(grep -E '^- (P1|P2|nit):' "$f" 2>/dev/null)
  mapfile -t typed < <(printf '%s\n' "${findings[@]}" | typed_severities "$f")
  for finding in "${findings[@]}"; do
    legacy="${finding#- }"
    legacy="${legacy%%:*}"
    final="$(severity_of "${typed[i]:-}" "$legacy")"
    i=$((i + 1))
    case "$final" in
    nit)
      nits=$((nits + 1))
      ;;
    P1 | P2)
      text="${finding#- ${legacy}: }"
      slug="$(scr_slugify "$text")"
      [ -n "$slug" ] || slug="finding"
      file_report alert "$text fix or park with cause" \
        "review-finding:$digest_date:$slug"
      ;;
    *)
      nits=$((nits + 1))
      ;;
    esac
  done
  printf '%s [%s] %s nit finding(s) skipped\n' "$(date -u +%H:%M:%S)" \
    "$JOB_NAME" "$nits" >&2
}

route_findings "$file"

breadcrumb "$JOB_NAME" "review-dispose-done" "$file sunk to report queue"
exit 0
