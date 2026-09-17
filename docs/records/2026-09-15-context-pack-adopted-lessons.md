# Adopted-lessons block in the context pack (d1-surface) — 2026-09-15

Machine session record (jcode deep task graph node `d1-surface`, swarm
lane `session_dolphin_1789472126868_b6fe1d64bcfa1dc6`). Free-commit
automation lane; coordinator commits. No kernel `src/`, `tests/`,
`Makefile`, or `hngh.asd` touched.

## Problem

The harvest organ (d1-harvest, same day) made adopted research
dispositions cumulative in `automation/research-lessons.tsv`, but the
consumption side was still open: the operator context pack cited
`research index:` and nothing else from the research loop, so a
delegated session never saw any harvested lesson at orientation time.
d1-harvest's open question named exactly this ("should harvested
lessons be surfaced in context-pack consumption — audit suggestion
3b").

## Change

- `automation/lib/context-pack.sh`: one new block, rendered
  immediately after the existing `research index:` line. Header
  `adopted lessons (top-5 newest active, from research-lessons.tsv):`
  followed by up to five `lesson: <ISO Z date> <line_id>: <sentence>`
  lines. Active rows only (`$6 == "active"`), newest first (`sort -r`
  on the ISO Z date), lesson sentence visibly cut at 160 chars
  (`cut -c1-160`, the marked_cut visible-truncation convention — never
  a silent mid-word slice), block omitted silently when the ledger is
  absent, empty, or header-only (`[ -s ]` guard plus empty-block
  check). Derived-data law respected: the pack only cites the ledger;
  the ledger and the wiki LES-* pages stay the sources of truth.
- `automation/tests/test-context-pack.sh`: three new cases following
  the file's existing numbered-case conventions — absent ledger silent
  (case 6), header-only ledger silent (case 7), populated ledger
  renders top-5 newest active in order after the research index line
  with retired and oldest rows never present, plus a regression assert
  that the `frontier (kernel Verified numbers):` header survives on
  its own line after the block (case 8).

## The trap the tests almost missed

The unit fixture (5 clean rows) passed while a real-ledger render put
the last lesson line directly against the next section header
(`...is essentfrontier (kernel Verified numbers):`): `block="$(cat)"`
strips the trailing newline and the printf did not re-add it. Caught
by rendering the real 69-row ledger in a scratch sandbox before
landing; fixed by appending `\n` in the block printf and pinned by the
frontier-header regression assert.

## Verification

- Red-first: cases 6-8 landed before the block; case 8 failed on the
  missing header exactly as designed (the silent-omission cases passed
  pre-change because the old pack had no block at all).
- `bash tests/test-context-pack.sh` rc=0 (all 8 cases green).
- Live-ledger render proof: real `research-lessons.tsv` (69 active
  rows) in a `$JCODE_SCRATCH_DIR` sandbox, block shows the 5 newest
  lessons, cut at 160, frontier intact.
- Consumer suites unaffected: test-agent-respawn.py, test-bctx-launch.py,
  test-ocgo-launch.py, test-session-launch.py all OK.
- Full gate: `cd automation && make test` rc=0 — ALL PASS, identifier
  lint clean.

## Known limits / open questions

- Date-sort is lexicographic on ISO Z timestamps, correct for the
  format the harvest writes; a legacy hand-edited ledger with a
  different date shape would sort oddly (fail-quiet, not fail-closed —
  the pack is derived data and cites, never decides).
- The 160-char cut is a pack-sizing judgment, not a contract tested
  against CONTEXT_PACK_BYTES; the hard cap still bounds the whole
  pack (case 3 unchanged and green).
