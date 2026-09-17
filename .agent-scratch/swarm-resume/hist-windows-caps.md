# Truncation and cap rules for the recent-history merged feed (hist-windows-caps)

Date: 2026-09-15. READ-ONLY spec, no repo files edited. Builds on
hist-windows-schema.md (envelope + per-source keys), hist-gitlog-dedupfmt-shape.md
(subject length facts), workq-report-shape.md (report sizes).

## 1. Measured volumes (this repo, 2026-09-15)

- gitlog: 1121 commits in last 30 days, 753 in last 7 days (high volume;
  gitlog is by far the dominant source).
- report ledger: 3259 rows total; `first` line is 1-1094 chars, avg 122.
- records: 140 files in `docs/records/` (all-history pool).
- journal: 23 daily files in `docs/journal/` (excluding `ebook/`).
- Max observed git subject: 292 chars (last 500); 0 tabs/newlines.

## 2. Cap design

Two layers: per-source caps bound each producer feed, then a single total
feed cap bounds the merged payload. Per-source caps are applied FIRST
(each source truncates its own list newest-first), then the merged list is
interleaved by `ts` desc and cut to the total cap. Cutting after the merge
(not per source only) is what actually bounds payload size; the per-source
caps guarantee one noisy source cannot starve the others.

| parameter          | value | rationale (measured) |
|--------------------|-------|----------------------|
| gitlog per-source cap    | 200 | 753 commits/7d would dominate; 200 is ~2 working days and keeps gitlog <= 40% of the total cap. Pass `--since` generously (30d) and `-n 200` / truncate after sort; do not narrow `--since` below 7d, since commit density is uneven. |
| report per-source cap    | 50  | Ledger is append-mostly (3259 rows all-history); the 50 newest rows cover the actionable recency window with margin. Skip prune-archived rows before capping (schema sibling §7.6). |
| records per-source cap   | 30  | 140 total files, date-stem timestamps are date-precision; the 30 newest records are the spine-relevant recency band. |
| journal per-source cap   | 14  | Only 23 exist; two weeks of daily files, effectively uncapped in practice. |
| TOTAL feed cap           | 500 | Bound on entries after merge-sort; ~4x the gitlog cap so ordering is genuine `ts` interleave, not a gitlog monoculture. |

## 3. Truncation rules

### 3.1 Entries (list truncation)

- Newest-wins everywhere: truncate each source list AFTER sorting `ts`
  desc (tie-break `key` asc) and keep the head. Never drop the newest
  entries; never interleave-then-drop mid-source.
- The total-cap cut (500) happens after the merged sort, so an old-but-
  sparse source's entries can be displaced by a recent gitlog burst. This
  is intended: the feed is a recency spine, not a balanced census.
- No padding, no backfill: if a source yields fewer than its cap, emit
  what exists. Empty sources contribute zero entries.

### 3.2 `summary` strings

- gitlog: NEVER producer-truncate. Max observed 292 chars is fine for JSON
  and renderers; verbatim subjects are the sibling spec's contract. UTF-8
  preserved (or `json.dumps` default `\uXXXX` escapes, both valid).
- report `first`: truncate to 200 chars ONLY if longer, appending `...`
  (3 ASCII dots, no U+2026). Measured need is rare (avg 122, but max is
  1094). Truncate on a char boundary (Python str slicing is codepoint-
  safe); do not split the ` ×N` dedup marker if present — the marker is
  part of `first`'s tail, and 200 > any observed marker width, so plain
  `first[:200] + "..."` preserves it in practice; if the cut would land
  inside a ` ×N` suffix, cut at its start instead.
- records: `summary` = filename slug (bounded by filename rules, never
  truncate).
- journal: fixed generated summary `"daily journal YYYY-MM-DD"` (schema
  sibling §6), never truncates.
- All `summary` values remain flat strings (validator forbids nested
  content, viz_schema.py:309-322); no "detail body" field exists at
  history/1. Renderers needing full text follow `ref`.

## 4. Truncation markers in the envelope

The history/1 envelope is pinned to exactly two keys (`schema`, `entries`);
unknown envelope keys ERROR (viz_schema.py `_ENVELOPE_FIELDS`). Therefore
NO `truncated: true` flag or `more` marker can be added at history/1.
Signaling options, in order of preference:

1. Preferred: no marker. Consumers infer truncation only via the stable
   caps above (gitlog<=200, report<=50, records<=30, journal<=14, total<=500)
   — caps are deterministic, so "exactly 500 entries" implies a cut.
2. If a marker is later required, it is a schema/2 envelope change (new
   key, e.g. `"truncated": true`), NOT an additive WARN-accepted entry
   field — envelope extras fail closed today.
3. Do not encode truncation as a sentinel entry (e.g. a fake `key`);
   the duplicate/regex key rules would fight it and it pollutes dedup.

For the 200-char `summary` cut on report rows, the `...` suffix IS the
marker (ASCII-only per operator output rules).

## 5. Large-output handling

- Payload size budget: 500 entries x (key ~60B + ts 20B + summary <=300B
  + extras ~60B) ~= 220KB worst case, ~80KB typical. Fine for a local
  JSON file served by the existing readout; no streaming needed.
- Write atomically: build the full payload in memory, validate via
  `viz_schema.py --schema history/1` (flag, not positional — CLI gotcha
  from the gitlog sibling), round-trip `json.loads(json.dumps())`, then
  write once (temp + rename). Never append to a feed file.
- Never let a large source starve validation: cap BEFORE validate.
- `stdout` discipline for producers: do not print entry bodies to logs;
  print only counts (per-source emitted / after-cap), matching the
  patrol/report-queue summary style.
- Missing report sidecars (49 known, all `alert`): still emit the row
  with ledger `first` as summary; `ref` may dangle (report-queue fails
  soft on missing bodies). The cap does not interact with this.

## 6. Interaction with dedup

Caps apply AFTER within-source dedup (dedup keeps the original row per
logical report, per the schema sibling §3), so a ` ×N`-bumped report never
consumes two cap slots. Across the total cap, dedup is by exact `key` and
the validator still fail-closes on any duplicate, so the cap can never
introduce duplicates.

## 7. Constants (proposed, single source of truth)

```
HIST_CAP_GITLOG   = 200
HIST_CAP_REPORT   = 50
HIST_CAP_RECORDS  = 30
HIST_CAP_JOURNAL  = 14
HIST_CAP_TOTAL    = 500
HIST_SUMMARY_MAX  = 200   # report `first` only; suffix "..."
```

Define once in the merged-feed producer module; tests assert each cap
against fixture feeds (construct a source with cap+1 entries, assert cap
survive newest-first).

## 8. What I did not check

- Whether any planned TUI consumer wants a smaller or configurable cap
  (no history consumer exists yet).
- Whether records beyond the 30-newest band need a different window for
  the ebook/publication surfaces (out of spine scope).
- Exact growth rate of the report ledger (3259 rows now) — revisit the
  report cap if pruning policy changes.
