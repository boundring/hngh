# hist-records-index: docs/records/ index rules verification

Verified 2026-09-15, repo ~/Projects/etc/hngh. READ-ONLY.
Builds on siblings hist-records-recency.md (ordering + thin-harvest
policy) and hist-windows-schema.md (merged feed envelope). No repo files
edited; this artifact lives under .agent-scratch/ only. (A concurrent
session had drafted an earlier hist-records-index.md; this resume pass
re-verified everything from the repo and overwrote it. Siblings
hist-records-format.md, rec-readme-rule.md, and records-maint-rule.md
landed concurrently and are cross-referenced below where they agree.)

## 1. README.md currency: which entries are indexed vs anchor-only

docs/records/ holds 140 markdown files: 139 records + README.md (the
index). 139 tracked by git; one untracked working-tree record
(2026-09-13-userspace-home.md, per `git status`).

Indexing state by filename, cross-checked against README.md content:

- **August (dense prose entries):** 53 of 72 records dated 2026-08-* are
  indexed with descriptive bullets. 19 are absent, mostly 2026-08-26
  wave records (fasttest-cache, governance-vocabulary, oversight-tick,
  roguelike-watchdog, omp-bridge, ceremony-profile, architecture-index,
  etc.) plus 2026-08-25-queue-rotation and the 2026-08-30/31 plan
  records. The index ends its prose coverage at 2026-08-30 (last August
  entry: 2026-08-30-lessons-and-foldback).
- **Since 2026-09-01:** 67 records exist dated 2026-09-*. Exactly 4 are
  indexed — the four 2026-09-09 "anchor records":
  1password-service-account-interface, budget-governance-directive,
  operator-flexibility-doctrine, wake-mutation-lane-rotation.
- **Anchor-only format:** unlike August entries (bullet + one-sentence
  description), the four anchors are bare markdown links with no
  description text (README.md lines 170-173), followed by the
  thin-harvest paragraph (lines 175-178): "The harvest from 2026-09-01
  onward is thin here on purpose: recent work-slice facts live closer to
  their surfaces (plan files, reports.md, the changelog). The four
  2026-09-09 rows above are the anchor records the documentation spine
  ties itself to."
- The remaining 63 September records (09-01 through 09-15, including
  all of 09-10..09-15) are deliberately unindexed — consistent with the
  stated policy, not an omission. Sibling hist-records-recency.md
  independently confirmed the same policy text and the ~30 records in
  the 09-13..09-15 window.
- **No dangling references:** every filename the README mentions exists
  on disk (scripted check over all `2026-*-*.md` tokens in README.md).

Provenance: the anchor indexing landed in commit b865330a
(2026-09-12, candidate 49f88915..., the presentation-pass-1 step-2 docs
spine promotion), which added the four links, the thin-harvest
paragraph, and the "Back to the documentation spine" footer. The
overnight lesson log (docs/project/lessons-2026-09-13.md line 64)
confirms: "2026-09-09 anchor records indexed in docs/records/README
(two hops from the spine)".

Reachability rule the anchors serve: docs/README.md line 15 promises
"everything listed here is reachable from the root README in two hops
or fewer." Root README (line ~107) links the records index; the index
links the anchors — two hops. The other 63 September records are NOT
reachable that way; they are findable only by directory listing.

## 2. Missing index.json — confirmed, and it is by design

- There is NO index.json (or any JSON index) for docs/records/ anywhere
  in the repo. The only index.json in the tree is
  `automation/dashboard/kb/index.json`, written by
  `automation/jobs/kb-feed.py` — and it indexes ~/.llm-wiki sources
  (llm-wiki KB snapshot for the dashboard KB tab), NOT docs/records/.
- No script, job, test, Makefile target, or plan file proposes or
  generates a records index.json (grep across automation/, scripts/,
  tests/, docs/, Makefile: zero hits for records + index.json).
- The only machine-readable index consumers of docs/records/ today read
  the directory itself (globs), never an index file:
  - `scripts/generate-publication` `mission_line()` (line ~458):
    `sorted((ROOT / "docs" / "records").glob("*.md"))` — reads each
    file's text hunting for the full candidate hash to title a commit.
    NOTE: this glob MATCHES README.md too (140 files), so the index file
    is scanned as if it were a record; harmless today (README contains
    no candidate hashes) but a real quirk for any future consumer that
    assumes records-only.
  - `scripts/generate-publication` `--chapters 'docs/records/*.md'`
    (see section 3) — same README.md inclusion quirk.
- Consequence for the merged-feed design (hist-windows-schema.md): the
  `records:` source must glob the directory and EXCLUDE README.md
  explicitly (the sibling spec already says "Exclude README.md" in its
  dedup-key table — confirmed necessary because plain `*.md` globs
  include it). There is no JSON index to read instead; a producer must
  list the directory.

## 3. generate-publication glob consumer of docs/records/

Two generate-publication scripts exist; only the KERNEL one consumes
docs/records/:

