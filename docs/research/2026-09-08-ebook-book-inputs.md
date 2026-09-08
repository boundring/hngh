# ebook book-machine inputs: what the royalty-pipeline lane actually still needs

Status: crystallized 2026-09-08 from queue row `ebook-book-inputs`
(`docs/project/backlog.md` line 1496; `docs/project/queue.md` line 42). Builds
directly on `docs/research/2026-08-30-publication-pipeline-grounding.md` (read
first — this doc does not repeat its content); one material fact has changed
since that doc was written, and §1 records it.

---

## 1. The delta that reshapes the input set

The base doc priced option A (`ebook-selection-manifest`) as the next grow
beat. It landed: the current `scripts/generate-publication` (404 lines, read
in full 2026-09-08) now accepts `--chapters GLOB [GLOB ...]` — docstring
contract at lines 23–27 (with `docs/journal/*.md` and `docs/records/*.md`
given as the examples), argparse at line 364, wired into the build at lines
387–389. `chapter_documents()` (lines 276–280) matches repo-relative globs
against the project root, dedups via a set, sorts deterministically, and
titles each chapter by file stem. `build_ebook()` line 286 concatenates it
after the seven fixed docs, so the seven-file front matter contract the base
doc documented still holds (that function is now lines 261–273).

Two consequences, stated plainly:

- The base doc's §1 claim "no selection mechanism of any kind" was true on
  2026-08-31 and is stale today; its line citations (235–247, 295–322) no
  longer match the file. Every script line number in THIS doc comes from
  today's read only.
- The queue row `publication-lines-contract` (queue.md line 41) is closed
  consistent with this: the research-lines side was not wired; a general
  glob selection was.

## 2. The three book-machine inputs, against actual consumption

### (a) chapter/selection input — journal + records seams

Exists today: the glob scan (lines 276–280) accepts exactly the seams the
ebook-longform row names as evidence (`docs/journal/*.md`,
`docs/records/*` — backlog.md lines 498–503). Both seam directories are
populated on disk (journal has day files through 2026-09-07; records has
81 markdown files; see Grounding).

Missing:

1. **No persisted selection.** The seam list lives only in the operator's
   command line each run. The ebook-longform review acceptance is
   `make journal-ebook` producing a deterministic document (backlog.md line
   507); the Makefile has no journal/ebook target of any kind (grep
   2026-09-08: its only publication reference is the test invocation at
   line 21). A one-line make target (or a committed manifest file the mode
   reads when `--chapters` is absent) closes this.
2. **The TOC acceptance still fails structurally.** Selection adds body
   text but the EPUB remains one `chapter.xhtml` (lines 296–298) with one
   navPoint (lines 308–312); "TOC maps the records" cannot hold.
3. **No committed test exercises `--chapters`.** The publication test's
   ebook case calls `build_ebook(td)` with no chapters
   (tests/scripts/test-generate-publication.py lines 65–75).

Price: ~30–45 min (one make target, optionally a manifest fallback read;
script + Makefile only, no kernel sources).

### (b) per-book metadata input (title / author / identifier / keywords)

Exists today: nothing inputtable. The OPF metadata is a hard-coded
f-string — `dc:title` "hngh memoir", `dc:language` en,
`dc:identifier` `urn:hngh:memoir` (lines 299–302) — and the NCX `dtb:uid`
mirrors the same literal (line 310). There is no `dc:creator` (author), no
subject/keywords, no CLI flag, and no metadata file read anywhere in the
source.

Missing: an input path (one flag or one small metadata file) feeding
title/author/identifier/keywords into the OPF and NCX, defaulting to the
current memoir values. This is the base doc's royalty-pipeline gap ("no
author field, no keywords, no per-book metadata input"), unchanged by the
`--chapters` landing.

Price: ~30–45 min (argparse + one read + two f-strings; the whole EPUB is
written inside one function, lines 283–325).

### (c) cover asset path

Exists today: nothing. The OPF manifest lists exactly two items —
`chapter.xhtml` and `toc.ncx` (lines 303–306) — and the spine one itemref
(line 307). No image media-type appears anywhere in the source.

Missing: both halves. The wiring (a cover `<item>` plus its metadata
`<meta name="cover">`) is trivial; the asset is not — no cover image exists
in the repo to point at (see Not established), and a cover is
operator-authored content, not script work.

