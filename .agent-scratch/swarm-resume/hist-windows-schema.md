# Merged feed schema for the recent-history spine (hist-windows-schema)

Date: 2026-09-15. READ-ONLY spec built on sibling artifacts
hist-gitlog-dedupfmt-shape.md, hist-reports-sections.md,
hist-records-recency.md, hist-journal-location.md. No repo files edited.

## 1. Design decision: one envelope, prefix-tagged keys

The merged feed reuses the pinned `history/1` envelope from
`automation/jobs/viz_schema.py:72-85` (accepted by
`automation/tests/test-viz-schema-history.py`):

```json
{ "schema": "history/1", "entries": [ <entry>, ... ] }
```

No new envelope version. Per source key prefixes
(`gitlog:` / `report:` / `records:` / `journal:`) carry the source tag, so
dedup stays exact and flat (duplicate `key` values fail closed at
viz_schema.py:323-329). Entries stay FLAT scalar objects (validator rule:
unknown scalar keys WARN-accept, nested objects/arrays fail closed at
viz_schema.py:309-322).

## 2. Unified entry fields

| field    | type | required | rule |
|----------|------|----------|------|
| `key`    | str  | yes | `<source-tag>:<source-native-id>`, globally unique, the dedup key. Table in section 3. |
| `ts`     | str  | yes | UTC Z form `YYYY-MM-DDTHH:MM:SSZ` (lexically sortable), normalized per source in section 4. |
| `summary`| str  | yes | One-line human summary, verbatim from the source where a native line exists. UTF-8; producer may emit `json.dumps` escapes. |
| `source` | str  | yes (additive) | One of `gitlog`, `report`, `records`, `journal`. Redundant with the key prefix but cheap for renderers; currently WARN-accepted as unknown scalar, formalize by widening viz_schema.py's allowed-entry set (additive change, NOT schema/2). |
| `author` | str  | no (additive) | gitlog only: `%an`. No emails (exposure precedent, per gitlog sibling). |
| `short`  | str  | no (additive) | gitlog only: git-native `%h` (8 hex). |
| `kind`   | str  | no (additive) | report source only: ledger `kind` cell (`progress`/`alert`/`scheduled`/`optimization`; `expense` declared but unused). |
| `ref`    | str  | no (additive) | Optional repo-relative pointer: sidecar filename for reports (`docs/project/report-bodies/<ts>-<kind>-<id>.md`), record path (`docs/records/<file>.md`), journal path (`docs/journal/<date>.md`), omitted for gitlog. |

## 3. Dedup keys per source

| source | key format | native identity | notes |
|--------|-----------|-----------------|-------|
| gitlog | `gitlog:<40-hex full sha>` | commit hash | Exact; abbrev (`%h`, 8 chars) never used in keys (collision-prone in principle). Regex `^gitlog:[0-9a-f]{40}$.` |
| report | `report:<ts>-<kind>-<id>` | sidecar filename stem from `docs/project/reports.md` body column | The ledger `id` alone is NOT unique (`6f20e8cb` appears 801 times, same-second rows collide); the `(ts, kind, id)` triple of the sidecar name is unique per row. Dedup `×N` markers: keep ONE entry per logical report keyed by its ORIGINAL row (dedup keeps original ts/id per report-queue docstring 15-30); do not emit a new entry per re-fire. |
| records | `records:<YYYY-MM-DD>-<slug>` | filename stem in `docs/records/` | Exclude `README.md`. ISO-prefix sortability verified by hist-records-recency. |
| journal | `journal:<YYYY-MM-DD>` | filename stem in `docs/journal/` (daily files only, glob excludes `ebook/`) | One entry per day file. |

Cross-source collisions are impossible by prefix; within-source duplicates
fail closed via the validator's duplicate-key rule, so producers must dedup
before emission.

## 4. Timestamp normalization per source

All `ts` values normalized to `YYYY-MM-DDTHH:MM:SSZ` so the merged feed
sorts lexicographically (matches graph-data.py `%Y-%m-%dT%H:%M:%SZ` and the
committed fixtures).

- gitlog: `%aI` (`2026-09-15T08:39:26-04:00`) -> convert offset to UTC Z.
  Author date (semantic when-work-happened; `%aI`==`%cI` 499/500).
- report: ledger timestamp cell is already `...Z` (report-queue `now_ts()`)
  — copy verbatim. One known 1-second inversion exists at reports.md line
  3009 (append race); after merge-sort by `ts` this is harmless — final
  ordering is by `ts` desc, tie-break `key` asc.
- records: filenames are date-only. Use `YYYY-MM-DDT00:00:00Z` (date
  precision is honest; no mtime dependency, which would break
  reproducibility under `git checkout`).
- journal: same as records, `YYYY-MM-DDT00:00:00Z`.

## 5. Ordering and window

- `entries` newest-first (`ts` desc, tie-break `key` asc for determinism).
- Window/cap per source owned by sibling nodes (hist-gitlog* family); the
  merge layer takes each source's already-truncated feed and interleaves by
  `ts`. Empty merged feed: `{"schema": "history/1", "entries": []}` is
  valid (no min-length rule).

## 6. Concrete example

```json
{
  "schema": "history/1",
  "entries": [
    {
      "key": "gitlog:d6d239d0151034bfd7218ba8a9317112228dc823",
      "ts": "2026-09-15T12:39:26Z",
      "summary": "research: fail-20260914-What-is-the-current-maximum-length-of-se reviewed-adopted",
      "source": "gitlog",
      "author": "Fixture",
      "short": "d6d239d0"
    },
    {
      "key": "report:2026-09-15T12:51:12Z-progress-3e1a77b2",
      "ts": "2026-09-15T12:51:12Z",
      "summary": "implementation: ...",
      "source": "report",
      "kind": "progress",
      "ref": "docs/project/report-bodies/2026-09-15T12:51:12Z-progress-3e1a77b2.md"
    },
    {
      "key": "records:2026-09-15-viz-schema-version-gate",
      "ts": "2026-09-15T00:00:00Z",
      "summary": "viz-schema-version-gate",
      "source": "records",
      "ref": "docs/records/2026-09-15-viz-schema-version-gate.md"
    },
    {
      "key": "journal:2026-09-15",
      "ts": "2026-09-15T00:00:00Z",
      "summary": "daily journal 2026-09-15",
      "source": "journal",
      "ref": "docs/journal/2026-09-15.md"
    }
  ]
}
```

Validates today with additive WARNs on `source`/`author`/`short`/`kind`/
`ref` (scalar extras are WARN-accepted, rc=0).

## 7. Producer obligations

1. Emit each source per its sibling spec, dedup within source (exact keys).
2. Normalize all `ts` to Z form; sort merged entries `ts` desc, `key` asc.
3. Validate through `automation/jobs/viz_schema.py --schema history/1
   <payload>` before writing (CLI gotcha: tag is a flag, not positional).
4. Round-trip `json.loads(json.dumps(payload))` and revalidate
   (schema-tests-version-gate discipline).
5. Tolerate missing report sidecars (49 known missing, all `alert` kind):
   emit the row with `summary` from the first-line cell; `ref` may point at
   a nonexistent sidecar — renderer fails soft (report-queue precedent).
6. Skip prune-archived report rows (`report-bodies/prune-archive-*.md`
   content is history-of-history, not spine material).

## 8. What I did not check

- Cap values / window widths per source (sibling-owned).
- Whether a future schema/2 should carry nested detail; today's validator
  forces flat entries and that is sufficient for the spine.
- TUI/dashboard consumption of the additive fields (no history consumer
  exists yet).
