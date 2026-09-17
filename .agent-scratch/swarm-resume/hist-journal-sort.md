# hist-journal-sort: sort order spec for journal glob results

Read-only verification leaf. Confirms how `docs/journal/` files sort, what
consumers rely on it, and which direction each consumer uses.
Siblings: hist-journal-glob.md, hist-journal-location.md.

## The sort rule

- Journal date files are `docs/journal/YYYY-MM-DD.md`. For this fixed-width,
  zero-padded shape, lexicographic sort == chronological sort. There is no
  numeric/date-aware comparator anywhere; every ordered consumer uses plain
  string sort and relies on the naming contract.
- Declared convention (docs layer): **oldest first, newest last**.
  `docs/journal/README.md:3` -- "Dated working entries (`YYYY-MM-DD.md`),
  one per day, newest last."

## The only directory-enumerating consumer: generate-publication

- `scripts/generate-publication:588-592` `chapter_documents(patterns)`:
  `ROOT.glob(pattern)` per caller-supplied pattern, keep `p.is_file()`,
  dedupe into a set, then `sorted(matched)` by full path.
  - Result: **ascending lexicographic == chronological oldest-first** in the
    generated book. Confirms the README "newest last" convention.
  - Caveat (carried from hist-journal-glob.md): a naive
    `--chapters 'docs/journal/*.md'` would also match `README.md`, which
    sorts between dates lexicographically ("R" > digits is false; "R" sorts
    after digits, so README.md lands at the END, after the newest date --
    harmless for chronology but present in the book). Callers should glob
    `docs/journal/2*.md` or pass explicit dates.

## Consumers that do NOT enumerate (sort order irrelevant)

- `scripts/run-autonomous` `journal_day()` (lines 66-79): date arithmetic
  only (previous day), path built as `JOURNAL_DIR / f"{day}.md"` (line 101),
  existence check (line 95). No glob, no sort.
- `automation/jobs/daily-writeups.sh:32`: `j="$KERNEL/docs/journal/$day.md"`
  with `day=$(date -u +%F)`; refuses if it exists. Single-file, no sort.
- `automation/jobs/digest-public.py:238,311-312`: links to a single
  `docs/journal/<date>.md`; its own `sorted(glob...)` at line 106 is over
  hngh-home data files, not journals.
- Ledger sync (`automation/cadence/hour/30-kernel-ledger-sync.sh:33`):
  lists `docs/journal` as a sync surface, no glob.
- Git-path watchlists (`scripts/run-autonomous:121`,
  `automation/jobs/oversight-tick.sh:121`): whole-prefix match, no sort.

## Verdict

- Sort order: **lexicographic, which equals chronological ascending
  (oldest-first) for `YYYY-MM-DD.md` names**.
- Convention per consumer: oldest-first / newest-last everywhere order
  matters; the only order-reliant consumer is generate-publication
  `chapter_documents` (`scripts/generate-publication:592`), which matches
  the README contract. No consumer requests newest-first; none reverses the
  sort. Nothing to fix.

## Key refs

- `docs/journal/README.md:3` -- newest-last contract.
- `scripts/generate-publication:588-592` -- glob + `sorted(matched)`, only
  order-reliant consumer.
- `scripts/run-autonomous:66-79,95,101` -- single-date, no enumeration.
- `automation/jobs/daily-writeups.sh:32` -- single-date write.
- `automation/jobs/digest-public.py:238,311-312` -- single-date links.
