# hist-reports-window: window semantics over docs/project/reports.md

Task: spec the ledger's window semantics — full-ledger append-only growth,
newest-first dashboard reads, the trailing-24h alert window in graph-data.py,
the last-N rows window in system-feed.py backups probe, and the cutoff
comparison mechanics. Builds on hist-reports-sections.md (structure map);
this artifact covers the temporal/window layer only and corrects two claims
of the prior artifact. All observations taken 2026-09-15 ~13:20-13:43Z
(read-only; ledger was 3262 lines, 3206 well-formed rows + 49 pipe-corrupted
rows at check time — the file is machine-appended live and grows between
reads).

## 1. The one full ledger, append-only growth

- Single canonical store: `docs/project/reports.md`, written ONLY through
  `scripts/report-queue --add` (writers surveyed: cadence jobs
  01-activity-tick / 02-ledger-prune / 03-gate-check / 04-review-prep /
  06-review-disposition, `automation/jobs/config-backup.sh` line 261,
  `automation/jobs/patrol.py report_alert` line 1321, `automation/scripts/
  router-tick.py report()` line 98 — every one shells out to report-queue,
  nobody concatenates rows by hand). `--add` opens the file in append mode
  (report-queue line 250-251), so on-disk order is oldest-first by
  construction; the only mutation of existing text is `bump_row()` (line
  188) rewriting the FIRST LINE cell of a deduped row (the ` ×N` marker).
  The header preamble (reports.md lines 4-5) states the contract verbatim:
  "appended oldest-first; the dashboard reads it newest-first and the bodies
  sit beside the table."
- Full ledger means: every consumer that needs a window computes it at READ
  time from the same full file. There is no per-consumer extract or
  materialized view; `--prune` (day-tier 02-ledger-prune.sh, 48h retention on
  alert kind only, archived to `report-bodies/prune-archive-<date>.md`) is
  the only removal mechanism and is explicitly CLI-only — the dashboard
  comment (app.js lines 341-342) says "mark-read advances the operator's
  own reading cursor via the token-guarded POST; --prune stays CLI-only
  (destructive)."

## 2. Newest-first reads (display layer)

- `scripts/report-queue --list`/`--unread` reverse file order
  (`newest_first()` line 255-256) — display-only, never persisted.
