# hist-reports-extract: docs/project/reports.md extraction rules

## Ledger format (docs/project/reports.md)

- Append-only markdown pipe table, rows appended oldest-first
  (header lines 2-5: "Everything the routines saw fit to say, appended
  oldest-first; the dashboard reads it newest-first").
- Header row: `| timestamp | kind | id | first line | body |` (line 7;
  line 1 of the file also carries a stray copy of the header row, so
  parsers must tolerate header-looking rows).
- Rows are single-line pipe rows, one report per line. Columns when
  split on `|`:
  - `cols[0]` = empty (leading pipe)
  - `cols[1]` = timestamp, ISO-8601 UTC `YYYY-MM-DDTHH:MM:SSZ`
    (lexically comparable as a string)
  - `cols[2]` = kind (`progress`, `scheduled`, `alert`,
    `optimization`, ...)
  - `cols[3]` = id, 8-hex report id (note: ids can repeat across rows,
    e.g. `6f20e8cb` config-backup id and duplicate alert id `cf2fc04a`)
  - `cols[4]` = first line, the report's one-line summary/alert text
  - `cols[5]` = body, a sidecar filename
    `<timestamp>-<kind>-<id>.md` (bodies sit beside the table, not inline)

## Alert-row identification

- Alerts are rows with kind cell == `alert` (e.g. line 17:
  `| 2026-08-26T16:57:47Z | alert | 77c23af0 | [oversight] loop-signal: ... |`).
  First-line prefixes seen: `[oversight] loop-signal:`, `ui-audit ...`.
- Patrol alert convention: first line starts with `patrol:` (consumed
  by graph-data.py, see below).

## Consumer 1: automation/jobs/graph-data.py (patrol 24h filter)

`edge` function, lines 487-497:

```python
alerting = set()
reports = dashboard_dir / "reports.md"          # L489
if reports.exists():
    cutoff = (now - timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ")  # L491
    for line in reports.read_text().splitlines():
        if not line.startswith("|"):            # L493 pipe-row gate
            continue
        cols = [c.strip() for c in line.split("|")]   # L495 split+strip
        if len(cols) >= 4 and cols[1] >= cutoff and cols[3].startswith("patrol:"):
            alerting.add(cols[3].split(":", 1)[1])
```

Rules: keep only lines starting with `|`; split on `|` and strip each
cell; require >= 4 cells; timestamp filter is LEXICAL string compare
`cols[1] >= cutoff` (24h window, works because format is fixed-width
UTC); alert detection is on the FIRST-LINE cell `cols[3]` prefix
`patrol:` (not the kind column); the patrol id is the text after the
first colon. A patrol id in `alerting` renders its node state as
"alerting" with suffix "FAIL reported trailing 24h" (L504-508).

Note the column-index shift vs. system-feed: graph-data uses the
stripped leading-empty cell convention, so `cols[1]`=timestamp,
`cols[3]`=first line.

## Consumer 2: automation/jobs/system-feed.py (config-backup filter)

`probe_backups`, lines 221-237 (REPORTS_MD defined at L34):

```python
for ln in fh:
    cells = ln.split("|")                # L227 raw split, no strip on gate
    if len(cells) < 5:                   # L228 minimum 5 cells
        continue
    text = cells[4].strip()              # L230 first line = 5th cell
    if text.startswith("config-backup "):   # L231 prefix filter
        rows.append({"ts": cells[1].strip(), "kind": cells[2].strip(),
                     "ok": ": ok " in text, "text": text})   # L232-233
```

Returns `rows[-BACKUP_ROWS:][::-1]` (last N, newest-first) or None
with reasons "reports.md unreadable — backups omitted" (L235) /
"no config-backup runs in the ledger yet" (L237). Rules: split on `|`
without requiring a leading-pipe gate (header row also yields 7 cells
but its text does not match the `config-backup ` prefix, so it is
excluded by the prefix filter, not by structure); cells[1]=timestamp,
cells[2]=kind, cells[4]=first line; success detection is substring
`": ok "` in the first line (matches `config-backup agent-configs:
ok 9 files ...` rows such as reports.md L43).

## Cross-consumer summary

| consumer | row gate | ts cell | kind cell | first-line cell | filter |
|---|---|---|---|---|---|
| graph-data.py | startswith("|") + strip cells | cols[1] | (unused) | cols[3] | cols[3] startswith "patrol:" AND cols[1] >= 24h cutoff |
| system-feed.py | len(cells) >= 5 | cells[1] | cells[2] | cells[4] | text startswith "config-backup "; ok = ": ok " in text |
