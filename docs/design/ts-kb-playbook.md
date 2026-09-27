# Typesafe knowledge-base playbook (hngh)

What it is, where it lives, and how to query the local Typesafe/Jev
corpus that informs typed calls (course-correction slice 3).

## Shape

One ingest (`automation/scripts/typesafe-docs-ingest.py`) maintains:

- `<home>/db/hngh-knowledge.db` — sqlite: `nodes(id, url UNIQUE, title,
  blurb, path, fetched, content)`, `edges(src, dst, kind)` (markdown
  cross-links between ingested pages), `nodes_fts` (FTS5 over
  title/blurb/content, external-content on `nodes`).
- `<home>/db/typesafe-docs/` — one markdown cache file per page
  (`docs.typesafe.ai__<path>.md`), source of truth for re-ingest.

`<home>` resolves through `lib/hngh_home.py` (`HNGH_HOME_DIR`
override). The corpus is deliberately OUTSIDE the llm-wiki vault:
25-wiki-health counts vault pages and a machine-scraped corpus would
poison its UNINDEXED budget.

## Refresh

Weekly drop-in `automation/cadence/calendar/weekly/03-typesafe-docs-refresh.sh`
re-runs the ingest (llms.txt is the page set, so new upstream pages
arrive automatically), files a `ts-docs-refresh` progress row, and
exits 0 either way (fail-closed: a failed run keeps the previous DB).

Manual: `python3 automation/scripts/typesafe-docs-ingest.py [--core-only]
[--limit N] [--source-dir DIR]`.

## Querying

Probe (`automation/scripts/ts-kb-probe.py`, honors
`HNGH_KNOWLEDGE_DB` override):

    ts-kb-probe.py                          # stats: nodes/edges/stale count
    ts-kb-probe.py --query "fan-out"        # FTS5 top-3 with snippets
    ts-kb-probe.py --related patterns.md    # 1-hop neighbors via edges
    ts-kb-probe.py --live                   # one typed Jev Noul call

Embedding the DB directly (the recommended consumer path):

    -- lexical recall:
    SELECT url, title FROM nodes_fts JOIN nodes ON nodes.id = rowid
    WHERE nodes_fts MATCH ? ORDER BY rank LIMIT k;
    -- graph walk:
    SELECT d.url FROM edges e JOIN nodes d ON d.id = e.dst WHERE e.src = ?;

## Doctrine

The KB is context for typed calls (which primitive to use, which
pattern applies, what confidence means here) — it never decides
anything. Deterministic refusals and the confidence floors in
`lib/typesafe.py` stay authoritative (ceremony doctrine: Jev advises,
never certifies).
