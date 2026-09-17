# workq-rotate-shape: rotate-queue script, state file, rotation semantics, ordering fields

Inspected 2026-09-15. Read-only: `scripts/rotate-queue` (SBCL),
`scripts/dashboard-readout`, `scripts/omp-bridge`, `docs/project/queue.md`,
`automation/jobs/schedule-feed.py`, live `readout.json`. No repo edits.
Siblings: workq-report-shape.md (report-queue JSON), workq-staleness.md
(staleness rules), rp-mirror.md (mirror mechanics).

## 1. The script: `scripts/rotate-queue` (SBCL --script, loads hngh.asd)

Closes one queued item through the full governance loop. "The script adds
no authority" - each step is a closed command an operator would run by hand.
Periodic invocation belongs to the operator's scheduler, never inside hngh
(no daemon/watcher).

Usage: `sbcl --script scripts/rotate-queue --store=PATH --item=QUEUE_ID
(--reviewer=REVIEWER_FILE | --route=auto|local|remote) OBJECTIVE FILES...`

Exit codes: 0 rotated/committed; 1 refused or verdict not admitted;
2 malformed invocation; 3 transport fault.

Rotation steps (in `rotate`):
1. `queue-row-flip`: rewrite `docs/project/queue.md` in place, setting the
   item's status column to `done` and the evidence column to `rotated <UTC
   date>`. Errors if the item id is not found (fail closed).
2. `gather-evidence`: real candidate evidence via
   `hngh.adapters.run-gather:run-candidate-evidence` over the objective's
   files PLUS the queue file itself: repo identity, base revision, content
   hash, per-file source-manifest entries with live SHA-256s. Refusal aborts.
3. Reviewer routing: `--route` probes via `scripts/probe-model-route`
   (one bounded read-only probe); local -> `~/.hngh-automation/reviewer-local.conf`,
   remote -> `~/.hngh-automation/reviewer-remote.conf`. Note: secrets stay
   in the `~/.hngh-automation` home (two-home split).
4. Kernel steps through `hngh.main:dispatch-command`:
   `create-run` (builder loadout, route label "remote" or "model") ->
   `admit-transport run-1 model repository` -> `review run-1
   content-hash=... paths=... reviewer=...` -> `propose` under the ten
   principles (closed-authority ... source-grounding), each with
   `evidence-requirements=<principle>:claim-proof:<content-hash>`.
5. The rendered proposal verdict is written to a temp file and bound:
   `issue-cert prepare-candidate` then `mutation-check prepare-candidate`,
   then `issue-cert commit` + `mutation-check commit` with all files
   (objective files + queue.md). Queue ledger lands in the same candidate
   commit (atomic: queue flip + work commit are one certificate).

## 2. State file: `docs/project/queue.md`

- 4-field TSV with a header line: `id \t status \t title \t evidence`.
- Status vocabulary: `queued | active | done` (parser accepts exactly these
  three; see dashboard-readout `queue_items`).
- Row semantics per the file header: "rotate-queue turns the crank" through
  `queued -> active -> done`. One row per item; full proposal prose lives in
  `docs/project/backlog.md` under the same id; this file is rotation state.
- Extra sections parsed by consumers:
  - `## Next` (line ~45): markdown bullet `- **<id>** - <why>`; names the
    single next rotation item. Parsed by `scripts/omp-bridge queue_next()`
    (NEXT_RE + BULLET_ITEM regexes) and mirrored in
    `automation/jobs/plan-feed.py queue_next()` (same approach).
  - `## ETA` (~line 105): bullets `- <id> - <window text>` (em dash);
    operator-set planned windows. Parsed by dashboard-readout
    `queue_etas()`: takes the LAST `## ETA` section (duplicate-proof), ends
    at the next `## ` heading, skips tab/code lines, entries whose window
    starts with `DONE` are excluded (never drawn as a future bar).
- Current live state: `## Next` = `node-lattice-admission` ("rotate next,
  unblocked: wake-mutation-lane landed 2026-09-13").

## 3. Fields feeding upcoming-work ordering

### dashboard-readout `--json` spine (written to readout.json by
### automation/jobs/refresh-dashboard.sh via atomic tmp+mv)
- `queue`: `[{"id": ..., "status": ...}, ...]` - built by `queue_items()`:
  every 4-tab-field queue.md line whose status is queued/active/done, in
  FILE ORDER (which is also insertion order; no sort key in the TSV itself).
- `etas`: id -> window-text map from the `## ETA` block.
- Display order only (`order_queue`, stable sort): rows with
  `status == "active"` float above all others; everything else keeps file
  order. Ordering only, never fabrication (stable sort, nothing dropped).
- Spine staleness: `STALE_SPINE_SECONDS = 86400` - committed spine
  (timeline/queue) stale after a full day without rotation (see
  workq-staleness.md for the tier/multiple feeds).
- Verdict spine key: `all-clear` when queue.md and timeline.md both read
  cleanly AND no run needs attention (dead/unknown states fail closed).

### schedule-feed.py `oneoff_rows` (upcoming-work schedule builder)
Reads `readout.json` queue + etas:
- Skips rows with `status == "done"`; keeps queue file order.
- `estimate_for`: honest estimate chain - time-ledger p50 first, then
  `:TIME-LIMIT N` grep from session tails x 0.5, else DEFAULT_EST_S = 30m
  (`placeholder: true` when default).
- Dependencies parsed from ETA text `after <token>`: exact id match in the
  queue id set, short tokens (<4 chars, e.g. "a") discarded, else unique
  prefix match over sorted ids. Output rows:
  `{name, depends_on, estimate_s, estimate_source, status, placeholder}`.

### omp-bridge `--orient` brief
Surfaces `queue_next()` (the `## Next` id) plus roadmap Next, dirty-tree
state, last ceremony commit - the "do not re-walk" handoff.

## 4. Takeaways for consumers
- The TSV itself has no ordering column: priority = position in file, and
  the designated next item is the `## Next` block, not a field.
- Rotation is atomic with the work commit (same certificate-bound commit);
  readout.json queue is derived and lags by the refresh tick (30m cadence,
  per-PID tmp, see workq-staleness.md).
- ETAs are prose-parsed (em dash separated, `after X` dependency tokens) -
  fragile by design tradeoff, guarded by last-section-wins and DONE
  exclusion rules.
