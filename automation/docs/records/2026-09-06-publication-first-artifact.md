# 2026-09-06 — Publication pipeline first artifact (2026-09-01 plan step 5)

Status: RECORD

## What ran

`HNGH_PUB_ROOT=$(mktemp -d) python3 scripts/generate-publication --ebook`
from hngh-automation at 2026-09-06T00:16Z — exit 0, no "skipping
missing" on stderr.

## Output inventory (throwaway temp dir, never committed)

- `docs/journal/ebook/book.md` — 17,937 bytes, the 7-file corpus
  concatenated under one title.
- `docs/journal/ebook/hngh-automation-research.epub` — 22,371 bytes;
  `zipfile.testzip()` clean; entries `mimetype`,
  `META-INF/container.xml`, `OEBPS/content.opf`, `OEBPS/toc.ncx`,
  `OEBPS/chapter.xhtml`; chapter body 20,703 bytes; all 7 corpus
  sections present in the chapter (`<h2>` inventory verified:
  Session cost model, Notification channel survey, Local-model
  benchmark loop, Arbitrary request scheduling, Roguelike pattern
  design, The research lines, The research subjects).

## What the pipeline actually consumed

The hard-coded `EBOOK_FILES` list in scripts/generate-publication
(lines 46-58): the five 2026-09-01 docs/research/ line docs plus
`research-lines.tsv` and `research-subjects.txt`. Unlike the hngh
kernel's generate-publication (hard-coded 7-file spine, zero
docs/research/ lines — the grounding note in the 2026-09-01 plan),
this automation-repo variant's list IS the research corpus, so
research output reaches the publication surface.

Gap observed: `docs/research/2026-09-02-biographic-cadence-design.md`
(2d old) is NOT in the list — the corpus has already outgrown the
hard-coded contract. This is the publication-lines-contract backlog
row's decision (queued): whether research-lines.tsv drives the corpus
instead of a hand-maintained list. Not wired here; that decision
belongs to the backlog row.

## Next-needed inputs (ebook-longform / ebook-book-inputs backlog rows)

The current artifact is a concatenated research volume — a single-
chapter EPUB, not a book. The book-machine inputs still needed:

1. Outline: a curated chapter structure (one chapter per research
   line) instead of one monolithic chapter.xhtml.
2. Metadata: title/author/cover/date front matter beyond the minimal
   dc:title/dc:language/dc:identifier currently emitted.
3. Manuscript framing: intro/conclusion prose that turns research
   notes into a readable volume.
4. The lines-contract decision above (corpus source of truth).

## Verification state

- Kernel `make test` green at 2026-09-06T00:05Z (2855 checks passed).
- hngh-automation `make test` green at 2026-09-06T00:15Z (commit
  b199eb8, gate-red root-cause fix).
- No publication artifacts committed: build landed only in the
  throwaway temp dir.
