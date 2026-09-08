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

echo "context-pack contract: all green"
