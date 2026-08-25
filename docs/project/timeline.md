# Timeline — the queue that runs itself

How the rotation cadence turns into a visible, traceable schedule:
heartbeat artifacts, zoom-out passes, and the entities a future
dashboard could draw.

## Cadence and heartbeats

- **Rotation cadence** (operator-owned cron): `scripts/rotate-queue`
  closes one queued item per run. Each rotation lands a certificate-bound
  commit + flips the queue row + records the run in a fresh store.
- **Heartbeat artifact per rotation**: the candidate commit itself is
  the heartbeat — `git log` is the ledger of when each item moved
  `queued → done`. The store ledger adds run-level state per rotation.
- **Zoom-out pass** (operator-owned, ~weekly): a scout polls
  market/news/opportunity sources (terminalfeed.io, nothumansearch.ai,
  agent-market research) and the findings feed new queue candidates or
  de-prioritize existing ones. Recorded as a dated queue/zoom entry.

## Entities a future dashboard could observe

Current and near-future data that a gantt/readout dashboard could draw:

- **Runs** — per-rotation run records (identifier, state, role,
  loadout, mission, receipt kinds) already rendered by `present`; the
  timestamps are in receipt facts.
- **Queue rows** — the ledger (id, status, title, evidence, and, once
  added, ETA). A gantt's left-of-now columns are `queued`, its now
  bar is `active`, its right-of-now is `done` on the timeline.
- **Candidate commits** — every ceremony produces one; the commit
  graph is the completeness/momentum view.
- **Rotation events** — a future machine-readable `timeline` line per
  rotation (id, state, timestamp) unlocks past/present/future session
  views without a daemon: each rotation emits one line to a store, and
  the dashboard reads lines, never polls a process.

## Planned entities (to add, not yet built)

- `timeline-events` (machine-readable ledger line per rotation) —
  queue candidate proposed, not built.
- `queue-eta` (planned window per row) — queue candidate proposed, not
  built.
- Dashboard surface (terminal or web, read-only over committed data) —
  future; the data spine above is the prerequisite.

## Zoom-out pass (this is the first)

Scope: what to watch and why. Poll 2-4 open sources quarterly (in
season): terminalfeed.io, nothumansearch.ai, Hacker News, GitHub
trending, arXiv agent-ops abstracts. Feed classifiable signals into the
queue candidates. Record each pass as a dated note; the queue grows by
opportunity and shrinks by done.

The first structured zoom-out pass (market-opportunity framing) is
recorded in the queue ledger and the 2026-08-25 records.
## Timeline events

Machine-readable rows appended per rotation/event:
`DATE<TAB>KIND<TAB>ITEM<TAB>HASH`. `scripts/rotate-queue` appends a
row per rotation; check-ins may append `event` rows. This is the raw
spine a future dashboard reads (no daemon — lines accumulate in the
repo, the dashboard draws from committed data).

```
2026-08-25	rotation	doc-sync-loop	bbd1d598794e82fcab767354b6220a97e87f790495fb921ba17871cd739242bf
2026-08-25	event	queue-scale	04a4446dbc9499a7c5348b6df0683b16a042cfe1e5f3bef08ef4709babda264
2026-08-25	rotation	timeline-events	e96e7d0c4d87955d02569dac7375a1d5ee50a40f8023d84c314528ffadaf866f
2026-08-25	rotation	queue-eta	c688853068c4770785de875104752bc8c588fe8a662e647d7440aa01b94d73af
2026-08-25	event	check-in-7	ae306c89cdc37c3ec30ee815a7365ae54035b1ac1f2a3dfc6c7a2c4d0ef9d480f954243d949cd60943887ee63dc3ef4d
```
2026-08-25	rotation	dashboard-readout	6d10a4493b52cff07e74eb10f48347b83b068c34620551e525d536f3f477049c
2026-08-25	event	check-in-8	6d10a4493b52cff07e74eb10f48347b83b068c34620551e525d536f3f477049c
