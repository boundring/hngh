# Heartbeat action cards

`scripts/schedule-heartbeat` only triggers a driver for an item when a
**card** is mounted here. A card is how the operator says "this queue
item's autonomous lane is ready" — without a card the heartbeat stays
cadence-only and takes no action.

Card files are named after the queue item id:

- `<id>.rotation` — mount the rotate-queue ceremony for this item.
  - line 1: the objective string (passed to the ceremony).
  - lines 2+: repository-relative candidate files, one per line
    (`#` comments and blank lines skipped).
  - A rotation card means "when this item is Next, close its slice
    through the full governance loop using these files".
- `<id>.worker` — mount the bounded worker-driver cycle.
  - line 1: the objective string.
  - line 2: the worker task label.

Malformed cards (a file exists but has fewer than two content lines)
fail the tick closed with exit 2 — a stale half-written card must not
silently disable a lane.

Example `wake-mutation-lane.worker`:

```
# bounded recon for the wake lane (read-only scout, no mutation)
scout wake-mutation-lane
```

Example `doc-sync-loop.rotation` (already done; shown as shape):

```
Sync the README check count to the live suite
tests/scripts/test-doc-numbers.py
README.md
docs/project/roadmap.md
```

Cards are committed, just like every other ledger fact — the mounted
lane is public evidence, not a shadow config.