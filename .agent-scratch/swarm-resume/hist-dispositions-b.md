# hist-dispositions-b: Inventory of automation/research-dispositions.tsv

Read-only survey, 2026-09-15. Complements hist-windows-schema.md (merged feed
envelope) and hist-journal-dispatch-status.md (research-lines histogram feeding
verdicts).

## File basics

- Path: `automation/research-dispositions.tsv`
- Size: 95,609 bytes; mtime Sep 15 10:15 (today, minutes before this survey)
- Rows: 162 total lines = 1 header + 161 disposition records

## Columns (9, tab-separated)

| # | name      | notes |
|---|-----------|-------|
| 1 | line      | subject id; matches keys in research-lines.tsv; newer rows use `fail-YYYYMMDD-<question-slug>` ids from the failure-driven lane |
| 2 | action    | terminal disposition; histogram: adopted 71, parked 59, killed 30, fixed 1 |
| 3 | verdict   | free-text verdict beginning with the action keyword ("killed -- duplicate of surviving line ...", "adopted -- Crystallized ...") |
| 4 | reviewer  | model pin, e.g. `model:kimi:k3-256k`, `model:unsloth:unsloth/Qwen3.8-27B-GGUF`, `model:deck:deck-7b` |
| 5 | evidence  | absolute path to the research doc under `docs/research/` |
| 6 | date      | review date (YYYY-MM-DD) |
| 7 | support   | (mostly empty in sampled rows) |
| 8 | oppose    | (mostly empty in sampled rows) |
| 9 | followons | (mostly empty in sampled rows) |

## 3 sample rows (verbatim, truncated verdicts/evidence to keep lines readable)

1. `gantt-legibility` | killed | "killed -- duplicate of surviving line gantt-legibility-patterns; keep record, consolidate findings there" | model:kimi:k3-256k | docs/research/2026-08-28-gantt-legibility.md | 2026-09-07
2. `log-presentation-patterns` | adopted | "adopted -- Crystallized slice-first, contract-driven log presentation guidance is actionable and should shape logging and UI work now..." | model:unsloth:unsloth/Qwen3.8-27B-GGUF | docs/research/2026-08-28-log-presentation-patterns.md | 2026-09-08
3. `session-cost-display` | killed | "killed -- duplicate of survivor line session-cost-display-formats; findings should be reviewed under that record" | model:kimi:k3-256k | docs/research/2026-08-28-session-cost-display.md | 2026-09-08

## Freshness

- File mtime: 2026-09-15 10:15 (fresh; actively appended).
- Row `date` column distribution (tail): 2026-09-11 x11, 09-12 x15, 09-13 x20,
  09-14 x49, 09-15 x23. Newest rows are failure-lane ids
  (`fail-20260914-*`, `fail-20260915-*`) reviewed/parked or adopted today.
- Last 3 git commits on the file (all 2026-09-15): ff627ba8, 485474f6, 90ef2c01,
  messages `research: fail-... reviewed-parked/adopted`.

## Consumers (non-log, non-prompt surfaces)

- `automation/cadence/hour/33-research-beat.sh` (line 149): reads
  `$AUTOMATION_ROOT/research-dispositions.tsv` as the terminal-disposition
  ledger for the hourly research beat (adopted|parked|killed dedupe check).
- `automation/jobs/patrol.py` (line 1216): joins `research-dispositions.tsv`
  alongside research-lines for patrol state.
- `automation/mcp/hngh_mcp_server.py` (lines 98-158): serves disposition header/
  content to MCP clients (surfaces `research_lines` companion).
- `automation/scripts/overnight-cycle.sh` (line 437): tail -n 5 of the file for
  overnight context refresh.
- Test coverage: automation/tests/test-research-review.sh,
  test-research-accel2.sh, test-research-blockers.sh,
  test-research-commit-per-op.sh, test-dev-plan-synth.sh,
  test-model-pin-routing.sh, test-patrol.py, test-mcp-server.py.
- Dashboard state mirrors: automation/dashboard/{data,plans,sessions}.json and
  automation/STATE.md reference the file.

## Relationship to siblings

- hist-journal-dispatch-status.md covers research-lines.tsv state histogram;
  every terminal line state there ends up appended here as a verdict row, so
  dispositions.tsv is the terminal verdict ledger downstream of lines.
- hist-windows-schema.md covers the merged feed envelope; dispositions rows
  feed the review step of that pipeline.
