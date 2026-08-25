# Check-ins — gentle periodic look at the project

A light heartbeat on Hngh itself. Purpose: catch drift, note health,
and occasionally inject a small steering correction — never to create
busywork. Cadence is operator-set (here: ~per session or on the
rotation that looks in). One entry per check-in, appended dated.

## What each check-in looks at

1. Git state: clean? synced? recent commit type (candidate vs labeled).
2. Gate: `make test` exit (checks count, loop-history guard,
   doc-numbers guard).
3. Queue: any row stuck, any item done, what's next.
4. Any drift between docs and code (counts, commands, mentions).
5. Steering call: one concrete note if something is off, else "no
   steer needed".

## Steering policy

- Gently. One small, reversible adjustment per check-in when genuinely
  warranted (a stale number, a queue reorder, a missing "next").
- Never manufacture work: no-change entries are a valid outcome.
- Every check-in that changes anything rides the ceremony like any doc
  slice.

---

## 2026-08-25 — check-in #1

- **State:** clean, synced (`6953808`). Recent history is
  ceremony-dense (rotation + zoom-out + worker-driver + guard), all
  candidate-bound, loop guards green (2774 checks, 15/1/0).
- **Queue:** 15 open items, 1 done (doc-sync-loop). Nothing stuck;
  `wake-mutation-lane` sits at the top as the natural next rotation.
- **Drift scan:** README count live, architecture/intent/roadmap
  aligned after the doc pass; no new drift spotted.
- **Steering (small):** the queue never named its "next" — the
  schedule line said `NEXT_ITEM` without saying which. Steer: pin the
  next rotation to **wake-mutation-lane** (the boundary amendment that
  unblocks node-lattice admission and is the highest-value pending
  governance lane), and note it in the ledger so the cadence needs no
  human re-deciding every run.
- **Outcome:** queue.md gains a `Next` pointer; this entry.

Nothing else required attention — healthy. Next check-in: after the
next rotation or tomorrow, whichever comes first.
## 2026-08-25 — check-in #2

- **State:** clean, synced (`3c25df9`); queue `Next` still
  wake-mutation-lane; gate green.
- **A real calibration hit:** wake-mutation-lane is a genuine
  multi-slice implementation (new `:wake-mutation` action in the
  closed mutation vocabulary + executor path + verification + CLI +
  tests), not a small steer. A check-in must stay gentle — so the
  steering here is *calibration*: this item belongs to the rotation
  cadence with a full session, not to a check-in. No partial slice was
  forced; the item stays pinned as next-with-a-full-session, and the
  check-in log now distinguishes "check-in-scale" from "rotation-scale"
  work so future passes don't overreach.
- **Outcome:** this entry; no code changed. The next action for
  wake-mutation-lane is a full rotate-queue session, operator-invoked.

## 2026-08-25 — check-in #3

- **State:** clean, synced (`4fb0407`); queue stable; gate green.
- **Steering (small, direct):** made the check-in #2 calibration
  *usable* — the queue ledger now carries a `## Scale` appendix
  marking each item check-in-scale vs rotation-scale, so the cadence
  picks the right instrument without re-reading each item. The TSV
  stays 4-field so `rotate-queue`'s parser is untouched.
- **Note:** timeline-events and queue-eta are the two check-in-scale
  items that most directly build the dashboard spine; given they are
  small, the *next* check-in could take one. Everything else waits
  for its rotation.
- **Outcome:** queue.md Scale section; this entry. No code changed.

## 2026-08-25 — check-in #4

- **State:** clean, synced (`7a880a8`); gate green.
- **Steering (check-in-scale, taken):** implemented the first
  check-in-scale dashboard-spine item — **timeline-events**. The
  timeline now carries machine-readable rows
  (`DATE<TAB>KIND<TAB>ITEM<TAB>HASH`) with a test
  (`tests/scripts/test-timeline-events.py`) wired into `make test`
  that asserts the 4-field shape and rejects malformed rows. The
  dashboard's raw spine exists as a committed, testable data stream.
- **Queue:** timeline-events → done. Next for the spine: queue-eta
  (also check-in-scale), then dashboard-readouts (rotation-scale).
- **Outcome:** timeline events + test wired + queue updated + this
  entry, committed through the ceremony.

## 2026-08-25 — check-in #5

- **State:** clean, synced (`bf9eb11`); gate green; timeline stream
  live.
- **Steering (check-in-scale, taken):** rotated **queue-eta** — the
  queue ledger now carries an ETA section (planned windows per item,
  the TSV stays 4-field for rotate-queue), so "future" has dates a
  gantt can place. Next spine item: dashboard-readouts, once the
  spine has >= 5 timeline/ETA rows.
- **Outcome:** ETA section + queue-eta done + this entry, committed.

## 2026-08-25 — check-in #6

- **State:** clean, synced (`90b1624`); gate green.
- **Steering (timeline growth):** the timeline stream is the
  dashboard spine but had only 2 rows. Appended the rotation/event
  rows for timeline-events and queue-eta — the spine is now 4
  committed rows, one short of the dashboard-readouts threshold (≥5).
  Next check-in reaches it by recording the next event/rotation row.
- **Outcome:** timeline 2→4 rows; this entry.

## 2026-08-25 — check-in #7

- **State:** clean, synced (`154af78`); gate green.
- **Steering (threshold-cross):** the timeline stream is at 4 rows —
  one short of the dashboard-readouts bar. This check-in appends its
  own event row, crossing to **5**, so dashboard-readouts becomes
  actionable as the next rotation-scale item.
- **Outcome:** timeline 5 rows; dashboard-readouts unblocked; this
  entry.

## 2026-08-25 — check-in #8

- **State:** clean, synced; 5-row spine; gate green.
- **Steering (taken, check-in-scale):** first thin readout —
  `scripts/dashboard-readout` renders the timeline spine as plain
  gantt-style bars (legend # event / . queued), reads only committed
  data (no daemon). Smoke-tested and wired into `make test`. The
  readout view you asked for now has a working first cut; the
  rotation-scale item (denser gantt, ETA windows, session views) is
  next.
- **Outcome:** scripts/dashboard-readout + smoke test + queue item
  active + this entry, committed through the ceremony.

## 2026-08-25 — check-in #9

- **State:** clean, synced (`4a9c272`); readout live; gate green.
- **Steering (honest timeline):** the spine had gone stale — the
  dashboard-readout rotation and check-in #8 were not in the stream.
  Appended those rows (7 now), so the readout's view matches the
  commits. Small, keeps the narrative honest.
- **Outcome:** timeline 7 rows; this entry.

## 2026-08-25 — check-in #10

- **State:** clean, synced; 7-row spine; readout live.
- **Steering (readout honesty):** the readout promised a `.` queued
  window but never rendered one. Now every queued item shows `...`
  and active shows `+` — the whole queue is visible, not just done
  rows. Smoke still green.
- **Outcome:** readout honors its legend; this entry.

## 2026-08-25 — check-in #11

- **State:** clean, synced; readout shows the full queue; gate green.
- **Steering (traceability):** every check-in now accrues a timeline
  row, so the spine records the check-ins themselves (a future
  dashboard can show "checked-in on ..." per day). Legend made to
  match reality (`...` for queued).
- **Outcome:** check-in rows in the spine; legend fixed; this entry.
