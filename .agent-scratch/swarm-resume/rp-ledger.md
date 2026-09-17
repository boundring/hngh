# rp-ledger — Stage 2 ledger write path (report-queue --add / --identity / --evidence / --window)

Task: map the write side of `scripts/report-queue` into the
`docs/project/reports.md` row format plus `docs/project/report-bodies/<ts>-<kind>-<id>.md`
body meta, and verify the dedup and suppression rules. Sibling artifact
`workq-report-shape.md` covers the read side; this artifact is write-only.
All claims below carry file:line evidence; live-ledger checks were read-only,
and behavioral probes ran hermetically in a temp `HNGH_REPORT_ROOT`.

## 1. Surfaces

- Writer: `scripts/report-queue` (kernel surface; machine commits need the
  ceremony label per AGENTS.md "repo-root scripts/ is kernel code surface").
  - Entry: `add()` at scripts/report-queue:211-252.
  - CLI wiring: `main()` at scripts/report-queue:412-415 passes
    `--identity`, `--window` (default 86400 at :414), `--evidence`.
- Callers (write side): ~35 sites. Representative:
  - `automation/jobs/patrol.py:1321-1336` `report_alert()` — the only
    `--evidence` caller (argv built at :1335), identity `"patrol:" + pid`,
    window 86400, evidence = the failing detail line (call at :1434).
  - `automation/scripts/router-tick.py:100-108` `report()` — identity
    `router:routed:<slug>` / `router:dedup:...`, window 86400.
  - `automation/cadence/hour/33-research-beat.sh:184`,
    `automation/cadence/day/06-remote-posture.sh:46`,
    `automation/lib/notify-email.sh:61`, `automation/scripts/service-ctl.sh:115`
    (window 3600), `automation/cadence/day/25-wiki-health.sh:69` (weekly).
- Tests: `tests/scripts/test-report-queue.py` (hermetic temp root, :24-28).

## 2. Ledger row format (reports.md)

Header (exact, scripts/report-queue:79):

```
| timestamp | kind | id | first line | body |
```

A new report appends one line at end of file (oldest-first; append at
scripts/report-queue:250-251):

```
| {ts} | {kind} | {rid} | {first} | {body_name} |
```

Field derivation in `add()`:

| Cell | Value | Evidence |
|------|-------|----------|
| ts | `now_ts()` UTC ISO second `%Y-%m-%dT%H:%M:%SZ` | scripts/report-queue:87-88, 222 |
| kind | must be in KINDS {progress, expense, optimization, scheduled, alert}; else exit 2 before any write | scripts/report-queue:71, 212-215 |
| id | first 8 hex of sha256 of the full stripped TEXT | scripts/report-queue:83-84, 220 |
| first line | first line of TEXT, stripped | scripts/report-queue:221 |
| body | body FILENAME `{ts}-{kind}-{rid}.md`, not the body text | scripts/report-queue:111-116, 251 |

Refusals before any write: bad KIND (exit 2, scripts/report-queue:212-215),
empty/whitespace TEXT (exit 2, :216-218). `ensure_header()` (:138-143)
creates the file with the header, or prepends the header if missing.

On dedup bump the row is REWRITTEN IN PLACE: first-line cell gains/updates a
trailing ` xN` marker (count = old + 1; an existing marker is replaced, not
stacked) while ts/kind/id/body-name cells keep their ORIGINAL values —
`bump_row()` at scripts/report-queue:188-208 (regex ` ×(\d+)$` at :191,
replace at :193, in-place rewrite matching `cells[:3] == [ts0, kind, rid]`
at :200, whole-file rewrite at :206). A matched row that vanished between
read and bump raises "row vanished mid-bump" -> exit 2 (:204-205, 245-247).

## 3. Body file format and meta (report-bodies/<ts>-<kind>-<id>.md)

`write_body()` at scripts/report-queue:119-126 emits, in order:

```
# {kind} — {rid}

- **timestamp:** {ts}
- **kind:** {kind}
- **first line:** {first}
- **identity:** {KEY}          <- only when --identity passed on the FIRST add
- **last-evidence:** {TOKEN}   <- only when --evidence passed

{full TEXT}
```

- `identity` is written on first add only (:121, :249); later matching adds
  never rewrite it — matching reads it back via `row_identity()`
  (:146-151, prefix scan for `- **identity:** `).
