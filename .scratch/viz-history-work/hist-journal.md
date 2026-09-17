# docs/journal/ inventory (hist-journal-b)

## Layout
- Flat directory of one file per day: `YYYY-MM-DD.md`, plus `README.md`. Newest last, no subdirectories.
- Date coverage: **2026-08-25 through 2026-09-14** (21 dated entries + README, 22 files total).
- Gap: **2026-09-08 has no entry** (coverage is not perfectly contiguous).
- README.md (`docs/journal/README.md`) documents the format invariant: no YAML frontmatter; H1 first line, enforced by a check command; directory is part of the HISTORICAL tree.

## Entry schema
- First line: `# Journal — <date>` H1 (2026-08-25 was `# Journal — 2026-08-25 (day one)`; H1 text may carry suffixes).
- **No YAML frontmatter** in any file (README's check reports 0 files starting with `---`).
- Sections are `## H2` headings, but the set drifts over time. Stable recent set:
  - `## DISPATCH` (recent entries only, 4 occurrences)
  - `## The ledger (machine-checked)` (13)
  - `## The day's story` (4)
  - `## The book of the day` (12)
  - `## The day's commits` (11; once titled `## The wake's commits`)
  - Occasional one-offs: `## Notes`, `## Looking out`, `## The arc in one breath`, named wake sections (e.g. `## 00:30Z overnight-continuity wake ...`).
- Recent entries embed HTML comments citing data sources, e.g. `<!-- sources: sessions = automation/logs/budget.md; spend/calls = ~/.hngh/db/telemetry.db ... -->` and `<!-- feeds: automation/state/... -->` (docs/journal/2026-09-14.md:9, :18, :24, :31).
- Day's commits section: bullet list of backticked short hashes with one-line descriptions.
- Early entries (2026-08-25) are prose narrative with `## The arc in one breath` style sections; ledger/DISPATCH structure appeared later.

## Volume
- 22 files, 136K total. Dated entries range ~429 B (2026-08-29) to ~15.7 KB (largest dated entries; README itself is ~7.5 KB... largest file overall is a dated entry at 15,688 B). Recent entries are larger (multi-KB) than early ones.

## Update cadence
- One entry per day, appended as a new dated file. Commit-date analysis shows most files added on their nominal day, with backfill batches (5 files added 2026-09-06, 2 on 2026-08-30/31 and 2026-09-07) — i.e. entries are sometimes written/committed late in groups.
- Writers: machine sessions ("machine ledger sync" commits, e.g. `dca5994f docs: machine ledger sync — 12 changed file(s)`) plus occasional coordinator/handoff sessions (e.g. `75006ca0 journal: dinner watch handoff`). Content is generated from telemetry feeds (telemetry.db, budget.md, research-lines.tsv, operator-items.json) per the embedded source comments.
- Same-day later edits happen (files get follow-up commits, e.g. 2026-09-14 has multiple sync commits).

## History-view implications
- Sort by filename = chronological order; line 1 always yields the date/title.
- No frontmatter: parse H1 for title, H2s for sections; section names are not guaranteed stable across eras.
- Expect a missing-day hole (2026-09-08) and schema drift (prose era vs DISPATCH/ledger era).
