# 2026-08-26 — Agent live-view (dashboard roster)

## Scope

First implementation of the agent-live-view rung: the dashboard now reads
a live agent-session roster — the genuine worker stores under
`/tmp/hngh-heartbeat-*` and `/tmp/hngh-auto-*` plus the automation store —
distinct from the archived `sessions` list, and renders it as a panel in
`dashboard-tui` (and a table in `--export-html`).

## What landed

1. **`scripts/dashboard-readout`**: new `roster_rows(limit=15, ttl=0.0)`
   beside `session_rows` — same TTL-cache and fail-closed-empty-on-missing
   convention (a missing or unreadable store yields `[]`, never a crash).
   Rows are `{id, state, mission, source, age}` where `source` is
   `heartbeat`/`auto`/`automation`; state/objective are parsed directly
   from each store's `record.lisp` (no sbcl subprocess), newest record
   first, bounded by `LIMIT`. `roster` is folded into `data_spine`.
2. **`scripts/dashboard-tui`**: a `live agents` panel following the
   sessions `DataTable` pattern — id/state/source/mission columns;
   closed/evacuated beacons dim to ` beacon` exactly like the sessions
   panel (`_beacon_kind`), genuine states keep their `_STATE_COLOR`.
   Roster rides the existing worker gather/paint refresh; the panel is
   bounded (`height: auto; max-height: 10`) so it never squeezes the
   other tables.
3. **HTML export**: `render_html` gains a `live agents` table.
4. **Tests**: `tests/scripts/test-dashboard-readout.py` now asserts the
   `roster` key in `--json` output and fail-closed-on-missing
   (`roster_rows() == []` when no store root exists);
   `tests/scripts/test-dashboard-tui.py` asserts the `live agents` panel
   renders in the live PTY smoke. Both green.

## Verification

- `python3 tests/scripts/test-dashboard-readout.py` — smoke OK (added
  roster checks).
- `python3 tests/scripts/test-dashboard-tui.py` — 5/5 OK, PTY shows
  `live agents` panel + status strip.
- `python3 scripts/dashboard-readout --json` — carries a `roster` list
  populated from real heartbeat/auto/automation stores.
- `make test` — full gate green (lisp suite 2774 checks + python).

## Notes

- The roster is display-only (read), never governance input — matching
  the backlog intent ("display-only, never governance input").
- Hub-agent visibility stays limited to what the omp hub roster +
  `history://` transcripts expose; this pane surfaces the on-disk
  store sessions those run.