- `last-evidence` on first add sits in the meta block (:122). On a bump with
  changed evidence, `set_body_evidence()` (:162-174) REPLACES an existing
  `- **last-evidence:** ` line in place, or APPENDS it at the END of the
  body if none existed. Verified hermetically: a first add without
  `--evidence` then a bump with one puts `last-evidence` at the last line,
  after the TEXT and the occurrence lines (parse still works because
  `body_evidence()` (:154-159) is a prefix scan, but the meta line lands
  outside the meta block — cosmetic wart, read-safe).
- Occurrence lines: on each dedup bump, `- {new-ts} occurrence` is APPENDED
  to the body (scripts/report-queue:207-208).
- Suppression breadcrumbs: `- {new-ts} suppressed duplicate (no new evidence)`
  appended to the body on an evidence-identical re-fire (:233-236), with a
  stdout notice and exit 0 (no bump, no new row, :237-239).
- The em dash in the `# {kind} — {rid}` heading is written by the script
  itself (:124); it is file format, not agent output.

Live example (read-only): row `reports.md:3218`
`| 2026-09-15T09:48:53Z | alert | c16c59bf | patrol automation-gate: ... |`
has body `docs/project/report-bodies/2026-09-15T09:48:53Z-alert-c16c59bf.md`
carrying `- **identity:** patrol:automation-gate`,
`- **last-evidence:** hngh-automation: make test rc=2`, then 7
`suppressed duplicate (no new evidence)` breadcrumbs.

## 4. Dedup rules (--identity / --window)

Flow in `add()` (scripts/report-queue:223-247):

1. Scan rows NEWEST-FIRST (`reversed(read_rows())`, :224); skip rows of a
   different KIND (:225-226). First (newest) match of stored identity wins.
2. Match condition: `row_identity(r) == identity and within_window(r[0], window)`
   (:227). Matching is on KIND + stored identity, NOT text — TEXT drift is
   tolerated by design (docstring :24-26).
3. Window: `within_window()` (:177-185) measures age from the ROW's ORIGINAL
   ts, not from the last bump — a bumped row does NOT refresh its window.
   Default 86400 s; `--window 0` = unlimited lookback (:178-180). A row older
   than the window is skipped and a NEW row is appended (with identity
   re-stored), verified by `test_identity_window_expiry_and_unlimited_zero`
   (tests/scripts/test-report-queue.py:187-202).
   Consequence in the live ledger: a persistent condition with a 24 h window
   produces one row per day — identity `patrol:automation-gate` exists as
   2026-09-14 row (reports.md:2844) AND 2026-09-15 row (reports.md:3218),
   because the 09-14 row aged out of the 86400 s window.
4. No match / different identity -> plain append. Different identity with the
   SAME text still adds a new row
   (test_different_identity_adds_new_row, tests/.../test-report-queue.py:204-207).
5. Alternating identities in one window each keep their own single row —
   the scan walks past other identities' rows
   (test_identity_dedup_scans_past_other_identities, tests/...:209-229).

Verified behaviors (hermetic temp-root probe + existing tests):

- 2nd/3rd same-identity adds: 1 row, first line `... x2` then `x3` (marker
  replaced), 1 then 2 `occurrence` body lines
  (tests/scripts/test-report-queue.py:167-185).
- Window expiry -> 2nd row; `--window 0` re-dedups even against the
  backdated row (tests/...:187-202).

## 5. Suppression rules (--evidence)

Checked only INSIDE the identity-dedup branch (scripts/report-queue:233),
after a kind+identity+window match, before the bump:

- Stored `last-evidence` == new TOKEN -> SUPPRESS: append breadcrumb line to
  the matched body, print `report-queue: suppressed duplicate alert {id}
  (no new evidence since {orig-ts})`, return 0. No xN bump, no new row
  (scripts/report-queue:233-239). Hermetic probe confirmed: stdout notice,
  row count and marker unchanged, breadcrumb present in body.
- Stored evidence differs (or none) -> BUMP: `bump_row()` then
  `set_body_evidence()` stores the new token (:240-243).
- `--evidence` WITHOUT `--identity` is INERT for dedup: the evidence branch
  is unreachable without an identity match, so each add is a plain new row
  (hermetic probe: two evidence-only adds -> two rows, no suppression). The
  token still lands in the new bodies' meta.
