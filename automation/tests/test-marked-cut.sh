#!/usr/bin/env bash
# test-marked-cut.sh — contract proof for lib/common.sh marked_cut and
# its source_block wiring: a byte cap on model-facing evidence MUST be
# visibly marked, and uncut input MUST stay marker-free. Unmarked
# mid-word cuts read as corrupted files to review models (phantom
# findings 55db79ae / 622e68f0 were exactly that). Hermetic: sandbox
# dirs only, no repos or endpoints touched.
set -u
root="$(cd "$(dirname "$0")/.." && pwd)"
sb="$(mktemp -d)"
trap 'rm -rf "$sb"' EXIT
mkdir -p "$sb/lib"
ln -s "$root/lib/common.sh" "$sb/lib/common.sh"
. "$sb/lib/common.sh"

ok() { echo "ok: $1"; }
need() { "$@" || { echo "FAIL: $*"; exit 1; }; } # every case fatal

# case 1: stdin pipe longer than cap -> marker, head is byte-exact
out="$(printf 'plan supply refilled' | marked_cut 10)"
need test "${out%%$'\n'*}" = "plan suppl"
need grep -q '^\[truncated at 10 bytes\]$' <<<"$out"
ok "stdin cut: head exact + marker"

# case 2: stdin under cap -> unchanged, no marker
out="$(printf 'short' | marked_cut 6000)"
need test "$out" = "short"
if grep -q 'truncated' <<<"$out"; then echo "FAIL: marker leaked into uncut output"; exit 1; fi
ok "stdin uncut: no marker"

# case 3: file arg cut -> marker present
seq 1 500 >"$sb/big.json"
marked_cut 200 "$sb/big.json" >"$sb/out3"
need grep -q '\[truncated at 200 bytes\]$' "$sb/out3"
ok "file cut: marker present"

# case 4: file exactly at cap -> no marker (cut only when longer)
head -c 100 /dev/zero | tr '\0' 'a' >"$sb/exact.json"
out="$(marked_cut 100 "$sb/exact.json")"
need test "$out" = "$(head -c 100 "$sb/exact.json")"
if grep -q 'truncated' <<<"$out"; then echo "FAIL: marker leaked into exact-fit output"; exit 1; fi
ok "boundary: exact-size input unmarked"

# case 5: source_block carries the marker (wake-context path)
seq 1 500 >"$sb/sessions-0101.json"
blk="$(source_block "$sb/sessions-0101.json" 100)"
need grep -q '\[truncated at 100 bytes\]$' <<<"$blk"
ok "source_block: marked cap reaches prompts"

echo "test-marked-cut: all pass"
