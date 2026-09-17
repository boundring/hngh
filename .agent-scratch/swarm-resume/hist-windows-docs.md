# hist-windows-docs: docs/records extraction window spec

Date: 2026-09-15. READ-ONLY spec, no repo files edited. Builds on
hist-records-recency.md (ordering, thin-harvest policy, anchors),
hist-windows-caps.md (records per-source cap = 30, newest-wins truncation),
hist-windows-schema.md (envelope, `records:` dedup keys = filename stems),
hist-records-format.md (body format facts).

## 1. Scope: which records are in the window

- Source directory: `docs/records/*.md` (flat, no subdirectories exist).
- Include: every `YYYY-MM-DD-<slug>.md` file. 140 files total
  (139 records + README.md as of 2026-09-15).
- Exclude: `README.md` explicitly (it sorts last in both directions and is
  an index, not a record). Exclusion is by exact filename, not pattern.
- No other filtering: no topic filter, no scope keyword filter. The window
  is purely recency-based (newest-N by date stem).

## 2. Date bounds

- NO lower date bound in the producer. The all-history pool is the input;
  the effective window is produced by sorting newest-first and cutting at
  the per-source cap (30) per hist-windows-caps.md §2.
- Rationale: the thin-harvest-since-09-01 policy means date-bounding at
  2026-09-01 would be redundant today but brittle tomorrow (a quiet week
  plus the 30-cap already handles sparsity). Cap-driven selection degrades
  gracefully; a hardcoded `--since` does not.
- Empirical coverage of the top 30 (verified 2026-09-15): spans roughly
  2026-09-13 through 2026-09-15 at current commit density (the recent
  wave). If density drops, the 30-record window automatically stretches
  back toward the 2026-09-09 anchor band (1password-service-account-interface,
  budget-governance-directive, operator-flexibility-doctrine,
  wake-mutation-lane-rotation) — the spine-relevant recency band. No
  special-casing of anchors is needed; they enter the window naturally
  once density allows, and until then they are surfaced by their doctrine
  references in current records.
- Optional debugging bound only: an operator/debug flag MAY accept a
  `--records-since YYYY-MM-DD` filter comparing against the filename date
  stem (lexical compare is valid, ISO-prefixed). Not part of the default
  producer path.

## 3. Selection algorithm (newest-wins, matches caps sibling)

1. Glob `docs/records/*.md`; drop `README.md`.
2. Sort by filename stem descending (ISO date prefix => lexicographic ==
   chronological; verified by hist-records-recency: `sort -C` clean).
3. Keep the first 30 (cap; no padding if fewer exist).
4. Zero truncation of content: `summary` = filename slug (never
   truncated), so no summary-truncation rules apply to this source
   (caps sibling §3.2).

## 4. Output format (per hist-windows-schema.md)

One flat entry per record:

| field   | value |
|---------|-------|
| `key`   | `records:<filename stem>` e.g. `records:2026-09-15-viz-schema-version-gate`. Unique by construction (one file per stem); duplicates would indicate a real collision and fail closed at the validator. |
| `ts`    | Date-precision source: `YYYY-MM-DDT00:00:00Z` (midnight UTC of the filename date). Records carry no intraday timestamp; midnight normalization keeps lexical merge-sort correct relative to gitlog/report/journal entries of the same or later day. Records of a given day sort BEFORE that day's gitlog/report traffic — acceptable, since a record is a day-level summary of that day's work. |
| `summary` | filename slug after the date prefix (e.g. `viz-schema-version-gate`). Stable, bounded, no truncation. (Do NOT use the H1 title: it contains em dashes and free prose; slug is the machine-stable form. Renderers that want the title can `ref`-resolve.) |
| `source`| `records` |
| `ref`   | `docs/records/<filename>` (repo-relative, per schema sibling `ref` rule). |

`author`, `short`, `kind` are omitted for this source.

## 5. Interplay with the merged feed

- Entries join the merged feed, interleaved by `ts` desc, subject to the
  500-entry total cap (caps sibling §2). A 30-record contribution cannot
  be starved below its cap by gitlog volume because the per-source cap is
  applied first.
- Anchor-record fail-safe: if a future operator needs guaranteed anchor
  inclusion regardless of recency, that is a pinned-entries extension to
  the feed, not a widening of this window (records remain pure
  newest-N). Out of scope here.

## 6. Verification performed

- File counts: 140 entries in `docs/records/` (ls | wc -l), consistent
  with recency sibling's 139 records + README.
- No subdirectories: flat glob is safe today; if subdirs ever appear,
  fail closed (non-`.md` and nested paths excluded by the `*.md` glob).