- Evidence is a caller-derived token from fresh failing state (docstring
  :36-38); the only live derivation is patrol.py:1434 passing the failing
  `detail` line. A CONSTANT token would suppress every re-fire after the
  first — the docstring explicitly warns against constants (:37-38).
- Race note (write-order): bump happens BEFORE set_body_evidence
  (:240-243). A crash between the two leaves the bumped row carrying the
  OLD evidence, so the next same-evidence re-fire is suppressed even though
  the condition recurred with new evidence that was already reported once
  (missed-evidence window). Bump itself is also a two-file write
  (reports.md rewrite at :206 then body append at :207-208) — a crash
  between leaves the marker without its occurrence line.

## 6. Write-path hazards found (with live/verified evidence)

1. PIPE GHOST ROWS. The writer interpolates TEXT raw into the row
   (scripts/report-queue:251) with no escaping, but the readers accept only
   rows with EXACTLY 5 pipe-split cells (read_rows() :105-107; bump_row()
   :199-200). Any `|` inside TEXT makes the row invisible to --list/--json/
   dedup/prune while still occupying the file. LIVE: 49 rows with NF>7,
   e.g. reports.md:17 (`... credential-health.sh | credential-health |
   loop retry ...`). A ghost row can never be bumped (invisible to the
   match scan) and never pruned; an identity-less re-add of the same text
   appends a duplicate row.
2. ID COLLISION / DUPLICATE IDS. id = sha8(TEXT) (:220) is not
   uniqueness-checked on append. LIVE: id `cf2fc04a` appears twice
   (reports.md:18, :19) — an identity-less re-add of identical text within
   minutes produced two rows. `--mark-read`/`--unread` locate the cursor by
   id; `unread_rows()` (:284-287) stops at the FIRST (oldest) match, so a
   duplicate id can leave rows between the two occurrences permanently
   unread-visible (fails open, never hides, but never advances past either).
   Bumps are safe (they match ts+kind+id triple, :200).
3. NO FILE LOCK. Two concurrent `--add` runs with the same identity can both
   scan before either writes, producing two rows for one identity. Cadence
   is timer-serialized so this is latent, not live.
4. HEADER MUTATION. `ensure_header()` (:138-143) prepends the header to a
   file that lost it — a rare non-append mutation of reports.md (only on
   corruption repair).
5. Evidence meta placement wart (see section 3): late `--evidence` appends
   the meta line at the body's end rather than in the meta block
   (set_body_evidence :172-173).

## 7. Test coverage of the write path

tests/scripts/test-report-queue.py covers: add row+body (:88-102), bad kind /
empty text refusal (:140-150), identity dedup with xN + occurrence lines
(:167-185), window expiry + `--window 0` (:187-202), different identity
(:204-207), alternating identities (:209-229), prune (:231-267), help
documents the flags (:269-273). NOT covered: `--evidence` suppression (no
occurrence of "evidence" anywhere in the test file — the suppression branch
scripts/report-queue:233-239 has no regression test), pipe-in-text ghost
rows, duplicate-id append, bump/set-evidence crash ordering. Hermetic probes
this session confirmed the documented evidence behavior works, but nothing
pins it.

## 8. Read-side summary counts for cross-check (from queue-report MCP)

Summary: progress 2931, scheduled 34, optimization 12, alert 232; unread 215.
The bumped rows visible in the live feed (`de42b67b x3`, `a00b01ca x3`,
`dd16b84b x2`, `c16c59bf` with 7 suppressions) match the write rules above.

## 9. Conclusion

The write path is: validate -> (identity match within window) -> either
suppress-with-breadcrumb / bump-in-place-with-xN-and-occurrence, or
append-new-row + write body file with identity/evidence meta. Dedup and
suppression rules verified as documented against both the hermetic harness
and the live ledger, with two structural write hazards confirmed live
(pipe ghost rows, duplicate ids from identity-less re-adds) and one
untested-but-working branch (--evidence suppression) that deserves a
regression test before any change to it. Any fix lands on kernel surface
(scripts/report-queue + tests/scripts/test-report-queue.py) and therefore
requires the ceremony label, not the automation free-commit rule.