- Dashboard (automation/dashboard/app.js `fetchQueue` lines 355-376 +
  `renderQueue` lines 377-398): fetches the ledger mirror
  `dashboard/reports.md` (a SYMLINK to ../../docs/project/reports.md,
  verified on disk — same inode, not a copy) plus `report-cursor`, parses
  rows in file order (`parseReportRows` line 353 comment: "file order =
  oldest first, same as the ledger"), computes unread as everything after
  the cursor id in file order (unknown cursor id fails open — all unread;
  mirrors report-queue `unread_rows` lines 274-287), then renders
  `u.slice(-10).reverse()` — the LAST 10 unread, newest first (line 386).
- story-view.js `todayRows()` (lines 61-67): a different window — rows whose
  line starts with `| <UTC-date>T` where the date comes from the feed's own
  `generated` stamp (`todayFromStamp` lines 53-57: "a client-prayed Date
  could disagree with the ledger's own day"), i.e. a UTC-calendar-day
  window, not trailing hours, and it keeps ledger (oldest-first) order.
- report-queue `--json` (json_cmd lines 316-332): payload carries unread
  rows newest-first plus a `summary` of kind counts over ALL rows.

## 3. Trailing-24h alert window in graph-data.py

- Code: automation/jobs/graph-data.py lines 487-497. `build(...)` takes an
  injectable `now` (default `_now()` = UTC wall clock; tests pass
  `now=self.now`, test-graph-data.py line 118). The window is
  `cutoff = (now - timedelta(hours=24)).strftime("%Y-%m-%dT%H:%M:%SZ")`
  — a fixed trailing 24h, recomputed on every build (server caches the
  graph 30s: dashboard-server.py `TELEMETRY_TTL_S = 30.0`, `graph_feed()`
  lines 321-342).
- **Cutoff comparison mechanics — string compare, not datetime parse.**
  A row matches when `cols[1] >= cutoff` (line 496), lexicographic
  comparison of `YYYY-MM-DDTHH:MM:SSZ` strings. This works because the
  writer (`now_ts()` line 87-88) always emits zero-padded fixed-width ISO
  second stamps, so lexicographic == chronological for well-formed rows
  (verified: 0 ts-format mismatches across all 3206 well-formed rows).
  Rows are read line-by-line over the WHOLE file (no early break), split on
  `|` with NO length-5 validation — any line with >= 4 cells is considered.
- **Column indexing bug (finding, live-verified):** the scan tests
  `cols[3].startswith("patrol:")` where `cols = line.split("|")`. Because a
  pipe-table line starts with `|`, cols[0] is empty, so cols[1]=timestamp,
  cols[2]=kind, cols[3]=ID (8-hex sha8), cols[4]=first line. Real patrol
  alerts are filed as first line `patrol <pid>: ...` (patrol.py line 1434:
  `report_alert("patrol %s: %s on %s -- %s" ...)` — "patrol" + SPACE, and
  in the first-line column) with identity `patrol:<pid>` stored only in the
  body meta (verified in body 2026-09-15T09:07:19Z-alert-26f0cc27.md:
  `- **identity:** patrol:services`). The id column is always 8 hex chars
  (verified: 0 non-hex ids), so `cols[3].startswith("patrol:")` can NEVER
  match a real row — live simulation over the full ledger returns 0 matches
  all-time (15 alert rows have first line starting "patrol " with a space;
  0 rows have "patrol:" in the id column). Consequence: every patrol node
  renders healthy forever; real 24h FAILs (e.g. patrol services comfyui
  down at 2026-09-15T09:07Z) never flip a node to alerting. Confirmed by
  running the real builder read-only: all 21 patrol nodes healthy on
  2026-09-15T13:35Z despite same-day FAIL rows. The test
  `test_patrol_alerts_only_within_24h` (test-graph-data.py lines 187-193,
  fixture lines 90-94) passes only because the FIXTURE rows place
  `patrol:budget` in the ID column (kind `patrol-fail` — not even a real
  kind), a shape the real writer never produces. The trailing-24h filter
  itself is real and tested (fixture seeds one 2h-old and one 40h-old row;
  only the 2h-old one alerts) — the prefix/column match is the bug.
- The matched pid (from `cols[3].split(":", 1)[1]`) marks the patrol node
  alerting with detail suffix " — FAIL reported trailing 24h" (line 508);
  patrol-routes rows not in the alerting set stay healthy.

## 4. Last-N rows window in system-feed.py probe_backups

- Code: automation/jobs/system-feed.py lines 221-237, constant
  `BACKUP_ROWS = 6` (line 36, "recent config-backup runs surfaced on the
  backups card"). Reads the full ledger via `REPORTS_MD` (line 34, root from
  `HNGH_HOME`/`HNGH_REPO` env or the hardcoded default repo path), collects
  EVERY row whose 5th cell (cells[4] after split-on-pipe — the first-line
  column, unlike graph-data's cols[3] which is the id column) starts with
  `config-backup ` , then returns `rows[-BACKUP_ROWS:][::-1]` — the LAST 6
  in file order, REVERSED to newest-first. Verified live: system-ops.json
  backups card carries exactly 6 entries, newest (13:00:05Z) first, matching
  an independent re-scan of the ledger.
- The `ok` flag is derived by substring: `": ok " in text` — the writer
  (config-backup.sh line 261) always files `config-backup <lane>: ok <n>
  files push=<target> wall=<n>s` on success and `config-backup <lane>:
  <failure>` via `fail()` (line 37) on failure, so the substring is a
  reliable success marker. The dedup ` ×N` marker (150 rows carry one in the
  live ledger; e.g. 6f20e8cb x801) appends AFTER the text, so `": ok "`
  still matches deduped rows.
- Fail-closed: unreadable reports.md => `(None, "reports.md unreadable —
  backups omitted")`; zero config-backup rows => `(None, "no config-backup
  runs in the ledger yet")`. NO timestamp window at all — a 7th-oldest
  backup can be arbitrarily stale and the card shows nothing about age
  beyond the raw ts strings. Note the window is COUNT-based (last 6 rows),
  not time-based: if backups stop, the card keeps showing the same 6 aging
  rows with no staleness note.

## 5. Cutoff comparison mechanics (summary across consumers)

| Consumer | Window kind | Comparison | Direction after window |
|---|---|---|---|
| report-queue `--add` dedup | trailing seconds (default 86400) | `within_window()`: datetime parse then `(now - then).total_seconds() <= window` (line 177-185); 0 = unlimited lookback; malformed ts => False (fail closed) | n/a (in place) |
| graph-data.py patrol scan | trailing 24h | string `cols[1] >= cutoff` on ISO stamps | n/a (flag set) |
| system-feed.py backups | last N=6 rows | none (positional) | reversed (newest first) |
| app.js report queue | cursor position (all after cursor id) | id equality scan in file order; unknown id fails open | `slice(-10).reverse()` |
| story-view.js today rows | UTC calendar day of feed stamp | string prefix `'| ' + today + 'T'` | ledger order (oldest first) |
| 02-ledger-prune.sh | older-than 48h (alert kind only) | `--before TS` string `r[0] < before`; refuses future TS | archived to prune-archive-<date>.md |

- The dedup window (report-queue `--window`, default 86400s) is the
  writer-side temporal window: same-kind + same-identity re-fires inside
  the window fold into the existing row (` ×N`, occurrence lines in the
  body, original ts/id kept); with `--evidence TOKEN` an UNCHANGED evidence
  token suppresses the re-fire entirely (breadcrumb only, line 233-239).
  Patrol uses identity `patrol:<pid>` window 86400; router-tick uses per-
  signal identities; ledger-prune's deletions alert uses window 604800
  (02-ledger-prune.sh line 53).

## 6. Corrections to hist-reports-sections.md

1. **The 49 "missing-body" rows are pipe-corrupted rows, not absent
   bodies.** The prior artifact claimed 49 alert rows reference sidecars
   that do not exist on disk. Re-verified: those 49 ledger lines contain
   literal `|` characters inside the first-line TEXT (e.g. "loop-signal:
   STATE 3x identical crumb from oversight-tick: oversight-tick | tick |
   mode=timer"), so naive split-on-`|` yields 6-11 cells and both
   report-queue's strict 5-cell `read_rows()` and any 5-cell consumer skip
   them. Their LAST cell is always a well-formed body filename, but the
   corresponding body files genuinely do not exist on disk (all 49 checked:
   0 present). They span 2026-08-26 through 2026-09-13, all alert kind
   (writers: loop-signal/ui-audit-era rows and the patrol email
   send-failed family bcf6956b etc.). So the ledger rows are orphaned —
   but the mechanism is unescaped pipes corrupting the parse, not merely
   missing files; the row count is 3206 well-formed + 49 corrupted, not
   "3246 rows" (the earlier count included these 49 as rows plus the
   header).
2. **Kind counts as of this check: progress 2928, alert 232, scheduled 34,
   optimization 12 (well-formed rows only).** The prior artifact's 3246-row
   split (2921/279/34/12) included the 49 corrupted lines in the alert
   count. expense remains 0 rows (declared, never used) — confirmed.

## Key file:line index

- `scripts/report-queue`: add/dedup 211-252, within_window 177-185,
  bump_row 188-208, newest_first 255-256, unread_rows 274-287,
  json_cmd 316-332, prune_cmd 335-386.
- `automation/jobs/graph-data.py`: build signature 363-369, patrol scan
  487-497 (cutoff string compare line 491, patrol: prefix test line 496),
  patrol nodes 502-513.
- `automation/jobs/system-feed.py`: REPORTS_MD 34, BACKUP_ROWS 36,
  probe_backups 221-237.
- `automation/dashboard/app.js`: parseReportRows 344-354, fetchQueue
  355-376, renderQueue 377-398 (slice(-10).reverse() at 386).
- `automation/dashboard/story-view.js`: todayFromStamp 53-57, todayRows
  61-67.
- `automation/dashboard-server.py`: TELEMETRY_TTL_S 210 (30s graph cache),
  graph_feed 321-342.
- `automation/jobs/patrol.py`: report_alert 1321-1341 (identity patrol:<id>
  window 86400), FAIL filing 1432-1436.
- `automation/cadence/day/02-ledger-prune.sh`: 48h alert prune, archive,
  deletions alert window 604800.
- Tests: test-graph-data.py `_seed` 90-94 + test_patrol_alerts_only_
  within_24h 187-193 (fixture uses id-column patrol:budget — see finding);
  test-system-feed.py covers probe_uptime only, NO test covers
  probe_backups.
