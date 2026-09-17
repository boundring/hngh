# workq-report-shape: scripts/report-queue output shape

Inspected 2026-09-15. Read source (438 lines, Python 3, stdlib only) and
ran `scripts/report-queue --json` read-only. No repo edits.

## CLI flags

- `--add KIND TEXT [--identity KEY] [--evidence TOKEN] [--window SECONDS]`
  append a row (exit 2 on bad KIND / empty TEXT). id = first 8 hex of
  sha256(TEXT); ts = UTC ISO second (`YYYY-MM-DDTHH:MM:SSZ`).
- `--list [KIND]` rows newest-first, optional kind filter.
- `--unread [KIND]` rows newer than cursor (`docs/project/report-cursor`,
  stores one report id; everything after it in file order is unread;
  missing cursor = all unread; unknown cursor id fails open).
- `--json` dashboard payload (see below).
- `--mark-read ID` write ID to cursor; refuses unknown id (exit 2).
- `--prune --before TS --kinds KIND[,KIND...] [--archive PATH]`
  remove listed kinds older than TS; refuses missing/future TS.
- `--help` prints the module docstring.
- Malformed usage / no recognized flag: exit 2 (usage line to stderr).

## `--json` payload (exact)

Top-level keys: `generated`, `reports`, `unread`, `summary`.

```json
{"generated": "<UTC ISO second>",
 "reports": [{"ts": ..., "kind": ..., "id": ..., "first": ..., "body": ...}, ...],
 "unread": <int>,
 "summary": {"<kind>": <count>, ...}}
```

- `reports`: newest-first (`newest_first(unread_rows(rows))`), each dict
  exactly `{ts, kind, id, first, body}`:
  - `ts` row column 0, `kind` column 1, `id` column 2 (sha8 of text),
  - `first` column 3 (first line of TEXT, `×N` occurrence marker appended
    on dedup bumps),
  - `body` full text of `docs/project/report-bodies/<ts>-<kind>-<id>.md`
    (empty string when the body file is missing; never crashes).
- `unread`: count of rows newer than the cursor (== len(reports) when
  cursor absent; observed 212 == len(reports) today).
- `summary`: counts over ALL rows in the ledger (not just unread),
  keyed by kind; kinds with 0 rows are absent. Observed today:
  `{"progress": 2928, "scheduled": 34, "optimization": 12, "alert": 232}`
  (no `expense` rows).

## Exact extraction for a next-items list

```python
import json, subprocess
d = json.loads(subprocess.run(
    ["python3", "scripts/report-queue", "--json"],
    capture_output=True, text=True, check=True).stdout)
for r in d["reports"]:          # newest-first
    ts, kind, rid, first, body = r["ts"], r["kind"], r["id"], r["first"], r["body"]
# summary counts: d["summary"].get("alert", 0); unread count: d["unread"]
```

Notes for consumers:
- Order is newest-first, so "next items" typically means head of `reports`.
- `summary` is total-ledger counts; use `unread` for freshness.
- Alerts carry body meta `- **identity:** KEY` and optionally
  `- **last-evidence:** TOKEN`; dedup bumps add `- <ts> occurrence` lines
  to the body and ` ×N` to `first`.
- Fail-closed posture: missing cursor -> all unread; missing body -> empty
  text; file faults -> exit 2, never a crash. `HNGH_REPORT_ROOT` env
  overrides the repo root (points at repo root) for tests.

## Storage layout (context)

- `docs/project/reports.md`: markdown table, header
  `| timestamp | kind | id | first line | body |`, one row per line;
  parser skips non-table lines and the header itself (fail-safe).
- `docs/project/report-bodies/<ts>-<kind>-<id>.md`: full body.
- KIND set: progress | expense | optimization | scheduled | alert.
