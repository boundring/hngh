# Research harvest organ (d1-harvest) — 2026-09-15

Machine session record (jcode deep task graph node `d1-harvest`, swarm
lane `session_dolphin_1789472126868_b6fe1d64bcfa1dc6`). Free-commit
automation lane; coordinator commits. No kernel `src/`, `tests/`,
`Makefile`, or `hngh.asd` touched.

## Problem

The lifecycle audit (`.agent-scratch/consider/research-lifecycle.md`)
proved the research pipeline circular, never cumulative: 73 adopted
dispositions sat in `automation/research-dispositions.tsv` verdict
columns that nothing consumed — 0 of 73 fed any runtime decision. The
one onward motion was follow-on subjects re-entering the same loop.

## Change

- `automation/lib/research-harvest.py` (new): when a disposition lands
  `action=adopted`, condense the verdict reason into ONE actionable
  lesson row in `automation/research-lessons.tsv` — schema
  `lesson_id | date (ISO Z) | line_id | subject | lesson | status`,
  `lesson_id = les-<yyyymmdd>-<line_id>`. Keyed by `line_id`: a
  re-adoption REFRESHES the row (new date + lesson, never duplicates),
  a later non-adopted disposition retires the row
  (`status=retired`), and an unchanged rerun is a no-op.
- Wiki destination: the vault ingestion contract WAS determinable from
  local tooling (blocker not filed): `WIKI_SCHEMA.md` page types +
  ownership rules, the `SRC-*` source pages (`type: source` frontmatter
  with title/source_id/captured/file_path/tags), and — decisive —
  `concepts/hngh-lessons-current`, a page hngh's own Monday seed
  (25-wiki-health.sh) wrote into `wiki/`, present in the extension's
  `meta/registry.json` and `meta/index.md`. So hngh-written `wiki/`
  pages are indexed by the extension's `wiki_rebuild_meta` rebuild.
  The harvest appends `wiki/sources/LES-<line_id>.md` in exactly that
  shape; `meta/` and `raw/` are never touched (vault ownership rules).
  Vault absent → lessons TSV alone lands.
- Beat wiring: `cadence/hour/33-research-beat.sh` review transition
  calls the harvest right after the disposition row lands and before
  `set_state reviewed`; the lessons TSV joins the review's
  commit-per-op path list. Fail-closed: malformed disposition input
  exits non-zero writing nothing; the disposition itself was already
  recorded, so the beat files a `research-beat:harvest-failed` alert
  instead of losing the verdict.
- Backfill semantics: running the harvest against the existing
  dispositions file yields one lesson per historically adopted line on
  first beat run (no separate backfill needed; rows carry today's
  harvest date, not their original verdict date).

## Verification

- `automation/tests/test-research-harvest.py` (new, hermetic, 9
  scenarios: harvest-on-adopted shape, non-adopted ignored,
  refresh-not-duplicate, idempotent rerun, multi-line, wiki page shape
  + in-place refresh, absent-vault degradation, fail-closed on header
  drift / short rows, fallback lesson sentence). Landed red first
  (FileNotFoundError on the missing lib), green after implementation.
- Wired into `automation/Makefile` `test:` next to the research
  suites; full gate `cd automation && make test` → rc=0 (ALL PASS,
  identifier lint clean), including the pre-existing
  `test-research-review.sh` beat sandbox.
- End-to-end beat proof (scratch harness, repo `tests/stub-lib.sh`
  stub model, `HOME` sandboxed): one crystallized line → stub verdict
  `adopted -- proof verdict...` → disposition row + correct
  `research-lessons.tsv` row in the same beat. The beat's
  `research_commit` declined the sandbox commit (staged-check
  refusal), which is the designed coordinator-vs-beat lane split, not
  a defect.

## Known limits / open questions

- The wiki page is unindexed until the extension's next
  `wiki_rebuild_meta` run; the wiki-health probe flags new pages as
  UNINDEXED and the need-triggered auto-rebuild heals them. Honest,
  pre-existing gap, unchanged by this slice.
- Whether the operator wants harvested lessons surfaced in
  context-pack (audit suggestion 3b: top-N lessons in the research
  index line) — deliberately left out of this slice; consumers can
  read `research-lessons.tsv` today.
