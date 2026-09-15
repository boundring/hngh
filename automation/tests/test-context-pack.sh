#!/usr/bin/env bash
# test-context-pack.sh — contract proof for lib/context-pack.sh: the
# context pack (hngh docs/design/context-manager.md) is one bounded
# orientation file — size cap enforced, every promised section present,
# role hints vary by role, and the frontier cites the kernel torch
# sentinel. Hermetic: sandbox dirs only, no real sessions, no spend.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/automation/lib" "$sb/kernel/docs/project"

# minimal kernel STATE-OF-PROJECT with a torch-sentinel frontier
cat >"$sb/kernel/docs/project/STATE-OF-PROJECT.md" <<'EOF'
# State of project

## Verified numbers

<!-- torch:begin -->
- Research lines: 2 planned, 1 contracting, 26 crystallized (test).
- Gates: gate-green (test).
<!-- torch:end -->

## Hand-edited section (must NOT appear in the pack)
SECRET-looking hand-edited line outside the sentinels
EOF

ln -s "$root/lib/common.sh" "$sb/automation/lib/common.sh"
ln -s "$root/lib/context-pack.sh" "$sb/automation/lib/context-pack.sh"

# pack ROLE SLUG in a fresh subshell; the echoed path lands in $out
pack() {
  out="$(ROOT="$sb/automation" HNGH_HOME="$sb/kernel" bash -c '
    . '"$sb/automation"'/lib/common.sh
    . '"$sb/automation"'/lib/context-pack.sh
    context_pack "$1" "$2"' _ "$1" "$2")" || return 1
}

ok() { echo "ok: $1"; }
need() { "$@" || {
  echo "FAIL: $*"
  exit 1
}; } # every case fatal

# case 1: sections present — header with role, repo map, ledgers, role
# hint, frontier from the torch sentinel; path echoed, file written
pack overnight-lead seed
need test "$out" = "$sb/automation/prompts/overnight/seed.context.txt"
need test -s "$out"
body="$(cat "$out")"
need grep -q '^# context pack — role=overnight-lead seed — regenerated ' <<<"$body"
need grep -q '^automation repo: ' <<<"$body"
need grep -q '^ledgers: STATE.md agent-handoffs.md' <<<"$body"
need grep -q '^kernel ledgers: ' <<<"$body"
need grep -q '^research index: ' <<<"$body"
need grep -q '^role hint: ' <<<"$body"
need grep -q '^frontier (kernel Verified numbers):' <<<"$body"
need grep -q 'Research lines: 2 planned' <<<"$body" # torch sentinel cited
if grep -q 'SECRET-looking' <<<"$body"; then
  echo "FAIL: pack leaked content outside the torch sentinels"
  exit 1
fi
ok "sections present, frontier from torch sentinel only"

# case 2: role hints vary — each role gets its own one-line hint
for r in overnight-lead research review; do
  pack "$r" "hint-$r"
  need grep -q "^# context pack — role=$r " "$out"
done
h1="$(grep '^role hint: ' "$sb/automation/prompts/overnight/hint-overnight-lead.context.txt")"
h2="$(grep '^role hint: ' "$sb/automation/prompts/overnight/hint-research.context.txt")"
h3="$(grep '^role hint: ' "$sb/automation/prompts/overnight/hint-review.context.txt")"
need test "$h1" != "$h2"
need test "$h2" != "$h3"
need test "$h1" != "$h3"
ok "role hints vary: overnight-lead / research / review"

# case 3: size cap enforced — the whole pack never exceeds the cap
# (head -c on the assembled stream)
pack_at_cap() {
  ROOT="$sb/automation" HNGH_HOME="$sb/kernel" CONTEXT_PACK_BYTES=200 bash -c '
    . '"$sb/automation"'/lib/common.sh
    . '"$sb/automation"'/lib/context-pack.sh
    context_pack overnight-lead cap >/dev/null'
}
pack_at_cap
n="$(wc -c <"$sb/automation/prompts/overnight/cap.context.txt")"
need test "$n" -le 200
ok "size cap enforced: $n <= 200 bytes"

# case 4: the echoed path is the file just written (callers carry it
# into briefs and prompts)
pack overnight-lead echo
need test -s "$out"
ok "pack path echoed and written"

# case 5: the pack header carries the authoritative machine clock
# (ttsr alignment SUPPLY — the model never guesses time of day)
pack overnight-lead clock
need grep -q '^current UTC (machine clock — verify against it, never assume): ' "$out"
ok "pack header carries machine-clock UTC line"

# case 6: no research-lessons.tsv -> the adopted-lessons block is
# omitted silently (no noise, no failure)
pack overnight-lead nolessons
need grep -q '^research index: ' "$out"
if grep -q '^adopted lessons' "$out"; then
  echo "FAIL: adopted-lessons block rendered without the ledger"
  exit 1
fi
ok "absent lessons ledger omitted silently"

# case 7: header-only lessons ledger -> block still omitted silently
printf 'lesson_id\tdate\tline_id\tsubject\tlesson\tstatus\n' \
  >"$sb/automation/research-lessons.tsv"
pack overnight-lead empty
if grep -q '^adopted lessons' "$out"; then
  echo "FAIL: adopted-lessons block rendered for an empty ledger"
  exit 1
fi
ok "empty lessons ledger omitted silently"

# case 8: populated ledger -> top-5 newest ACTIVE lessons (date,
# line_id, lesson), after the research index line, oldest and retired
# rows never rendered
mklesson() { # date line_id status
  printf 'les-%s-%s\t%sT00:00:00Z\t%s\tsubject for %s\tlesson sentence for %s\t%s\n' \
    "$1" "$2" "$1" "$2" "$2" "$2" "$3"
}
{
  printf 'lesson_id\tdate\tline_id\tsubject\tlesson\tstatus\n'
  mklesson 2026-09-01 l-old-1 active
  mklesson 2026-09-07 l-new-7 retired
  mklesson 2026-09-06 l-new-6 active
  mklesson 2026-09-05 l-new-5 active
  mklesson 2026-09-04 l-new-4 active
  mklesson 2026-09-03 l-new-3 active
  mklesson 2026-09-02 l-new-2 active
} >"$sb/automation/research-lessons.tsv"
pack overnight-lead lessons
need grep -q '^adopted lessons (top-5 newest active, from research-lessons.tsv):' "$out"
for d in 6 5 4 3 2; do
  need grep -q "lesson: 2026-09-0${d}T00:00:00Z l-new-$d: lesson sentence for l-new-$d" "$out"
done
if grep -q 'l-old-1' "$out"; then
  echo "FAIL: 6th-newest lesson rendered (cap is 5)"
  exit 1
fi
if grep -q 'l-new-7' "$out"; then
  echo "FAIL: retired lesson rendered"
  exit 1
fi
ln_res="$(grep -n '^research index: ' "$out" | cut -d: -f1)"
ln_blk="$(grep -n '^adopted lessons' "$out" | cut -d: -f1)"
need test "$ln_res" -lt "$ln_blk" # block follows the research index line
need test "$(grep -n 'lesson: 2026-09-06T00:00:00Z ' "$out" | cut -d: -f1)" -lt \
  "$(grep -n 'lesson: 2026-09-05T00:00:00Z ' "$out" | cut -d: -f1)" # newest first
ok "adopted-lessons block: top-5 newest active, ordered, placed"
need grep -q '^frontier (kernel Verified numbers):' "$out" # block never eats the next section's newline

echo "context-pack contract: all green"
