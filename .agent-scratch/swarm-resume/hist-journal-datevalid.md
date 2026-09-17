# hist-journal-datevalid: date validation for the journal glob

Scope: which entry points validate the journal date argument
(`scripts/generate-publication`), what invalid dates do, and what the
feed layer should assume. Companion to hist-journal-glob.md.

## The single validation point

`day_bounds()` at scripts/generate-publication:97-100 is the only
calendrical validator on the journal path:

```python
def day_bounds(day):
    start = datetime.strptime(day, "%Y-%m-%d")
    end = start + timedelta(days=1)
    return (start.strftime("%Y-%m-%d"), end.strftime("%Y-%m-%d"))
```

Called by `day_commits()` at :103-106, which feeds `--since/--until`
into `git log`. Because `day_commits` sits inside `day_stats`
(:131-135), which is called by `build_journal` (:396-399) and
`check_day` (:468-474), BOTH `--daily` and `--check` inherit the
strptime validation. The dispatch section (`dispatch_numbers`,
:138+) is fail-open, so even if its feeds skip validation the
journal build still gates on day_bounds first via day_stats.

## Observed strptime semantics (verified by execution, 2026-09-15)

- `2026-02-30` -> ValueError: day out of range for month 2 (non-leap)
- `2026-13-01` -> ValueError: month 13 does not match `%m`
- `2026-02-29` -> rejected (2026 not a leap year); `2024-02-29` accepted
  (proper leap/calendrical handling; also 2000-style century rules via
  the stdlib calendar)
- `2026-2-3` -> ACCEPTED and normalized to `2026-02-03` (strptime is
  lenient about zero padding; `%d`/`%m` accept 1-2 digits). This
  matches the sibling finding: non-padded dates are accepted, not
  rejected.

So: structurally malformed or calendrically impossible dates fail
closed with an uncaught ValueError traceback; sloppily formatted but
calendrically valid dates are silently normalized. There is no
explicit filename-level or regex-level validation of the `day`
argument anywhere (argparse at :730 takes it as bare `nargs="?"`,
:732 defaults it to today UTC).

## Behavior per entry point

- `--daily [DATE]` (main at :739-751): build_journal -> day_stats ->
  day_commits -> day_bounds. Invalid date raises ValueError before
  any file is written; journal_path (:446-447, `docs/journal/{day}.md`)
  is never reached with an invalid date. A normalized non-padded date
  (e.g. `2026-2-3`) writes `docs/journal/2026-02-03.md` -- a different
  filename than the raw argument.
- `--check [DATE]` (:468-491): same chain via day_stats, so invalid
  dates raise before the count comparison. Note check_day reads the
  journal file (:469-473) AFTER day_stats, so the validation order is
  stats-first, file-second.
- `--ebook --chapters 'docs/journal/*.md'` (:591, chapter_documents):
  pure filesystem glob, NO date validation at all. Any file matching
  the glob becomes a chapter regardless of whether its stem is a real
  date; `2026-02-30.md` on disk would be included verbatim.
- Feed layer (automation/jobs/digest-public.py, digest-html.py,
  newspaper-edition.py): these use `datetime.now()` / strftime for
  the CURRENT date only (newspaper-edition.py:114,156) or glob media
  patterns (digest-public.py:106-108); none parse a user-supplied
  journal date, so none perform date validation. They never emit a
  journal filename, so invalid dates cannot enter the journal tree
  through them.

## What the feed layer should assume

- Assume the journal date is only ever produced by
  `date -u +%Y-%m-%d`-style generation or by day_bounds-normalized
  strptime output: always zero-padded `YYYY-MM-DD`, always a real
  Gregorian date. Padding leniency is an implementation detail of
  strptime, not a contract; downstream consumers should not rely on
  non-padded input being accepted.
- Assume NO filename-level validation exists for anything already on
  disk under docs/journal/: the ebook glob path and any external
  reader of `docs/journal/*.md` will pick up a `2026-02-30.md` if one
  were ever committed manually. Consumers that care must validate the
  stem themselves.
- Failure mode for bad CLI dates is an uncaught ValueError traceback
  (non-zero exit via exception), not a clean refusal message; this is
  fail-closed but not user-friendly.

## Summary table

| Entry point | Validation | 2026-02-30 | 2026-13-01 | 2026-2-3 |
|---|---|---|---|---|
| `--daily DATE` | day_bounds strptime (:97-100) | ValueError, nothing written | ValueError | writes 2026-02-03.md |
| `--check DATE` | same via day_stats (:474) | ValueError | ValueError | checks 2026-02-03.md |
| `--chapters` glob (:591) | none | included if file exists | included if exists | included if exists |
| feed layer jobs | none (never parse a date arg) | n/a | n/a | n/a |
