# hist-journal-site-excl: site/ exclusion from the journal glob

## Paths involved

- Journal glob (kernel publication surface): `scripts/generate-publication`
  - Chapter expansion: `chapter_documents()` at
    `scripts/generate-publication:591`:
    `matched.update(p for p in ROOT.glob(pattern) if p.is_file())`
    with documented patterns `docs/journal/*.md`,
    `docs/records/*.md` (`scripts/generate-publication:30`).
  - Ebook output default: `docs/journal/ebook`
    (`scripts/generate-publication:759`, doc at `:20`).
  - Site output default: `docs/site`
    (`scripts/generate-publication:764`, doc at `:38`).
- Automation sibling: `automation/scripts/generate-publication:21` names
  `$HNGH_PUB_ROOT/docs/journal/ebook` as ebook default; `--site`
  defaults to `$HNGH_PUB_ROOT/docs/site` (doc block at :23-26).

## Why docs/site/ is excluded (reason)

- Structural, not an explicit filter. There is no "exclude site/" rule
  anywhere; the exclusion is:
  1. `docs/site` is a sibling of `docs/journal`, not inside it, so any
     `docs/journal/*.md` glob never matches it.
  2. The glob is non-recursive (`*.md`, no `**`), and even if a
     directory matched, `p.is_file()` at `scripts/generate-publication:591`
     drops directories (e.g. `docs/journal/ebook/`).
- Verified on disk: `docs/site/` does not exist in the working tree
  (site builds land there only when `generate-publication --site` runs
  with the default, or via `HNGH_PUB_ROOT` redirection; the automation
  variant's README/doc says point `HNGH_PUB_ROOT` at a temp dir so
  build artifacts are never committed). `docs/journal/ebook/` also
  does not currently exist.

## Leak paths considered

1. `docs/journal/*.md` glob picking up ebook book files: impossible
   today because `--ebook` writes `book.md`/EPUB under
   `docs/journal/ebook/` (subdir), and non-recursive glob +
   `is_file()` keeps subdirs out (`:591`). If someone ran
   `--ebook docs/journal` (flattened), `book.md` WOULD leak into the
   next `--chapters docs/journal/*.md` build and into the daily journal
   enumeration used by feeds.
2. `docs/site/index.html` is `.html`, never matched by `*.md` globs.
   Even a `--chapters 'docs/**/*.md'` misuse would pick up `docs/site`
   only if markdown files were written there; current site output is
   HTML only.
3. Feed layer: `automation/jobs/digest-public.py` references journals by
   exact path (`docs/journal/%s.md`, `:312`, `:238`) - date-addressed,
   no glob over the journal dir, so no leak. Comic glob in the same
   file (`:106`) is `docs/media/manga/*.png`, unrelated.
   `automation/cadence/hour/30-kernel-ledger-sync.sh:33` lists
   `docs/journal` as a surface for ledger sync (directory-wide) - a
   flattened ebook or stray markdown in docs/journal/ would enter this
   sync, but nothing today writes non-date markdown there.

## What the feed layer should guard

- Fail closed on non `YYYY-MM-DD.md` names when enumerating
  `docs/journal/` (current exact-path consumers already comply; the
  directory-wide consumer `30-kernel-ledger-sync.sh:33` is the one to
  watch).
- Keep the invariant that artifact outputs (ebook/, site/) stay in
  subdirs or outside docs/journal/; a cheap guard test asserting
  `ls docs/journal` matches `^[0-9]{4}-[0-9]{2}-[0-9]{2}\.md$` (plus
  the `ebook/` dir) would catch the flattened `--ebook` mistake before
  it feeds dispatch/public surfaces.

## Verification

- `ls docs/site` -> not found; `ls docs/journal` -> only date .md files
  (checked 2026-09-15); `docs/journal/ebook` -> not found.
- Glob semantics read at `scripts/generate-publication:576-592`
  (`chapter_documents`, `is_file` filter) and `:759-764` (defaults).
