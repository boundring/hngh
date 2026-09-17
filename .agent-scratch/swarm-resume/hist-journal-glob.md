# hist-journal-glob: journal/ file glob, exclusions, sort order, date validation

Read-only exploration of how `docs/journal/` files are globbed, sorted,
excluded, and date-validated across the hngh repo.

## Naming and location (see also hist-journal-location.md)

- Journal files are `docs/journal/YYYY-MM-DD.md`, one per day, newest last
  (`docs/journal/README.md`: "Dated working entries (`YYYY-MM-DD.md`), one
  per day, newest last").
- Canonical path builder: `journal_path(day)` in `scripts/generate-publication:446-447`
  returns `JOURNAL_DIR / f"{day}.md"` with `JOURNAL_DIR = ROOT / "docs" / "journal"`
  (line 61).
- The only non-dated file present is `docs/journal/README.md`. Date files
  observed run `2026-08-25.md` through `2026-09-15.md` (23 files).

## Glob and sort order

- There is no glob that enumerates journals in kernel code. Consumers take an
  explicit date and construct the path; nothing iterates the directory.
- The `--chapters GLOB...` option (`scripts/generate-publication`, argparse
  line 725, help lines 27-31) is caller-supplied, e.g.
  `--chapters 'docs/journal/*.md' 'docs/records/*.md'`. Resolution is
  `chapter_documents()` (lines 588-592):
  - matches `ROOT.glob(pattern)` per pattern, keeps only `p.is_file()`
    (directories excluded automatically),
  - deduplicates into a `set`,
  - returns chapters `sorted(matched)` by full path -> **lexicographic sort,
    which for `YYYY-MM-DD.md` equals chronological ascending (oldest first)**.
    Chapter titles are the file stem.
- Sort caveat: `README.md` would sort between dates lexicographically
  ("R" < digits), so a naive `'docs/journal/*.md'` chapter glob would include
  it; date files themselves sort correctly. `ebook/` and `site/` subdirectories
  are excluded by `is_file()` filtering (directories are skipped, and
  `docs/journal/ebook/book.md` etc. would not match `*.md` at the top level
  anyway since `glob('*.md')` is non-recursive). No explicit exclusion list
  exists; exclusion is structural (non-recursive glob + is_file).

## Date validation

- `generate-publication --daily|--check [DATE]`: `day = args.day or
  datetime.now(timezone.utc).strftime("%Y-%m-%d")` (UTC, not local).
  Validation is implicit: `day_bounds()` (lines 97-100) calls
  `datetime.strptime(day, "%Y-%m-%d")`, which raises `ValueError` on malformed
  dates; `main` catches `ValueError` and exits non-zero. `strptime` with
  `%Y-%m-%d` rejects wrong shapes but accepts non-zero-padded forms like
  `2026-9-5` (no fullmatch regex is enforced).
- `scripts/run-autonomous.py` `journal_day()` (lines 67-79): journal day is
  the PREVIOUS day (a 00:00Z first-tick generation snapshot zero counters;
  2026-08-27 incident noted in the docstring). It truncates `day[:10]`,
  parses with `strptime`, and on `ValueError` falls back to today-1 in UTC.
- `automation/jobs/daily-writeups.sh` uses `day=$(date -u +%F)` (UTC) and
  writes `"$KERNEL/docs/journal/$day.md"`, refusing if the journal exists
  (operator-authored journals never touched; `--force` drift-refresh only
  for machine-generated ones).
- No file-name-level validation exists anywhere: a stray `foo.md` in
  `docs/journal/` would not fail anything, it would simply never be selected
  by date-keyed consumers and would sort oddly in a `--chapters` glob.
  Fail-closed behavior is on the date ARGUMENT, not on directory contents.

## Exclusions of ebook/ and site/

- `--ebook [DIR]` default output `docs/journal/ebook` (book.md + epub) and
  `--site [DIR]` default `docs/site` are OUTPUT locations nested near/inside
  the journal tree. They are never inputs to any journal enumeration; the
  only journal enumeration surface is the caller-supplied `--chapters` glob,
  which is non-recursive and file-only, so `docs/journal/ebook/*` is excluded
  in practice.
- `docs/site/` lives outside `docs/journal/` entirely.

## Related surfaces

- Dispatch/publication links hardcode `docs/journal/<date>.md` as relative
  links (`digest-public.py:238,312`; README dispatch block,
  `automation/tests/test-dispatch.sh` asserts the link pattern).
- Git-path watchlists reference `docs/journal/` as a whole prefix
  (`scripts/run-autonomous:121`, `automation/jobs/oversight-tick.sh:121`),
  so any file under the directory is treated as kernel-ledger surface.
- Ledger sync (`automation/cadence/hour/30-kernel-ledger-sync.sh`) lists
  `docs/journal` in `surfaces=(docs/journal docs/project docs/design
  docs/research)` without a glob.

## Key file:line references

- `scripts/generate-publication:61` JOURNAL_DIR; `:446` journal_path;
  `:97-100` day_bounds strptime; `:588-592` chapter_documents glob+sort;
  `:740-748` --daily exists/refuse; `:757-765` ebook/site outputs.
- `scripts/run-autonomous.py:66-79` journal_day (previous day, ValueError
  fallback); `:94-95` journal_exists.
- `automation/jobs/daily-writeups.sh:32-46` UTC date, exists refusal.
- `docs/journal/README.md` naming contract (YYYY-MM-DD.md, newest last).
