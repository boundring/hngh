# hist-reports-sections: docs/project/reports.md structure map

Task: map the report ledger's sections — header preamble, pipe-table schema,
body-file sidecar convention, kind vocabulary, oldest-first ordering.
All line refs are to `docs/project/reports.md` unless prefixed with another
path. Observations taken 2026-09-15 (file is `M` in git — machine-appended
live; 3253 lines at read time).

## 1. Header preamble (lines 1-6)

- **Line 1 (stray header quirk):** `| timestamp | kind | id | first line | body |`
  appears ABOVE the title, before line 2. A duplicated/degenerate copy of the
  canonical header at line 7. `scripts/report-queue` `read_rows()` (line 91)
  only parses rows that start with a timestamp year, so the stray line is inert
  to the tool but visible to raw readers/renderers.
- **Line 2:** `# Report ledger` — the single H1 title.
- **Line 3:** blank.
- **Lines 4-5 (preamble text, verbatim):**
  `Everything the routines saw fit to say, appended oldest-first; the`
  `dashboard reads it newest-first and the bodies sit beside the table.`
  This documents both orderings: on-disk append order is oldest-first; the
  consuming dashboard reverses to newest-first; full bodies live beside the
  table in sidecar files (not in the table itself).
- **Line 6:** blank separator before the table header.

## 2. Pipe-table schema (line 7 onward)

- **Line 7 (canonical header):** `| timestamp | kind | id | first line | body |`
  — exactly five columns, matching `HEADER` in `scripts/report-queue` line 79.
- **Data rows: lines 8-3253** (3246 rows at read time), one row per line, no
  trailing blank line at EOF (file ends `...bba72263.md |` + newline).
- Column semantics (from `scripts/report-queue` docstring lines 4-14):
  - `timestamp` — UTC ISO second, format `2026-MM-DDTHH:MM:SSZ`
    (all 3246 rows match; produced by `now_ts()` line 87).
  - `kind` — closed vocabulary (section 4 below).
  - `id` — first 8 hex chars of `sha256(TEXT)` (`sha8()` line 83); every row
    is exactly 8 hex chars. NOT unique across rows: identical TEXT re-fires
    produce new rows with the same id (e.g. `6f20e8cb` appears 801 times —
    the recurring `config-backup` line); same-second rows also collide.
  - `first line` — one-line summary of the report (may carry a dedup ` ×N`
    marker, see below).
  - `body` — sidecar FILENAME (not inline text), `<ts>-<kind>-<id>.md`
    (verified: all 3246 body cells match that pattern; 0 mismatches with a
    strict trailing-field regex).
- Row generation: `--add KIND TEXT` appends the row at the END of the file and
  writes the body sidecar; with `--identity KEY` + `--window SECONDS`
  (default 86400) same-kind/same-identity re-fires are deduped into the
  existing row: its first line gains/updates ` ×N`, `- <UTC ts> occurrence`
  lines append to the body, and the row keeps its original ts/id (docstring
  lines 15-30). Observed in the ledger, e.g. line 3010 ends `... day count 1) ×2`.
- Cursor/unread state lives OUTSIDE the file: `docs/project/report-cursor`
  (docstring lines 21-27); the display layer advances it, never the writer.

## 3. Body-file sidecar convention

- Location: `docs/project/report-bodies/` (`BODIES` in report-queue line 76;
  referenced from `automation/cadence/hour/30-kernel-ledger-sync.sh` line 4
  as a machine-appended surface).
- Filename: `<timestamp>-<kind>-<id>.md` (`body_name()` lines 115-116), e.g.
  `2026-08-26T16:09:35Z-progress-f79758fd.md`.
- Body file format (`write_body()` lines 119-127):
  `# <kind> — <id>` / blank / `- **timestamp:** <ts>` / `- **kind:** <kind>` /
  `- **first line:** <first>` / optional `- **identity:** <KEY>` and
  `- **last-evidence:** <TOKEN>` meta lines / blank / full report text.
- Counts at read time: 3221 kind-named sidecars on disk (progress 2925,
  alert 230, scheduled 34, optimization 12) plus 20 `prune-archive-*.md`
  files sharing the directory.
- **Missing-body tolerance:** 49 ledger rows reference sidecars that do not
  exist on disk (all 49 are `alert` kind, spanning 2026-08-26 through
  2026-09-13). The tool is explicit that this is safe: "never crash on a
  missing cursor/body — fail closed... a missing body yields empty text"
  (docstring lines 10, 56-57).
- **Prune archive sidecars:** `report-bodies/prune-archive-<YYYY-MM-DD>.md`
  hold rows removed by `--prune --before TS --kinds ... [--archive PATH]`.
  Each archive gets a `## pruned <TS>` section header followed by the removed
  rows in the same pipe format (02-ledger-prune.sh line 31 builds the name;
  report-queue docstring lines 46-53). Example: `prune-archive-2026-09-15.md`
  carries 86 pruned rows. Prune deletes the matching body files and never
  touches unlisted kinds.

## 4. Kind vocabulary

- Tool-declared set (`scripts/report-queue` line 71):
  `KINDS = {"progress", "expense", "optimization", "scheduled", "alert"}`
  — five kinds; the writer refuses any other KIND (exit 2, docstring line 13).
- **Observed in the ledger (3246 rows):** exactly four kinds are used —
  `progress` 2921, `alert` 279, `scheduled` 34, `optimization` 12.
  `expense` is declared but never used (0 rows).
- Typical first-line prefixes by kind (observed): progress —
  `implementation:`, `review:`, `cleanup:`, `inward:`, `outward:`,
  `course ...:`, `config-backup`, `research line ...`, `router ...`;
  scheduled — `refactor:`, `autonomous cadence tick ran`, `course ...
  provisioned`; alert — `[oversight] loop-signal:`, `ui-audit ...`,
  `router dedup/escalated`; optimization — `zoom-out-loop: ...`.

## 5. Oldest-first ordering

- On-disk rows are appended at the end, so the file is oldest-first by
  construction; `read_rows()` documents "Return the report rows in file order
  (oldest first)" (report-queue line 92), and `--list` reverses to
  newest-first for display (line 21). First row: line 8, ts
  `2026-08-26T16:09:35Z` (ledger creation, commit 859f691e "docs:
  activity-cadence report ledger"). Last row: line 3253, ts
  `2026-09-15T12:51:12Z`.
- Monotonicity check over all 3246 rows: non-decreasing everywhere except
  **one 1-second inversion at line 3009** — row `2026-09-14T20:00:32Z |
  progress | 27cebfcc` (router routed overnight...) sits between two
  `2026-09-14T20:00:33Z` rows (lines 3008 and 3010). Consistent with an
  append racing a UTC second boundary, not with dedup (dedup keeps the
  original row in place). No other inversions; same-timestamp row groups are
  common and ordered stably.

## Key cross-references

- `scripts/report-queue` (the writer/reader tool; repo-root `scripts/` is
  kernel ceremony surface): docstring lines 2-7 schema, 13-14 id/ts rules,
  15-30 dedup, 46-53 prune/archive, 71 KINDS, 75-79 paths/HEADER,
  91-92 row parse order, 111-127 sidecar naming/format.
- Writers: `automation/cadence/day/01-activity-tick.sh` line 22/37
  (`REPORT="python3 $KERNEL/scripts/report-queue"`), plus 02-ledger-prune,
  03-gate-check, 04-review-prep, 06-review-disposition all call
  `--add`/`--prune` with `HNGH_REPORT_ROOT`.
- Ledger is one of the machine-appended doc surfaces named in
  `automation/cadence/hour/30-kernel-ledger-sync.sh` lines 3-4.
