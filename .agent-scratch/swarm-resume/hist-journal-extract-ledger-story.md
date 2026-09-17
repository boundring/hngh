# Journal: ledger vs story sections (ledger/story contract and legacy layouts)

Scope: `docs/journal/2026-08-25.md` .. `2026-09-15.md`. Builds on sibling
artifacts `hist-journal-format.md` (canonical section order + ledger line
formats) and `hist-journal-extract-heading.md` (era shapes).

## Canonical pairing (DISPATCH era, 2026-09-11 onward)

Every file from 2026-09-11 through 2026-09-15 uses the same block sequence:

1. `## DISPATCH` (h2) at lines 3-13: 3-4 hand bullets (sessions/spend,
   research lines, operator items) + one "Verdict: ..." line, then an
   HTML `<!-- sources: ... -->` provenance comment.
2. `## The ledger (machine-checked)` (h2) at lines 14-20: strictly 4
   bullets: commits/candidate-bound, check-ins, timeline rows, public
   edition pointer. Example `docs/journal/2026-09-11.md:14-20`:
   "- **71** commits; **3** candidate-bound." / "- **0** check-ins (none)."
   / "- **0** timeline rows: none." / "Public edition: docs/dispatch/2026-09-11.md ...".
3. `## The day's story` (h2) at lines 21-36/40: prose paragraphs, each
   preceded by a `<!-- feeds: ... -->` provenance comment
   (`2026-09-11.md:22,25,28,31,34`). Paragraphs: hall/plan telemetry
   ("The hall fired N session(s)..."), outside-the-wire digest
   ("Outside the wire, N dispatch block(s)..."), stall/blocker ledger
   ("The stall ledger ..."), learning loop ("The learning loop filed N
   session lesson(s)..."), then a closing "Verdict: holding|advancing -
   ..." line (`2026-09-11.md:39`, `2026-09-12.md:39`).
4. `## The book of the day` (h2, fixed boilerplate sentence) then
   `## The day's commits` (h2, list of `hash` + candidate lines).

Key distinction: ledger bullets are bare machine-checked counts (bold
number + unit, terse, no narrative); story paragraphs are templated
narrative sentences with embedded numbers and per-paragraph feed
comments. Both are machine-generated (see
`automation/tests/test-narrative-ledger.py:151-162`, which asserts the
story section follows the ledger with the ledger intact; and
`automation/tests/test-dispatch.sh:64` which forbids DISPATCH from
displacing the journal's own structure). The ledger's numbers and the
DISPATCH header numbers overlap (commits/candidate-bound appear in
both `2026-09-11.md:5` and `:15`); the story repeats them inside
sentences instead of bullets.

## Pre-DISPATCH ledger (2026-08-25 .. 2026-09-10)

- Ledger placed right after the H1 (sometimes after a one-line intro),
  with free-form bullets rather than the fixed 4-line set:
  - `2026-08-25.md:34-40`: bullet-style prose counts ("`make test`:
    2774 checks + 8 reader guards.", "60 commits this day; 45
    candidate-bound; ..."). No "The day's story" section exists; the
    narrative section is `## Looking out` (`:42`).
  - `2026-08-26.md:5-10`, `2026-08-27.md:5-10`, `2026-08-28.md:5-10`,
    `2026-08-29.md:5-10`, `2026-08-30.md:5-10`, `2026-08-31.md:5-10`,
    `2026-09-02.md:5-10` .. `2026-09-10.md:5-10`: a fixed 3-bullet
    mini-ledger ("**N** commits; **N** candidate-bound." / "**N**
    check-in(s) ..." / "**0** timeline rows: none.") followed by
    `## The book of the day` boilerplate, then `## The day's commits`.
    No `## The day's story` anywhere before 2026-09-11.
- Narrative roles the story later absorbed were carried by ad-hoc
  sections: `## Looking out` (`2026-08-25.md:42`), `## The day's
  commits` (commit narrative in early files), operator-written
  addenda.

## Legacy / odd layouts

- `docs/journal/2026-09-01.md` (multi-wake day): a lead prose
  paragraph (`:3-7`) before the first `## The ledger (machine-checked)`
  (`:8-16`). Per-wake subsections `## The wake's commits` (`:17-27`),
  `## Notes` (`:28-35`), `## The 01:00Z + 02:00Z wakes (2026-09-01
  plan)` (`:36-46`) each carry their OWN lower-level
  `### The ledger (machine-checked)` (`:47-56`) and commits bullets.
  So this file has two ledger headings at different levels (h2 and
  h3) for different wakes, one per prose block. This is the only file
  with a repeated ledger heading.
- `docs/journal/2026-09-08.md` (wake-header layout, no ledger at
  all): the H1 is followed by a single enormous H2 that is itself a
  wake description: `## 00:30Z overnight-continuity wake (plan
  2026-09-02-overnight-continuity, executed six days after acceptance
  - routed stubs and operator-items wakes held the queue first)`
  (`:3`), whose body is gate/prose/commit bullets (`:5+`). No `The
  ledger`, no `The day's story`, no `book of the day` present at the
  standard position. Most structurally divergent file in the set.
- `docs/journal/2026-08-26.md` (addendum layout): canonical-looking
  front (H1 `:1`, intro line `:3`, 3-bullet ledger `:5-10`, book of
  the day `:11-14`, day's commits `:15-29`) but ends with an
  operator-authored `## The overnight (operator addendum)` (`:30-42`),
  explicitly "the operator's dated note under" the machine-checked
  ledger (`:41-42`). Only operator-authored narrative section in the
  journal set.

## Story section origin

`## The day's story` first appears 2026-09-11 with the DISPATCH
header and is unchanged through 2026-09-15 (same heading lines and
same 5 templated paragraph pattern + trailing verdict; minor variance
is the stall-ledger quiet case, `2026-09-12.md:28`). The generator is
`scripts/generate-publication:414` which pins the literal
`## The ledger (machine-checked)` heading.

## Takeaways for extraction

- A reliable machine anchor across eras is the exact string
  `The ledger (machine-checked)`; but pre-09-11 ledgers vary in bullet
  count/format (1 free bullets -> 3 fixed bullets -> 4 fixed bullets),
  and 09-01 has two instances (h2 + h3).
- `The day's story` is DISPATCH-era only (2026-09-11+); for earlier
  files the narrative stand-ins are `Looking out`, wake prose, or the
  operator addendum.