Price: code ~20–30 min; blocked on an asset that does not yet exist, which
is content work outside this lane's code scope.

## 3. Priced, parseable decision (master-plan §4 gate)

Prices are this beat's estimates from the single-script read in §2; they
are not measured by a run.

```
decision: ebook-book-inputs-next
  gate: research->grow (master-plan section 4)
  basis: scripts/generate-publication source read 2026-09-08 (section 2)
  options (ranked effort-class x unblocking-value):
    - id: B
      name: per-book-metadata-input
      change: title/author/identifier/keywords input (flag or small file)
              feeding the OPF/NCX; memoir values remain the defaults
      price: ~30-45 min (one function's f-strings + one input read)
      unblocks: royalty-pipeline metadata half directly (its builds cannot
                be per-book without it); fully unblocked today
    - id: A
      name: selection-persistence
      change: make journal-ebook target (+ optional manifest fallback when
              --chapters is absent); the scan itself already landed
      price: ~30-45 min; plus the multi-navPoint TOC if the ebook-longform
             acceptance is to be met in the same beat
      unblocks: ebook-longform acceptance; makes the royalty lane repeatable
    - id: C
      name: cover-asset-path
      change: cover item + meta in the OPF, path from metadata input
      price: ~20-30 min code, asset-blocked (no candidate cover exists)
      unblocks: royalty-pipeline cover half; only after B supplies the path
  pick: B
  rationale: A's structural half already landed (only persistence residue
             remains), so B is the smallest entirely-missing input and the
             one no KDP-path book can ship without; C inherits its input
             path from B and is blocked on content regardless
  alternation: next beat is grow (B); research resumes when B lands, with
               the TOC restructure (A's second half) as the next design
```

## Not established

- **Any revenue, royalty, or KDP behavior.** No source read this beat
  produces, invokes, or validates a KDP submission or tracks income; the
  exact metadata fields KDP mandates (and whether `urn:hngh:memoir`-style
  identifiers satisfy them) are unknown here. The royalty row itself marks
  royalties speculative (backlog.md line 557).
- **The PDF path.** The row wants PDF builds (backlog.md line 553); no
  read source contains or references one.
- **mobi/pandoc toolchain availability** in the environment: not checked,
  not asserted (the current EPUB is stdlib-only by construction).
- **The prose machine** (outline → draft → edit): the publication script
  contains none of it (verified by read); what would author marketable
  books is an open design the book-machine inputs do not address.
- **A cover asset.** No candidate image was located in the repo this beat;
  what would serve is undecided.
- **A live `--ebook` run.** Not performed this beat (kernel-repo write
  hygiene; the review acceptance belongs to the grow beat). All behavior
  claims above are source-read plus the committed smoke test.

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the
next certificate ceremony and is landed by the orchestrator (no machine
git operations in the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` (or `test -x` for executables) on
2026-09-08 from the kernel repo root; results recorded verbatim:

- `test -x scripts/generate-publication` → exit 0 (source read in full,
  404 lines).
- `test -f docs/research/2026-08-30-publication-pipeline-grounding.md`
  → exit 0 (base doc, read in full this session).
- `test -f tests/scripts/test-generate-publication.py` → exit 0 (read;
  ebook case lines 65–75).
- `test -f docs/project/backlog.md` → exit 0 (ebook-book-inputs row read
  at lines 1496–1509; ebook-longform row at lines 493–508; royalty-pipeline
  row at lines 547–561).
- `test -f docs/project/queue.md` → exit 0 (line 42: `ebook-book-inputs
  queued`; line 41: `publication-lines-contract done`).
- `test -f docs/project/master-plan.md` → exit 0 (cited for the §4 gate,
  as in the base doc).
- `test -f docs/journal/2026-09-07.md` → exit 0 (newest journal seam file;
  seam population verified by directory listing: 14 day files 2026-08-25
  through 2026-09-07).
- `test -f docs/records/2026-09-07-automation-subtree-import.md` → exit 0
  (newest record seam file; 81 record files verified by directory listing,
  oldest 2026-08-11-crystallized-cutover.md).
- Makefile grep (2026-09-08): no `journal`/`ebook`/`publication` target
  other than the test invocation at line 21 — evidence for §2(a) item 1.