- **Kernel `scripts/generate-publication`** (780 lines):
  - `--chapters GLOB [GLOB ...]` (docstring lines 27-31, argparse line
    725, `chapter_documents()` lines 588-592): repo-relative globs
    matched against ROOT, deduped via a set, sorted, each chapter titled
    by file stem. The docstring's own example is
    `--chapters 'docs/journal/*.md' 'docs/records/*.md'`.
  - Committed book.md (docs/publication/book.md, last regenerated by
    candidate 6bb8e668 on 2026-09-12) does NOT use the records glob:
    its 176 `##` chapters are the fixed front matter (7 core docs +
    presentation direction + the 4 anchor records pinned by exact path
    in `ebook_documents()` lines 543-554) plus the dated chapters from
    docs/project/decisions.md. Zero `docs/records/*` glob chapters; the
    2026-09-13 userspace record is absent from the book (grep
    "userspace" = 0 hits). So the glob seam exists but the committed
    artifact does not exercise it.
  - Known gaps recorded in docs/research/2026-09-08-ebook-book-inputs.md
    section 2(a): no persisted selection (the seam list lives only in
    the operator's command line; no Makefile journal-ebook target), the
    EPUB TOC acceptance ("TOC maps the records") fails structurally
    (one chapter.xhtml), and NO committed test exercises `--chapters`
    (verified today: grep "chapters" in
    tests/scripts/test-generate-publication.py = 0 hits; the ebook test
    calls build_ebook(td) with no chapters).
  - `mission_line()` is the OTHER records consumer (per-commit
    narrative in --daily journals): O(all-records) file reads per
    candidate commit, README.md included in the scan set.
- **Automation `automation/scripts/generate-publication`** (195 lines):
  hard-coded 7-file EBOOK_FILES list of docs/research/ line docs +
  research-lines.tsv + research-subjects.txt. It never touches
  docs/records/ at all (grep "records" = only prose in the docstring
  about the kernel's version). Its own docstring states the contrast
  explicitly.

## 4. Index maintenance rule

There is NO standing automated index-maintenance rule or gate:

- No test guards the records index. The only link-resolving test,
  automation/tests/test-getting-started-links.py, scans
  docs/getting-started.md alone (its mention of records/README.md is a
  literal test fixture string, not a scan of the index). No
  doc-numbers, loop-history, or other guard touches docs/records/
  README.md completeness.
- The only "rule" text inside the index itself is content-shaped, not
  index-shaped: README.md lines 180-181, "Future records name their
  scope, evidence command, observed result, and remaining unknowns" —
  a record-body format rule (sibling hist-records-format's scope), not
  an update-the-index obligation.
- The maintenance obligation that does exist is distributed, not an
  index-update rule: AGENTS.md:73-75 (commit protocol) requires "docs/
  records are updated" as a condition of every verified commit, and
  AGENTS.md:81 says "Record architecture-relevant work in CHANGELOG.md
  and docs/records/." Neither says the INDEX file must gain a row per
  record — and the thin-harvest paragraph (README.md:175-178)
  affirmatively says recent rows are withheld on purpose. Sibling
  artifact records-maint-rule.md reached the same conclusion
  independently: no single explicit index-update rule exists.
- Empirically the index is updated in explicit docs-pass commits, not
  per record: 30 commits have touched docs/records/README.md; the last
  was b865330a (2026-09-12). Since then 23 records landed
  (09-13..09-15, 22 tracked + 1 untracked) with zero index edits — the
  thin-harvest policy in action. Historical precedent for catch-up
  indexing: 2026-08-25-session.md line ~24 records a consistency pass
  where "the records index gained the missing rung-11..13 entries."
- The two-hop reachability promise (docs/README.md line 15) is the
  closest thing to an implicit maintenance obligation, but nothing
  enforces it for new records; the anchor-only convention (index the
  few records the spine cites, leave the rest to directory order) is
  the de facto rule since 2026-09-12.

## 5. Conclusions for the history spine design

1. A records producer must glob `docs/records/*.md` and exclude
   README.md by name; there is no index.json to consult, and the
   sibling spec's exclusion note is required (globs include the index).
2. README.md is NOT a reliable completeness signal: only 4/67 September
   records and 53/72 August records are indexed. Recency slicing must
   come from the directory listing (ISO-prefix sortable, per sibling
   hist-records-recency), never from the index.
3. The four anchors are the only September records with spine
   guaranteed reachability (two-hop rule); everything else is
   directory-discovered. If the merged feed's `records:` source wants
   "indexed" vs "unindexed" as a display flag, it can test membership
   in README.md's link list — but the flag will be mostly false for
   recent entries, by policy.
4. An index.json for records remains a possible future machine index
   (the kb-feed pattern shows the house style: flat, capped,
   fail-closed, display-only), but nothing today plans it; the merged
   feed should not depend on one existing.

## 6. What I did not check

- Whether docs/publication/hngh-memoir.epub (binary, regenerated
  2026-09-12) matches the committed book.md byte-for-byte; only the
  markdown side was inspected.
- Whether the automation-tier generate-publication's --site output
  embeds any records references (its corpus is research-only; not
  run).
- Whether the 19 unindexed August records were ever indexed and later
  removed, or never indexed (only the 2026-08-25 catch-up note was
  found; full per-file git archaeology not done).
- Whether any consumer outside the repo (llm-wiki harvest, operator
  tooling) reads docs/records/README.md as data.
- Behavior of `--chapters` with overlapping globs in edge cases
  (dedup set handles overlap, but not live-tested here).
