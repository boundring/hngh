# rp-mirror: Stage 3 dashboard mirror + report-cursor semantics

## Mirror mechanism: symlinks, not a copy job

`automation/jobs/refresh-dashboard.sh` does NOT copy reports.md or report-cursor.
It refreshes data.json (via `update_dashboard`, line 9), readout.json
(lines 14-25), sessions.json (30-34), operator-items.json (38-42), and kb/
(47-51). The ledger mirrors are instead **symlinks committed to the repo**:

- `automation/dashboard/reports.md -> ../../docs/project/reports.md` (symlink, mtime Sep 11)
- `automation/dashboard/report-cursor -> ../../docs/project/report-cursor` (symlink)

Consequence: the served mirror is always live with the kernel ledger — there is
no copy step and no refresh lag. Both symlinks are committed
(13bd1761 "automation: commit dashboard ledger symlinks (CI red — symlink contract test)");
`git check-ignore` does not ignore them (the "runtime serves gitignored
dashboard/ copies" note in research-dispositions.tsv:107 refers to other
dashboard artifacts, e.g. readout.json/session feeds, not these two).
Contract test: `automation/tests/test-dashboard-p1-ui.py:107-128`
(`test_unread_rows_derived_from_ledger_mirror`) asserts `p.is_symlink()` and
resolves each symlink's target name (lines 122-127).

## Serving path

- Client (`automation/dashboard/app.js:338-383`): `fetchText('reports.md')` +
  `fetchText('report-cursor')` (lines 357-358) with `cache: 'no-store'` and an
  8s abort timeout (lines 330-336). `reports.md` unavailable => the queue
  widget renders "ledger mirror unavailable — read state CLI-only"
  (lines 381-385) rather than stale data.
- `automation/dashboard-server.py` serves the dashboard/ dir statically;
  `jailed_doc_path` (lines ~274-284) is the general symlink/traversal jail for
  other doc routes (realpath must land inside base, fail closed).

## report-cursor semantics

`scripts/report-queue:77` — `CURSOR = ROOT / "docs" / "project" / "report-cursor"`;
current content is a 9-byte single report id.

- `cursor_id()` (lines 269-271): file absent/empty => None.
- `unread_rows()` (lines 274-286): everything strictly AFTER the cursor id in
  file order (oldest-first) is unread. **Fail-open**: unknown/absent cursor id
  => all rows unread ("no report is silently hidden by a stale cursor").
- `mark_read(rid)` (lines 294-297): refuses unknown ids (ValueError => rc 2),
  else rewrites the cursor file to that id. `--prune` stays CLI-only
  (destructive; app.js comment line 343).

## Web mark-read path

`dashboard-server.py:637-660` `_mark_read`: validates id against `SESSION_RE`
(400 on bad id), shells out to `python3 scripts/report-queue --mark-read <id>`
with 15s timeout, maps rc != 0 to 400 "report-queue refused (rc=N)", then
appends a `mark-read |` row to the handoffs ledger and returns 201.
Client (`app.js` ~395+) posts `{id}` via token-guarded `postJson` and surfaces
errors inline (`rqState.error`); the Sep-12 stale-server incident (76 clicks
swallowed by `.catch(fetchQueue)`) is guarded by
`test-dashboard-p1-ui.py:115-121` asserting the swallowing catch is absent.

## Staleness behavior (verified)

- Mirrors: symlink => zero staleness by construction; a ledger append is
  immediately visible to the next fetch (no-store).
- Commit lag only: kernel ledgers live in git; hour-tier
  `automation/cadence/hour/30-kernel-ledger-sync.sh:1-45` commits dirty
  docs/ surfaces (including docs/project) once per hour, refusing when staged
  changes exist. So repo-level readers can lag up to ~1h; the live dashboard
  does not.
- Client-side failure = fail-visible: mirror fetch failure disables the queue
  read state rather than showing stale unread counts (app.js:381-385).

## Cross-refs

Ledger write side: see sibling artifact rp-ledger.md. Queue row shape /
5-column table parse: workq-report-shape.md (client parser app.js:345-355
expects 5 cells: ts, kind, id, first-line, status-ish).
