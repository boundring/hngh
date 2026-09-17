# TASK hist-journal-extract-sentinels: HTML comment sentinels in docs/journal (2026-09-11..14)

Builds on: hist-journal-format.md (section order + HTML-comment feed citation
convention), hist-journal-extract-heading.md (heading/first-narrative rules).

## Sentinel inventory

Two sentinel kinds exist; both are single-line HTML comments on their own line,
surrounded by blank lines.

### 1. `<!-- sources: ... -->` (exactly one per file)

Placement: immediately after the DISPATCH section content (the verdict line),
before the one-line free narrative that precedes "## The ledger (machine-checked)".
Not before a story paragraph.

Verbatim variants (differ only in telemetry.db path after the 2026-09-12 -> 09-13 userspace-db move):

- docs/journal/2026-09-11.md:10 and 2026-09-12.md:10:
  `<!-- sources: sessions = automation/logs/budget.md (date-prefix + session-run suffix); spend/calls = automation/dashboard/telemetry.db (events, kind=session-cost, 24h window); operator items = automation/dashboard/operator-items.json (status=open); research lines = automation/research-lines.tsv (state column) -->`
- docs/journal/2026-09-13.md:10 and 2026-09-14.md:10: identical except
  `spend/calls = ~/.hngh/db/telemetry.db (...)` (repo path replaced by userspace home).

### 2. `<!-- feeds: ... -->` (one per story paragraph inside "## The day's story")

All story paragraphs are feed-cited; count varies 3-4 per day depending on
whether the digest feed fired.

| File:line | feeds value | Paragraph following it |
|---|---|---|
| 2026-09-11.md:23 | `automation/dashboard/telemetry.db + automation/logs/budget.md + automation/dashboard/plans.json` | Hall/sessions/meter/plans-queue paragraph ("The hall fired 9 session(s)...") |
| 2026-09-11.md:27 | `automation/digest/2026-09-11.md (Deck A)` | Outside-the-wire dispatch blocks paragraph (only on 09-11 and 09-12) |
| 2026-09-11.md:31 | `automation/state/beat-blockers.tsv` | Stall-ledger paragraph |
| 2026-09-11.md:35 | `automation/state/ocgo-agent-lessons.md + docs/project/lessons-2026-09-11.md` | Learning-loop paragraph |
| 2026-09-12.md:23 | same telemetry triple as 09-11:23 | Hall paragraph (20 sessions) |
| 2026-09-12.md:27 | `automation/digest/2026-09-12.md (Deck A)` | Outside-the-wire paragraph |
| 2026-09-12.md:31 | beat-blockers.tsv | Stall-ledger paragraph ("quiet for the day" variant) |
| 2026-09-12.md:35 | ocgo lessons pair (dated docs/project/lessons-2026-09-12.md) | Learning-loop paragraph |
| 2026-09-13.md:23 | `~/.hngh/db/telemetry.db + automation/logs/budget.md + automation/dashboard/plans.json` | Hall paragraph (33 sessions; telemetry path switched to userspace home) |
| 2026-09-13.md:27 | beat-blockers.tsv | Stall-ledger paragraph (no digest feed on 09-13) |
| 2026-09-13.md:31 | `automation/state/ocgo-agent-lessons.md + docs/project/lessons-2026-09-13.md` | Learning-loop paragraph |
| 2026-09-14.md:23 | same userspace telemetry triple | Hall paragraph (34 sessions) |
| 2026-09-14.md:27 | beat-blockers.tsv | Stall-ledger paragraph |
| 2026-09-14.md:31 | `automation/state/ocgo-agent-lessons.md + docs/project/lessons-2026-09-14.md` | Learning-loop paragraph |

## Structural rules for an extractor

- `sources` sentinel: exactly one per file, pinned to line ~10, terminates the
  DISPATCH section. Content is `key = path (qualifier); ...` semicolon list.
- `feeds` sentinel: always immediately precedes its story paragraph (one comment
  per paragraph, no uncited paragraphs observed inside "The day's story").
- Feed value grammar: `path + path` for multi-feed (` + ` separator), single path
  otherwise; one digest variant carries a parenthetical qualifier `(Deck A)`.
- Paragraph order is stable: hall/sessions -> [digest, only when digest exists]
  -> beat-blockers -> learning-loop. On 09-13/09-14 the digest paragraph is
  absent and later feed lines shift up two lines accordingly.
- The dated lesson path and the digest path embed the date
  (`lessons-YYYY-MM-DD.md`, `digest/YYYY-MM-DD.md`); telemetry/budget/plans/
  beat-blockers paths are date-invariant.
- Era boundary at 2026-09-13: telemetry path moves
  `automation/dashboard/telemetry.db` -> `~/.hngh/db/telemetry.db` in BOTH the
  sources line and the hall feeds line. An extractor should accept both path
  spellings. (09-13 also moves the public dispatch edition path to
  `~/.hngh/dispatch/`, consistent with hist-journal-format.md.)
- The free narrative between the sources line and "## The ledger" carries no
  sentinel; nor do the Verdict line, "The book of the day", or
  "The day's commits" sections.

## Notable content shapes

- Stall-ledger paragraph has two shapes: row-gained ("The stall ledger gained N
  row(s): ...") and empty ("The stall ledger is quiet for the day - no beat
  blockers filed."). Both are preceded by the same beat-blockers feed sentinel.
- The hall paragraph's numbers (sessions/cost/calls/plans) do not always match
  the DISPATCH numbers (e.g. 09-11: $8.32/98 calls in DISPATCH vs $7.47/195 in
  the hall paragraph); they cite the same feeds but different windows/slices.
