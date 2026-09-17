# hist-windows-queue: extraction windows for queue/automation state

Date: 2026-09-15. READ-ONLY spec, no repo files edited. Builds on
hist-windows-schema.md (history/1 envelope, entry fields, dedup-key
table), hist-windows-caps.md (per-source caps, truncation rules),
workq-report-shape.md (report-queue --json read side), rp-mirror.md
(ledger mirror symlinks, cursor semantics, staleness),
hist-dispositions-b.md (research-dispositions.tsv inventory).

Covers three queue/automation sources for the recent-history spine:
(S1) the report ledger, (S2) the dashboard readout spine, (S3) the
research-lines feed (lines + dispositions TSVs).

## 1. Source S1: queue ledger (report source)

### 1.1 Window decision: ledger-native newest-50, NOT the unread window

`scripts/report-queue --json` emits `reports` = unread rows only
(newest-first), bounded by the cursor (`docs/project/report-cursor`;
absent/unknown cursor fails open = all unread). That unread array is a
dashboard READ-STATE semantic, not a history window:

- One mark-read click rewrites the cursor and collapses `unread` to 0,
  so a history feed keyed on `reports` would silently empty itself.
- Observed live (14:44:34Z run): unread = 229 == len(reports),
  spanning only ~16h (head 2026-09-15T14:42:51Z, tail
  2026-09-14T22:52:30Z) because the cursor is fresh. A stale or
  absent cursor would expose the whole ledger (3,223 rows today:
  progress 2942 / alert 235 / scheduled 34 / optimization 12).

