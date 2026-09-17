# hist-reports-format: reports.md output format for the history payload

Task: spec the row-object shape, sort order, kind vocabulary, body-file
resolution, size/volume, and downstream consumers of
`docs/project/reports.md`. Builds on `hist-reports-sections.md` (structure
map: preamble, pipe schema, sidecars, ordering); this document covers the
*payload/JSON* side and the consumer programs. Re-verified 2026-09-15.

## 1. The canonical row-object shape

There is no single `{ts,kind,id,first_line,body_file}` producer in the
repo. The task's field names are aspirational; the actual emitters are:

### a) `scripts/report-queue --json` (canonical machine payload)

`json_cmd()` (scripts/report-queue lines ~297-315) emits, newest-first,
**unread-only** (rows after the cursor in `docs/project/report-cursor`;
no cursor => everything):

```json
{
  "generated": "2026-09-15T...Z",
  "reports": [
    {"ts": "...", "kind": "progress|scheduled|alert|optimization|expense",
     "id": "8-hex", "first": "<first-line summary>",
     "body": "<FULL INLINE TEXT of the sidecar, or '' if missing>"}
  ],
  "unread": <int>,
  "summary": {"progress": N, "alert": N, ...}   // counts over ALL rows
}
```

Key facts:
- Field is **`first`**, not `first_line`; it is `r[3]` of the parsed row,
  dedup marker ` ×N` included.
- Field is **`body`**, holding the resolved sidecar *text*, not a
  filename. `body_text()` (line ~283) resolves
  `docs/project/report-bodies/<ts>-<kind>-<id>.md`; a missing body
  yields `""` (fail closed, docstring line 56-57) — the JSON consumer
  never sees a path, so there is no `body_file` field at this layer.
- `summary` counts cover the whole ledger even though `reports` only
  carries unread rows.

### b) `scripts/dashboard-tui` / `scripts/osd-operative` adapters

Both shell `report-queue --json --unread` and pass records through as-is:
`_reports()` (dashboard-tui lines 433-450) keeps the newest `maxrows=5`,
fail-closed to `([], 0, False)` on any error/timeout.
`_report_body_text()` (dashboard-tui lines 462-470) is the one place a
"body file" re-resolution happens: if a record carries a `body` *name*
(legacy shape), it tries `docs/project/report-bodies/<name>.md` then the
raw path, else falls back to the first line. But note dashboard-tui:466
actually reads `report.get("first_line")` — a field the current
report-queue JSON never emits — so that fallback path is effectively
dead code; the live display path (line 777) also reads `first_line` and
thus renders an empty string unless a legacy producer supplied it.
osd-operative `report_status()` (lines ~134-152) reads `first_line`
the same way; its guard `first[:40]` makes the miss benign (it falls
through to ` · reports N`).

### c) Browser: `automation/dashboard/app.js` (ledger mirror)

The web dashboard does NOT use report-queue JSON. `parseReportRows()`
(app.js lines ~346-356) parses the served `reports.md` + `report-cursor`
mirror client-side into `{ts, kind, id, first}` (4 fields, no body),
oldest-first file order; unread = rows after the cursor id, unknown
cursor fails open (all unread). Read state advances via
`POST /report-queue/mark-read` handled by
`automation/dashboard-server.py` line ~652 (400 if report-queue refuses
the id).

## 2. Sort order

- Ledger file: oldest-first append order (see hist-reports-sections §5;
  one benign 1-second inversion at line 3009).
- `--json` / `--list` / `--unread`: newest-first (`newest_first()` =
  `reversed(read_rows())`, report-queue line ~224).
- app.js render: `u.slice(-10).reverse()` — newest first, capped at 10.
- graph-data.py consumes raw file order but only membership-tests, so
  order is irrelevant there.

## 3. Kind vocabulary

Tool-declared closed set: `{progress, expense, optimization, scheduled,
alert}` (report-queue line 71; unknown kind exits 2). Observed in the
ledger: progress (dominant), alert, scheduled, optimization; `expense`
declared, 0 rows ever. First-line prefixes by kind catalogued in
hist-reports-sections §4; not repeated here.

## 4. Body-file resolution

- Sidecar path rule: `docs/project/report-bodies/<ts>-<kind>-<id>.md`
  (`body_name()`, report-queue lines ~115-116).
- JSON layer resolves to text immediately (`body_text()`); missing =>
  `""`. TUI layer additionally tolerates a `body` field holding a
  filename (legacy) and re-resolves with `.md`-suffix normalization
  (`removesuffix('.md')` then re-append). Web layer never resolves
  bodies (first-line only).
- ~49 alert rows reference sidecars absent on disk (2026-08-26 ..
  2026-09-13) — tolerated everywhere by design.

## 5. Size / volume (measured 2026-09-15 09:17)

- `docs/project/reports.md`: 3262 lines, 3255 data rows, 692K on disk
  (708192 bytes). The task brief's "3145 rows, 679KB" was a stale
  snapshot; the ledger grows by machine appends (config-backup alone
  contributes an id repeated 801 times).
- Note the earlier section artifact recorded 3246 rows/3253 lines an
  hour earlier — file is live; treat counts as point-in-time.
- Full-ledger reads are O(file): read_rows() slurps and splits every
  line; `--json` additionally reads every unread sidecar. Prune
  (`02-ledger-prune.sh`) is the growth control; archives go to
  `report-bodies/prune-archive-<date>.md`.
- Per-row payload is dominated by `first` (dedup marker inflates it) —
  `body` text lives out-of-table, keeping the ledger line-oriented and
  awk-able (overnight-cycle.sh:341 greps it directly).

## 6. Downstream payload consumers (verified)

1. `scripts/dashboard-tui` — `--json --unread`, newest 5, report
   pop-in viewer; mark-read via TUI.
2. `scripts/osd-operative` — `--json --unread`, newest-1 status strip.
3. `automation/scripts/email-digest.py:405` — `--json` (full read).
4. `automation/dashboard-server.py` — POST `/report-queue/mark-read`
   (invokes report-queue; 400 on unknown id) and research-steer alerts
   appended via report-queue (lines 88-150, 999).
5. `automation/dashboard/app.js` — client-side pipe-parse of the
   `dashboard/` mirror (reports.md + report-cursor), unread rule
   mirroring `unread_rows`.
6. `automation/jobs/graph-data.py:487-496` — raw pipe parse of
   `automation/dashboard/reports.md` mirror, trailing-24h cutoff
   (`cols[1] >= cutoff`), `cols[3].startswith("patrol:")` => alerting
   patrol set (row-index note: with the leading `|` split, cols[0]="",
   so cols[1]=ts, cols[3]=first line — consistent).
7. `automation/scripts/overnight-cycle.sh:341` — awk over the ledger.
8. Tests: `tests/scripts/test-report-queue.py`,
   `tests/scripts/test-dashboard-tui.py`,
   `automation/tests/test-viz-schema-seam.py` (history/1 schema is the
   *sessions/telemetry* history payload, a different feed — do not
   conflate; see viz-history-payload.md).

## What I did not check

- Whether any external/off-repo consumer depends on the legacy
  `first_line`/`body`-as-filename shape that dashboard-tui still
  half-supports (dead-code suspicion is inferred, not proven by test).
- History of `first_line` field naming in git (when report-queue JSON
  diverged from the task-spec names).
- Memory/GC behavior of `--json` with a very large unread backlog
  (unread after long cursor absence = full ledger + all sidecars).
