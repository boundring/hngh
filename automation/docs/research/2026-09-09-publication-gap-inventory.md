# Publication --site run output and gap inventory (2026-09-09)

Status: RECORD

Plan step: `prompts/overnight/2026-09-03-staging.md` step 5 (GROW —
publications pipeline --site increment).

## The --site run

Rerun this date from the automation repo:

    HNGH_PUB_ROOT=/tmp/pub-temp python3 scripts/generate-publication --site
    # exit 0; "site index -> /tmp/pub-temp/docs/site/index.html"

Output inventory:

- `/tmp/pub-temp/docs/site/index.html` — 27,378 bytes, single static page,
  no auxiliary files (no CSS file, no assets, no manifest).
- Consumed exactly the hard-coded 7-file contract in
  `scripts/generate-publication` (`EBOOK_FILES`): the five 2026-09-01
  docs/research line docs plus `research-lines.tsv` and
  `research-subjects.txt`. No "skipping missing" warnings — all 7 exist.
- Rendered sections: Session cost model, Notification channel survey,
  Local-model benchmark loop, Arbitrary request scheduling, Roguelike
  pattern design, The research lines, The research subjects.
- Note: a separate 7,519-byte `index.html` sits at `/tmp/pub-temp/index.html`
  (generated 2026-09-09 ~19:08); it is the hngh dashboard snapshot, not
  this script's output. The script writes to
  `$HNGH_PUB_ROOT/docs/site/index.html`.

Build artifacts land only in the throwaway temp dir; nothing is committed.

## Gap inventory vs the research-lines surface

What the site lacks before it is a public surface (per the backlog
public-surface row, restated in staging step 5):

1. **Stale corpus contract.** The hard-coded 7-file list is already
   behind the corpus: 3 of 8 docs/research docs are missing
   (2026-09-02-biographic-cadence-design.md,
   2026-09-07-identifier-lint-design.md,
   2026-09-09-stage23-exit-criteria-sweep.md). The publication-lines-
   contract backlog decision (research-lines.tsv drives the corpus)
   is still unwired.
2. **Line coverage: 7 of 38.** `research-lines.tsv` carries 38 lines;
   the site represents 5 of them (as prose docs) and merely dumps the
   TSV/subjects manifests. 31 lines — including the whole govbench-*
   and ctx-* families and the cistern reviews — have no surface at all.
3. **No disposition layer.** `research-dispositions.tsv` (adopted /
   parked / killed verdicts, e.g. the killed self-funding-publications
   line) is not consumed; the site can present dead lines as live.
4. **No navigation or metadata.** One flat page: no TOC, no per-doc
   anchors/links, no dates or line ids, no attribution. Not navigable
   as a "research record".
5. **Markdown renderer is lossy.** `md_to_html` handles only headings,
   bullets, and paragraphs: no tables, code blocks, inline code/bold/
   links. The TSVs render as paragraph soup.
6. **No publish path.** No hosting/deployment target, no robots/llms.txt,
   no rebuild trigger; the artifact exists only as a local temp file by
   design. "Public surface" currently means "a file on disk".
7. **No verification hook.** Nothing checks the built HTML against the
   corpus (a stale-list regression like gap 1 is silent).

Items 1 and 3 gate everything else: until the corpus is manifest-driven
and dispositions are consumed, any published site misrepresents the
research record. Items 4-5 are presentation debt; 6-7 are process debt.

## Verification

- `--site` run exit 0 into `/tmp/pub-temp` (throwaway pub root).
- `git status` shows no committed publication artifacts — only the
  untracked `docs/research/2026-09-09-publication-gap-inventory.md`
  (this note) and unrelated in-flight work; no `docs/site/`, no
  `docs/journal/`, no build output in the tree.
