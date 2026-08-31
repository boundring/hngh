# publication pipeline grounding: what `generate-publication` actually consumes

Status: crystallized 2026-08-31 (authored 2026-08-31; filename dated 2026-08-30 per the
2026-08-30 evening selfdev plan's naming mandate) from the plan beat
`publication-pipeline-grounding`; companion material lives in
hngh-automation digest/RESEARCH-BEAT-*-self-funding-paths-publications-ebook-site-operator-runway.md.

---

## 1. What `--ebook` consumes

Source read: `scripts/generate-publication` (executable, `test -x` verified 2026-08-31).
The `--ebook [DIR]` mode (`ebook_documents()`, lines 235–247; `build_ebook()`, lines
250–292) reads a **fixed, hard-coded list of seven files**, each included only
`if path.exists()`:

1. `docs/intent.md`
2. `docs/architecture.md`
3. `docs/project/roadmap.md`
4. `docs/project/decisions.md`
5. `docs/project/backlog.md`
6. `docs/project/queue.md`
7. `README.md`

Verified to exist on disk 2026-08-31: all seven (see Grounding).

What `--ebook` does **not** consume:

- **No `docs/research/` selection mechanism of any kind.** The script source contains
  no reference to `docs/research/`, to a manifest file, or to any selection input;
  the corpus is the seven literals above, in code order.
- **No research-lines manifest.** `~/Projects/etc/hngh-automation/research-lines.tsv`
  exists (verified 2026-08-31) and is the automation repo's research-line ledger, but
  `scripts/generate-publication` never opens it, never references it, and has no
  cross-repository read path (its only root is `HNGH_PUB_ROOT` or the script's own
  parent, line 42–43). The claim "the ebook rides the research-lines manifest" is
  **not established** — it is false against the source.
- **No journal or record input.** `docs/journal/*.md` and `docs/records/*` are not
  read by `--ebook` (they are read only by the separate `--daily`/`--check` modes,
  which consume git log, `docs/project/checkin.md`, and `docs/project/timeline.md`).

Output of `--ebook`: `docs/journal/ebook/book.md` plus `hngh-memoir.epub` — a
stdlib-`zipfile` EPUB 2 with a **single** `chapter.xhtml` and a TOC.ncx carrying
**one** navPoint. Chapter order and titles are fixed in code.

## 2. What `--site` consumes

The `--site [DIR]` mode (`build_site()`, lines 295–322) is a thin shell: it imports
`scripts/dashboard-readout` as a module, calls `data_spine()` + `render_html(data)`,
appends a "leaderboard (timeline density)" table computed from the timeline rows, and
writes exactly one file: `docs/site/index.html`.

`scripts/dashboard-readout` (read 2026-08-31) `data_spine()` (line 290) consumes:

- `docs/project/timeline.md` — 4-column TSV rows, kinds `done`/`event`/`rotation`
  (`timeline_rows()`, line 101);
- `docs/project/queue.md` — 4-column TSV rows, statuses `queued`/`done`/`active`
  (`queue_items()`, line 110), plus the last `## ETA` section (`queue_etas()`,
  line 488);
- live, non-committed sources rendered read-only: session stores under
  `~/.hngh-automation/store` with a `record.lisp` (`session_rows()`, line 155) and
  rosters from `/tmp/hngh-heartbeat-*`, `/tmp/hngh-auto-*`, and the automation store
  (`_roster_sources()`, line 205).

So the public site today is the dashboard spine (timeline + queue + ETAs + live
sessions) plus a leaderboard, as one static HTML file. It is not a multi-page site,
has no journal feed, no comment intake, and no pricing surface.

## 3. The four self-funding backlog rows, given what the pipeline consumes today

Read source: `docs/project/backlog.md` lines ~448–525 (read 2026-08-31).

### ebook-longform ("Long-form ebook: the megastructure memoir")

Row wants: a `make journal` pipeline assembling the **day-by-day journal + key
records + the vision** into one long-form document, Markdown → epub/mobi, with a
review acceptance of a deterministic document "whose TOC maps the records".

Gap against actual consumption: today's `--ebook` assembles only the seven fixed
governance docs; it reads **no** journal day files and **no** records, so the row's
core content source is not wired in. The TOC acceptance also fails structurally
(single navPoint, fixed chapter list). What it needs next is **not** a pandoc step
first — it is a chapter-selection input: an explicit list (manifest or directory
scan) of `docs/journal/*.md` and `docs/records/*` seams fed into
`ebook_documents()`. Once selection exists, a mobi/pandoc step is a separate,
optional rung.

### public-surface ("Self-hosted public surface")

Row wants: journal posts, moderated comment intake, a public queue readout, and an
instances leaderboard, self-hosted on a budget VPS.

Gap against actual consumption: `--site` already produces the public readout and the
leaderboard (as one static file) — that part is genuinely served by today's
pipeline. The missing halves are (a) a **journal feed** — `--daily` writes
`docs/journal/YYYY-MM-DD.md`, but `--site` never reads that directory; and (b) a
**moderated intake**, which no publication script touches today and which is a new
surface (server + moderation policy), not an extension of a read-only assembler.
Next need: extend `--site`'s output set beyond one file (journal index) and scope
the intake as its own rung with its moderation/rate-limit review trigger first.

### royalty-pipeline ("Self-publishing / royalties pipeline")

Row wants: a repeatable "book machine" (outline → draft → edit → cover → metadata)
driving PDF/epub builds for KDP + direct sale.

Gap against actual consumption: everything the book machine needs above raw prose is
absent from the pipeline today. The only epub produced is the memoir with hard-coded
metadata (`dc:title` "hngh memoir", `dc:identifier` `urn:hngh:memoir`) — no author
field, no keywords, no cover image, no per-book metadata input, no PDF path. The
row itself names its dependency: "the longform assembler". Next need: the
ebook-longform selection mechanism first (shared prerequisite), then a metadata +
cover step; the prose generation pipeline (outline→draft→edit) is a separate machine
the publication script neither contains nor consumes.

### funding-rails ("Funding rails — bootstrap income")

Row wants: Shieldz + asterpay intake stood up, a `pricing` page stub, and the rails
documented in the site.

Gap against actual consumption: `--site` writes exactly one file (`index.html`) with
no pricing content and no payment references; the row's dependency is "the
public-site rung". Next need, minimal: a second output page (pricing stub) from the
same mode, and the rails documentation riding that page. The payment rails
themselves (Shieldz/asterpay, x402 wallet) are outside the publication pipeline
entirely — this beat makes no claim about them (see Not established).

## 4. Priced, parseable decision (master-plan §4 gate)

Per `docs/project/master-plan.md` §4: research→grow when the artifact is a priced,
parseable decision. Prices below are this beat's estimates from the single-script
scope read in §1–§2; they are not measured by a run.

```
decision: publication-pipeline-next
  gate: research->grow (master-plan section 4)
  basis: scripts/generate-publication source read 2026-08-31 (sections 1-2)
  options:
    - id: A
      name: ebook-selection-manifest
      change: feed docs/journal/*.md + docs/records/* into --ebook via an explicit
              chapter selection input; keep the seven fixed docs as front matter
      price: 1 grow slice (one mode of one script; no kernel files)
      unblocks: ebook-longform, royalty-pipeline (both name the assembler)
    - id: B
      name: site-second-pages
      change: --site emits a pricing stub page + journal index alongside index.html
      price: 2 grow slices (new output set + journal read; intake excluded)
      unblocks: funding-rails (partial), public-surface (partial)
    - id: C
      name: book-machine
      change: outline->draft->edit->cover->metadata prose pipeline + KDP builds
      price: unpriced (multi-component; blocked on A for the build half)
      blocked_on: A
  pick: A
  rationale: lowest price; named dependency of two backlog rows; B and C inherit
             their build half from A; today's pipeline is one mode edit away
  alternation: next beat is grow (A); research resumes when A lands, with the
               public-surface hosting/moderation design as the next missing design
```

The alternation follows §4's rule directly: no grow run in the publication lane is
blocked today (the pipeline exists and runs), so research yields to a grow beat
carrying option A, and returns only when the next missing design (hosting +
moderated intake for public-surface) is on the table.

## Not established

- Any revenue, royalty, payment-rail, or runway behavior: nothing in the read
  sources produces or tracks income. The prior beat
  (`docs/research/2026-08-31-self-funding-paths-publications-ebook-site-operator-runway.md`,
  untracked) reached the same conclusion from its own evidence basis and defined
  "operator runway" as a working term only; this beat adds no claim there.
- Whether a pandoc/mobi toolchain exists in the environment: not checked, not
  asserted (the current epub is stdlib-only by construction).
- Deployment of `docs/site/index.html` to any host: no read source mentions hosting.

## Batched landing

This doc is an uncommitted working-tree research artifact; it rides the next
certificate ceremony and is landed by the orchestrator (no machine git operations
in the kernel repo). No code was written in this beat.

## Grounding

All paths verified with `test -f` (or `test -x` for the script) on 2026-08-31:

- `scripts/generate-publication` — `test -x` passed; source read in full (369 lines).
  `--ebook` inputs: fixed seven-file list, lines 235–247; no manifest/research
  selection anywhere in source. `--site` mechanics: lines 295–322.
- `scripts/dashboard-readout` — read; `data_spine()` line 290, `timeline_rows()`
  line 101, `queue_items()` line 110, `queue_etas()` line 488, `session_rows()`
  line 155, `_roster_sources()` line 205.
- `docs/intent.md` — `test -f` passed (`--ebook` input 1).
- `docs/architecture.md` — `test -f` passed (`--ebook` input 2).
- `docs/project/roadmap.md` — `test -f` passed (`--ebook` input 3).
- `docs/project/decisions.md` — `test -f` passed (`--ebook` input 4).
- `docs/project/backlog.md` — `test -f` passed (`--ebook` input 5; also the four
  self-funding rows read, lines ~448–525).
- `docs/project/queue.md` — `test -f` passed (`--ebook` input 6; `--site` queue
  source via dashboard-readout).
- `README.md` — `test -f` passed (`--ebook` input 7).
- `docs/project/timeline.md` — `test -f` passed (`--site` spine source; `--daily`
  input).
- `docs/project/checkin.md` — `test -f` passed (`--daily`/`--check` input).
- `docs/project/master-plan.md` — `test -f` passed; §4 read in full (lines 63–82).
- `docs/research/2026-08-31-self-funding-paths-publications-ebook-site-operator-runway.md`
  — `test -f` passed (untracked prior-beat record; read, cited, not modified).
- `~/Projects/etc/hngh-automation/digest/RESEARCH-BEAT-2026-08-31-self-funding-paths-publications-ebook-site-operator-runway.md`
  — `test -f` passed (untracked prior-beat digest; read, cited, not modified).
- `~/Projects/etc/hngh-automation/research-lines.tsv` — `test -f`
  passed; inspected head (3 lines). Consumed by the research-lines machinery, **not**
  by `scripts/generate-publication` (verified by full source read).
