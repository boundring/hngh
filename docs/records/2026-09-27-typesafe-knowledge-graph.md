# Typesafe docs knowledge graph (slice 3)

Date: 2026-09-27. Course-correction slice 3
(local://hngh-course-correction-plan.md).

## What landed

- `automation/scripts/typesafe-docs-ingest.py` — pulls the Typesafe docs
  index (`https://docs.typesafe.ai/llms.txt`), caches every page as
  markdown under `<home>/db/typesafe-docs/`, and builds
  `<home>/db/hngh-knowledge.db`: `nodes` (one row per page, external
  content), `edges` (cross-references, kind `link`), and `nodes_fts`
  (FTS5 over title/blurb/content). The page set IS llms.txt, so new
  upstream pages arrive on refresh without code changes. Scope note:
  the plan sketched ~24 hand-picked URLs; the shipped implementation
  ingests the full llms.txt index (111 pages, ~2 MB) — same DB shape,
  strictly more recall, one less hardcoded list.
- `automation/scripts/ts-kb-probe.py` — stats / FTS query / 1-hop walk
  / `--live` typed Jev Noul probe (fail-closed without
  `TYPESAFE_API_KEY`).
- `automation/cadence/calendar/weekly/03-typesafe-docs-refresh.sh` —
  weekly refresh drop-in: runs the ingest, files one `ts-docs-refresh`
  progress row, exits 0 on every path (fail-closed: failed run keeps
  the previous DB).
- `docs/design/ts-kb-playbook.md` — consumer playbook (DB-shape
  queries are the recommended integration path).

## Corpus facts learned while wiring

- The `.md` endpoints serve the docs site SOURCE (MDX with JS
  components), not clean markdown; in-content cross-links are a mix of
  markdown `[]()` and (rare) static `href="..."`. Navigation between
  pages is mostly client-side, so edges carry real content references
  (300 edges over 111 nodes) but are not a full sitemap.
- Link targets are largely extension-less (`/concepts/system-one`);
  edge resolution aliases with `.md` to match llms.txt URLs.
- The DB deliberately lives OUTSIDE the llm-wiki vault
  (`<home>/db/`, per the two-home layout contract): 25-wiki-health
  counts vault pages, and a machine-scraped corpus would poison its
  UNINDEXED budget. Registered in `catalog.tsv` via
  `lib/hngh_home.py catalog()`.

## Doctrine

The KB is context for typed calls — which primitive fits, which
pattern applies — never a decider. Confidence floors in
`lib/typesafe.py` stay authoritative (Jev advises, never certifies).

## Verification

- `automation/tests/test-typesafe-docs-ingest.py` (new, 6/6): hermetic
  `--source-dir` fixtures — node/edge construction (absolute,
  site-relative, and `.md`-aliased targets), FTS recall, idempotent
  re-ingest, `--limit` cap, all-failed exit 1, catalog row, probe
  fail-closed exit 2 on missing DB.
- Live: full ingest 111 nodes / 300 edges / 0 failed; probe `--query`,
  `--related`, and `--live` exercised (`live: noul=0.27` — seam works;
  the Noul's low score on the sufficiency question is the honest
  advisory answer, not a failure).
- Weekly drop-in smoke in a sandboxed HNGH_HOME: ingest ran, report row
  filed with the ingest summary.
