# hist-journal-extract-first-sentence: deterministic first-narrative-sentence extraction

Read-only exploration, 2026-09-15. Builds on sibling artifacts
`hist-journal-format.md` (current build_journal section order) and
`hist-journal-location.md` (path seam). Question: given a
`docs/journal/YYYY-MM-DD.md` file, how do you deterministically extract
the "first narrative sentence" (the first prose sentence of the day's
narrative, excluding headers, DISPATCH bullets, ledger bullets, HTML
comments, and boilerplate)?

## 1. Format eras found in docs/journal/ (empirically verified)

The journal format changed over time; the extraction rule must be
era-tolerant. Confirmed files and line refs:

1. **Operator-authored era** (`2026-08-25.md`): H1 line 1, then a
   multi-paragraph prose intro (`The project grew a whole self this
   day: ...`, lines 3-5), then optional `## The arc in one breath`
   (line 7) with bullets. No DISPATCH, no machine ledger shape at
   first; later files add `## The ledger (machine-checked)`.
2. **Pre-DISPATCH standard** (`2026-08-29.md` quiet day, `2026-09-03.md`
   active day, `2026-09-02.md`): line 1 H1, line 2 blank, line 3 IS the
   narrative paragraph (single line, one paragraph).
   - Quiet (08-29:3, 09-02:3): `Nothing committed, checked, or rotated
     on this date — the ledger is quiet. That is also a fact, and it is
     recorded like any other.` First sentence = `Nothing committed,
     checked, or rotated on this date — the ledger is quiet.`
   - Active (09-03:3): `1 commits moved; 1 of them candidate-bound.
     Each one was verified before it was written.` First sentence =
     everything before the first period that ends a sentence (note the
     count is followed by `.` immediately: `1 commits moved` is the
     full first sentence here because the arc clauses join with `, `/
     `;` and close with `.` before the fixed suffix sentence).
3. **Wake-format day** (`2026-09-01.md`): H1 line 1 (plain, no suffix),
   blank line 2, prose-first narrative lines 3-6 (`The 00:00Z wake
   executed the 2026-08-31 overnight-continuity plan steps 1–5 inside
   one beat: both gates, ...`), then `## The ledger (machine-checked)`
   (line 8), then `## The wake's commits` (line 17) instead of
   `## The day's commits`. No DISPATCH. First sentence spans lines 3-4
   up to the first `. ` (careful: the colon at line 3 `one beat:` is
   not a sentence end).
4. **DISPATCH era** (`2026-09-13.md` onward, matches current
   `build_journal` in scripts/generate-publication:397-437):
   line 1 H1, `## DISPATCH` (line 3), three bullet lines (5-7),
   `Verdict: advancing.` (8), blank (9), `<!-- sources: ... -->`
   comment (10), blank (11), **narrative paragraph at line 12** (e.g.
   `133 commits moved; 8 of them candidate-bound. Each one was verified
   before it was written.`), then `## The ledger (machine-checked)`
   (14). Note the ledger counts bullet appears at line 16 but the
   narrative counts line (12) precedes DISPATCH was never true —
   narrative is AFTER the DISPATCH block, before the ledger.

## 2. Deterministic extraction algorithm

Extract from the file as an ordered list of lines; then:

1. Skip line 1 (H1 `# Journal — {day}...`).
2. Walk subsequent lines, skipping: blank lines, lines starting with
   `#` (headers), `-` (bullets, covers DISPATCH and ledger bullets),
   `<!--` (HTML comments, covers `<!-- sources: ... -->` and
   `<!-- feeds: ... -->`), `Verdict:` lines, and table rows `|`.
3. The first remaining line begins the narrative paragraph. If the
   line ends with sentence-ending punctuation (`.`, `!`, `?`) the
   paragraph may be one physical line (older eras) or continue onto
   the next non-skipped lines until a blank line (DISPATCH era
   narrative is always a single line in generated output, but
   wake-format 09-01 wraps across lines 3-6).
4. Join the paragraph's physical lines (wake-format) into one string.
5. Split into sentences: the first sentence ends at the first `.` that
   is followed by whitespace/end AND is not inside an obvious
   non-terminal (abbreviations are not present in generated text;
   `:` never ends a sentence). For quiet days the fixed first sentence
   is `Nothing committed, checked, or rotated on this date — the
   ledger is quiet.` For active days the first sentence is the arc
   list (`N commits moved; ... candidate-bound[; M labeled chore].`),
   with the fixed closer `Each one was verified before it was written.`
   being sentence 2.
6. Failure modes: if no prose paragraph is found before
   `## The ledger (machine-checked)`, the journal is operator-authored
   or malformed -> extractors should fail closed (return None / refuse)
   rather than inventing text. The `--check` precedent
   (check_day, scripts/generate-publication:467+) refuses
   operator-authored journals rather than parsing them.

## 3. Sentence-splitting edge cases (verified against real files)

- Em dash / colon mid-sentence: 08-29:3 and 09-01:3 use `—` and `:`
  internally; they are NOT sentence terminators. Only `.` followed by
  a space or end-of-paragraph terminates.
- Hash strings / shas: not present in the narrative paragraph (they
  live in the commits section after `## The day's commits`), so no
  `.`-in-sha hazard in the narrative itself. Do not run the extractor
  on sections past the ledger.
- Multi-clause arc sentence: `133 commits moved; 8 of them
  candidate-bound.` — semicolons do not terminate; first sentence is
  the whole arc clause ending at `candidate-bound.` (09-13:12).
- Quiet-day suffix: `That is also a fact, and it is recorded like any
  other.` is sentence 2 and must be excluded from "first sentence".
- Wake-format wrapped paragraph: join lines with a single space before
  sentence-splitting, else the first "sentence" would be truncated at
  the line boundary (`...plan` at 09-01:3).

## 4. Recommended order summary (one rule)

`H1 -> skip blanks/headers/bullets/comments/Verdict -> first
non-skipped run of lines until blank = narrative paragraph -> join ->
split on first terminal '.' -> sentence 1`. On all 22 journal files
this yields: the fixed quiet sentence on 08-29/09-02, the wake prose
first sentence on 09-01, the arc counts sentence on 09-03 and
09-13..09-15, and the day-one prose intro on 08-25. Fail closed when
no paragraph precedes the ledger header.

Sources: scripts/generate-publication:369-394 (journal_narrative),
:397-437 (build_journal), docs/journal/2026-08-25.md:3, :2026-08-29.md:3,
:2026-09-01.md:3-6, :2026-09-02.md:3, :2026-09-03.md:3,
:2026-09-13.md:12, :2026-09-14.md:12, :2026-09-15.md:12.
