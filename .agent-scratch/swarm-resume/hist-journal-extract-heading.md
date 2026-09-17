# hist-journal-extract-heading: journal H1 heading rule and first-narrative-sentence rule

Read-only exploration of `docs/journal/` heading form, the date-from-filename
authority, and how to extract the first narrative sentence after the H1.
Builds on hist-journal-format.md (section order) and hist-journal-glob.md
(naming/validation).

## H1 heading rule

- Exact form: `# Journal — YYYY-MM-DD` where the date equals the filename
  stem, an EM DASH (U+2014 `—`) between "Journal" and the date, single
  spaces around it. No trailing punctuation in the canonical form.
- Optional free-text suffix may follow the date, separated by a space:
  the only observed instance is `2026-08-25.md:1`:
  `# Journal — 2026-08-25 (day one)`.
- All 22 dated files carry exactly one H1 on line 1 in this form
  (`grep -n '# Journal' docs/journal/2026-*.md` -> every match is `:1:`).
  `docs/journal/README.md` has no such H1 (it is the directory readme, see
  hist-journal-glob.md).
- Single producer in code: `scripts/generate-publication:408` emits
  `f"# Journal — {day}"` as the first line of `build_journal(day)`.
  No other script or test greps/validates the heading (only consumer of the
  date is path construction, `journal_path()` at lines 446-447).

## Date-from-filename authority

- The filename `YYYY-MM-DD.md` is the authoritative date. The H1 date is
  redundant presentation: a checker should parse the date from the stem
  (`p.stem`, validated as `%Y-%m-%d` per hist-journal-glob.md) and verify the
  H1 matches it, rather than parsing the date out of the heading.
- Rationale from code: `journal_path(day)` builds the path from the day;
  `build_journal` interpolates the same `day` into the heading, so stem and
  heading cannot legitimately diverge in machine-written files. The
  hand-written day-one file keeps the match with a suffix.
- Suggested validation regex: `^# Journal — (\d{4}-\d{2}-\d{2})( .*)?$`,
  capture group 1 must equal the file stem.

## First-narrative-sentence rule

Definition: the first non-heading, non-list, non-sentinel prose line after
the H1 (line 1). "Non-sentinel" excludes `<!-- ... -->` HTML-comment feed
citations; "non-list" excludes `- ` bullets.

Observed shapes across eras (line refs):

1. `docs/journal/2026-08-25.md:3-5` - early era: prose paragraph directly
   after the H1 (blank line 2, then "The project grew a whole self this
   day: ...").
2. `docs/journal/2026-09-05.md:3` - machine-ledger era: a one-line narrative
   sentence before the first `##` section ("4 commits moved; ... verified
   before it was written."). Same shape in `2026-08-30.md:3`.
3. `docs/journal/2026-09-12.md` and `2026-09-15.md` - DISPATCH era: the
   narrative sentence has been pushed below the `## DISPATCH` section and
   its `<!-- sources: ... -->` sentinel. E.g. `2026-09-15.md:12`:
   "38 commits moved; 2 of them candidate-bound. Each one was verified
   before it was written." If extraction is scoped to "before the first
   `##`", these files yield nothing.

Extraction algorithm that covers all three eras:

1. Skip the H1 (line 1) and blank lines.
2. Skip any line starting with `#` (headings) or `- ` / `* ` (list items).
3. Skip `<!--` lines and everything through the matching `-->` (sentinels;
   in practice single-line comments).
4. The first remaining non-empty line is the narrative lead; it may
   continue onto subsequent lines until a blank line or a
   heading/list/sentinel line. The narrative sentence ends at the first
   `. ` sentence terminator (the generator always writes a single
   sentence paragraph, see `journal_narrative()` /
   `build_journal()` lines 407-410: narrative is inserted as one block
   followed by a blank line).
5. In DISPATCH-era files the lead found this way is the
   "N commits moved..." sentence (it sits between the sources comment and
   `## The ledger`); in early files it is the hand-written opening
   paragraph.

## Summary for a parser

- H1 regex: `^# Journal — (\d{4}-\d{2}-\d{2})( .+)?$`; group 1 == stem.
- Date authority: filename stem; heading is a check, not a source.
- First narrative: first prose line after H1 after skipping blanks,
  headings, list items, and HTML comments; extend to the paragraph's end.