Extraction window (matches the caps sibling's "the 50 newest rows"):

1. Read the ledger TABLE directly: `docs/project/reports.md` or the
   committed mirror symlink `automation/dashboard/reports.md` (zero
   staleness by construction, per rp-mirror) with the 5-column
   fail-safe parser from workq-report-shape.md (skips non-table lines
   and the header row).
2. Sort newest-first: `ts` desc, tie-break `id` asc. One known
   1-second append-race inversion (reports.md line 3009) is harmless
   after this sort.
3. Skip prune-archived rows and prune-archive sidecars
   (`report-bodies/prune-archive-*.md`) per schema sibling 7.6.
4. Within-source dedup needs no extra pass: xN-bumped alerts are
   already single ledger rows keyed by the original ts/id.
5. Cap at 50 (HIST_CAP_REPORT). Count-based window, no time bound.
   The 48h alert-prune cadence naturally bounds alert freshness
   (observed today 09:00:37Z: 86 alert rows pruned, archived to
   prune-archive-2026-09-15.md). At the observed ~14 rows/h, the 50
   newest rows span roughly 4 hours.
6. Use `--json` ONLY for envelope metadata: `generated` (staleness
   check), `unread` (read-state signal), `summary` (total-ledger
   kind counts).

### 1.2 Output format (per schema sibling)

Entry: `key` = `report:<ts>-<kind>-<id>` (sidecar filename stem),
`ts` copied verbatim (ledger cells are already
`YYYY-MM-DDTHH:MM:SSZ`), `summary` = ledger `first` truncated to 200
chars + "..." only when longer (max observed 495 in today's unread
window, 1094 all-time), `source` = "report", additive `kind`, `ref` =
`docs/project/report-bodies/<ts>-<kind>-<id>.md` (may dangle on the
49 known missing sidecars; 0 empty bodies observed in today's unread
set). Unread-window kind mix today: progress 168 / alert 59 /
optimization 1 / scheduled 1.

## 2. Source S2: dashboard readout (state snapshot)

### 2.1 Shape and structural caps (scripts/dashboard-readout --json)

`data_spine` (scripts/dashboard-readout:299-311) emits exactly:
`timeline`, `queue`, `etas`, `sessions`, `roster`, `generated`,
`verdict`. No time window exists anywhere in the readout: every
section is a full-parse snapshot bounded by structural caps,
regenerated per invocation.

| key | parse source | cap | observed today (14:25Z run) |
|-----|--------------|-----|------------------------------|
| timeline | docs/project/timeline.md 4-col tab rows, kind in {done, event, rotation} (`timeline_rows` :102-108). Entries are 4-string ARRAYS [date, kind, name, hash] | all valid rows (9) | 9 rows, all dated 2026-08-25 |
| queue | docs/project/queue.md 4-col tab rows, status in {queued, done, active} (`queue_items` :111-117) | all valid rows (26) | 26 rows (18 queued, 8 done). 5 done rows with 5 columns (credential-rotation-auto, push-self-sufficiency, governance-vocabulary, agent-live-view, machine-steered-backlog) are silently DROPPED by the NF==4 filter |
| etas | last "## ETA" section of queue.md (`queue_etas` :497-511) | all keys (3) | free-text windows, not dates. Parse quirk observed: value "next rotation (wake-mutation-lane done" (truncated inside a parenthetical) |
| sessions | newest `~/.hngh-automation/store` sub-stores rendered via `sbcl --script scripts/hngh present`, 4s timeout, fail-soft (`session_rows` :156-179) | hard limit = 5 | 5 rows, all evacuated beacons, ages 1376-8610 s, missions "hourly research ping" / "morning digest" |
| roster | `/tmp/hngh-heartbeat-*`, `/tmp/hngh-auto-*` globs + automation store, regex state/mission from record.lisp (`roster_rows` :258-297) | hard limit = 15 | 15 rows, all evacuated, source = automation |
| verdict | derived from roster headroom (`verdict` :363-374) | n/a | all-clear, reasons [] |
| generated | `datetime.now().astimezone()` LOCAL offset form | n/a | "2026-09-15T10:25:33-04:00" -- must be converted to UTC Z before any envelope use |

Sessions row shape: {run, store, state, role, loadout, mission, age}.
Roster row shape: {id, state, mission, source, age}. Ages are float
seconds relative to invocation -- unstable, never usable as ts.

### 2.2 Window + spine recommendation

- The readout is CURRENT STATE, not an event stream: queue rows carry
  no ts at all, sessions/roster ids churn hourly (evacuated beacons),
  and `generated` is the only invocation timestamp.
- For the history/1 spine, only `timeline` rows carry a native ts
  (date-only). If included: `key` = `timeline:<date>-<name>`,
  `ts` = `<date>T00:00:00Z` (date-precision convention, schema
  sibling section 4), `summary` = name, `source` = "timeline". All 9
  rows are dated 2026-08-25, far outside any recency band, but with
  count-based caps they still emit (9 <= any sane cap).
- Recommendation: EXCLUDE queue / etas / sessions / roster / verdict
  from history entries. Queue rows would need a synthetic ts (only
  candidate: queue.md last commit 2ad2dfa9, 2026-09-13, a ceremony
  candidate), and sessions/roster entries would duplicate themselves
  every hour with new store ids. Serve them as a state sidecar
  (separate feed or future envelope), not as history/1 entries.
- Staleness: the readout regenerates per invocation (`generated`).
  Source files are slow-moving committed surfaces: timeline.md last
  commit 27496458 (2026-09-06), queue.md last commit 2ad2dfa9
  (2026-09-13).

## 3. Source S3: research lines (scope + output format)

### 3.1 Files and MCP read side

- `automation/research-lines.tsv`: 159 rows, 4 cols
  (line, status, date, title). Status histogram: reviewed 133,
  planned 24, crystallized 1, contracting 1. Line ids ALL UNIQUE
  (verified, no duplicates). `date` is full Z-form second precision
  in 159/159 rows (copy verbatim). Date spread 2026-09-07..09-15
  (09-15 x48, 09-14 x35, 09-08 x30, 09-13 x19, 09-12 x15, 09-11 x9,
  09-10 x2, 09-07 x1). Max title length 417 chars.
- `automation/research-dispositions.tsv`: 162 lines = 1 header + 161
  rows, 9 named cols (line, action, verdict, reviewer, evidence,
  date, support, oppose, followons). Action histogram: adopted 71,
  parked 59, killed 30, fixed 1. `date` is date-only (normalize to
  `T00:00:00Z`). 123 rows fall in the last 7 days (>= 2026-09-09).
  Max verdict length 1294 chars.
- MCP `research_lines` tool (automation/mcp/hngh_mcp_server.py:96-110)
  reads both TSVs via `read_tsv` (:72-93) with ROW_CAP = 200 per file
  (:31) and returns `{lines, dispositions, truncated, counts}`.
  Fail-closed on MORE-than-expected columns (RuntimeError at :88);
  short rows zip-short silently.

### 3.2 Data-quality facts that shape the window

- Rows are served in FILE ORDER = append order = OLDEST-FIRST. The
  ROW_CAP truncates the TAIL, so the NEWEST rows are dropped first.
- Both files are under the cap today (159/161 < 200, truncated =
  false, counts {lines: 159, dispositions: 161}, full coverage), but
  dispositions append 20-50 rows/day (hist-dispositions-b tail:
  09-13 x20, 09-14 x49, 09-15 x23). The file crosses 200 rows within
  days. From then on the MCP feed silently serves the OLDEST 200 and
  hides the newest reviews, with only `truncated: true` as the
  signal.
- Column drift in dispositions: 3 rows are 5-col misaligned (file
  lines 61, 82, 102 -- the slow-unit lines). The date value lands in
  the `evidence` slot and the parsed dict has NO `date` key (the MCP
  output confirms `evidence: "2026-09-12"` for line 61). 67 rows are
  6-col (support/oppose/followons absent), 2 rows 8-col, 89 rows
  full 9-col. Consumers must treat `date` as optional and validate
  column shape.
- Dispositions are NOT unique by line id: same-day multi-reviewer
  rows exist. At least 10 duplicate (line, date) pairs today, and
  (line, date, action) still collides: fail-20260911-system-network-
  down has two `adopted` rows on 2026-09-11 from different reviewers
  (openrouter/z-ai/glm-5.3-flash and lobehub).

### 3.3 Window and output format

- Scope: BOTH TSVs together (the MCP tool's contract: lines +
  dispositions with counts and a truncated flag).
- Window: sort newest-first by row date AFTER read. Never trust file
  order. Proposed caps: HIST_CAP_RLINES = 50, HIST_CAP_RDISP = 50
  (7 days of dispositions is 123 rows today, so 50 covers ~3 days of
  review churn; lines churn slower). The spine producer should read
  the TSVs directly. The MCP tool is acceptable as a read side ONLY
  while under its 200 cap: check `counts` + `truncated` and fail
  over to a direct file read when truncated = true (or fix read_tsv
  to keep the newest N instead of the oldest N).
- Entries:
  - lines: `key` = `rline:<line-id>` (verified unique), `ts` = row
    date verbatim (already Z-form), `summary` = title (417 chars max
    observed; the 200-char + "..." rule from caps sibling 3.2
    applies), `source` = "rline", additive `kind` = status
    (reviewed / planned / crystallized / contracting).
  - dispositions: `key` = `rdisp:<line>:<date>:<sha8(verdict)>`
    where sha8 = first 8 hex of sha256 of the verdict text
    (report-queue id precedent). Verdict text differs across
    same-day reviewers, so this disambiguates the multi-review rows.
    If a hash collision ever survives, append an occurrence ordinal.
    `ts` = `<date>T00:00:00Z`, `summary` = verdict (1294 chars max
    observed; always apply the 200-char + "..." rule; verdicts begin
    with the action keyword, which survives the cut), `source` =
    "rdisp", additive `kind` = action (adopted / parked / killed /
    fixed), `ref` = evidence path when the value looks like a path
    (the 3 misaligned rows carry a date there, so skip `ref` for
    them).
- Freshness: both TSVs were committed today (research-lines.tsv:
  ff627ba8 10:15, f8982a26 10:03, 485474f6 09:50 EDT; dispositions
  mtime 2026-09-15 10:15). The hour-tier kernel-ledger-sync commits
  docs/ surfaces once per hour (rp-mirror), so git-level readers can
  lag up to ~1h; live file reads do not lag.

## 4. Constants (extend hist-windows-caps section 7)

```
HIST_CAP_REPORT   = 50   # already defined; ledger-native newest-50
HIST_CAP_TIMELINE = 30   # readout timeline rows if included (9 today)
HIST_CAP_RLINES   = 50   # research-lines.tsv rows, newest by date
HIST_CAP_RDISP    = 50   # research-dispositions.tsv rows, newest by date
```

The readout state block (queue / etas / sessions / roster / verdict)
contributes no history entries and therefore carries no cap here; it
belongs to a state feed, not the history spine.

## 5. What I did not check

- Whether the spine producer should read the TSVs directly vs through
  the MCP process boundary (only shape and caps were specified).
- Whether research-lines.tsv is ever pruned (no prune observed;
  append-only assumed from hist-dispositions-b).
- `report-queue --list` output serialization (not needed: the ledger
  table parse is the specified read side and --json covers metadata).
- Whether a future state feed should reuse the readout spine keys
  verbatim or define a new envelope.
