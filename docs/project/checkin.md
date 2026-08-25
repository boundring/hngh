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
