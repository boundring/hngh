#!/usr/bin/env bash
# doc-suite-update — daily read-mostly verifier for the 20260830 doc suite
# (~/Projects/etc/20260830). Deterministic shell only: no prose rewriting,
# no AI calls. Verifies structural integrity (internal .md links, mermaid
# fence balance, version header, at least one `## ` section per doc) and
# spot-checks stable facts (kernel HEAD in log, gate-green breadcrumb
# within 36h, hngh timers alive, the 2026-08-30 fix commits still in the
# automation log). Appends one dated row to the suite CHANGELOG.md
# (created if missing). Fail-closed: any failure exits nonzero with the
# failing list, which the day-tier wrapper turns into an honest alert row.
#
# usage: jobs/doc-suite-update.sh   (via cadence/day/08-doc-suite-check.sh)
# env:   DOC_SUITE_DIR overrides the suite dir (fixture/self-test).
set -u
. "$(cd "$(dirname "$0")/.." && pwd)/lib/common.sh"

SUITE="${DOC_SUITE_DIR:-$HOME/Projects/etc/20260830}"
KERNEL="${HNGH_HOME:-$HOME/Projects/etc/hngh}"
AUTO_GIT="$AUTOMATION_ROOT"
FIX_COMMITS="be84690 760adb5 5b79b86 1113810 dcb6221"
GATE_MAX_AGE=$((36 * 3600))

failures=()
docs_ok=0
links_ok=0
facts_ok=0
fail() { failures+=("$1"); }

# --- 1. structural integrity -------------------------------------------------
docs=0
before=0
for f in "$SUITE"/*.md; do
  [ -f "$f" ] || continue
  [ "$(basename "$f")" = "CHANGELOG.md" ] && continue # the changelog verifies itself
  docs=$((docs + 1))
  d="$(dirname "$f")"
  # internal .md links resolve
  for link in $(grep -oE '\]\([^)]+\.md\)' "$f" | sed -E 's/^\]\(//; s/\)$//' | sort -u); do
    [ -n "$link" ] || continue
    if [ -f "$d/$link" ]; then
      links_ok=$((links_ok + 1))
    else
      fail "$(basename "$f"): broken link -> $link"
    fi
  done
  # mermaid fences balanced (every fence line pairs up)
  fences="$(grep -c '^```' "$f")"
  [ $((fences % 2)) -eq 0 ] || fail "$(basename "$f"): unbalanced code fences ($fences fence lines)"
  # version header + at least one ## section
  head -n 1 "$f" | grep -q '^# .*[Dd]oc suite' ||
    grep -qE '^(Draft v|Expanded v|Introduction v|Doc suite)' "$f" ||
    fail "$(basename "$f"): missing version header line"
  grep -q '^## ' "$f" || fail "$(basename "$f"): no '## ' section"
  [ ${#failures[@]} -eq "$before" ] && docs_ok=$((docs_ok + 1))
  before=${#failures[@]}
done

# --- 2. key-fact spot checks --------------------------------------------------
head_hash="$(git -C "$KERNEL" rev-parse --short HEAD 2>/dev/null)"
if [ -n "$head_hash" ] && git -C "$KERNEL" log --format=%h | grep -qx "$head_hash"; then
  facts_ok=$((facts_ok + 1))
else
  fail "fact: kernel HEAD $head_hash not found in kernel git log"
fi

last_green="$(grep ' | gate-green | ' "$AUTOMATION_ROOT/STATE.md" 2>/dev/null | tail -n 1 | cut -d'|' -f1 | xargs)"
if [ -n "$last_green" ] &&
  [ $(($(date -u +%s) - $(date -u -d "$last_green" +%s 2>/dev/null || echo 0))) -le "$GATE_MAX_AGE" ]; then
  facts_ok=$((facts_ok + 1))
else
  fail "fact: no gate-green breadcrumb in STATE.md within last 36h"
fi

timers="$(systemctl --user list-timers 'hngh-*' --no-pager 2>/dev/null | grep -c hngh)"
if [ "${timers:-0}" -gt 0 ]; then
  facts_ok=$((facts_ok + 1))
else
  fail "fact: hngh timer count is 0 (systemctl --user list-timers 'hngh-*')"
fi

missing_commits=""
for c in $FIX_COMMITS; do
  git -C "$AUTO_GIT" cat-file -e "$c^{commit}" 2>/dev/null || missing_commits="$missing_commits $c"
done
if [ -z "$missing_commits" ]; then
  facts_ok=$((facts_ok + 1))
else
  fail "fact: fix commit(s) missing from automation log:$missing_commits"
fi

# --- changelog row (always appended; failures listed one per line) -----------
CHANGELOG="$SUITE/CHANGELOG.md"
[ -f "$CHANGELOG" ] || printf '# Doc suite changelog — append-only\n' >"$CHANGELOG"
row="## $(date +%F) — verified $docs docs, $links_ok links ok, $facts_ok fact checks passed, ${#failures[@]} failures"
{
  printf '\n%s\n' "$row"
  [ ${#failures[@]} -gt 0 ] && printf '%s\n' "${failures[@]}"
} >>"$CHANGELOG"

if [ "${#failures[@]}" -gt 0 ]; then
  log "doc-suite check FAILED: ${#failures[@]} failure(s)"
  printf '%s\n' "${failures[@]}"
  exit 1
fi
log "doc-suite ok: $docs docs, $links_ok links, $facts_ok fact checks"
exit 0
