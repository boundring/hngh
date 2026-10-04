# The Megastructure Simulation — from map to living machine

Status: draft (2026-10-03, harness-skeleton program Phase F1).

## 1. Premise

The control room's primary surface is a megastructure (Nihei's Kowloon-class vertical city): the machine rendered as place. The simulation gives that place its population. Rule: **the sim consumes only recorded local events** (crumbs.db, feeds, ledgers) — it never fabricates operator state, never invents incidents. It is a lens on the log, not a game.

## 2. Entity mapping

| Megastructure entity | hngh referent | Data source today |
|---|---|---|
| The megastructure itself | this host + its automation | fleet.json, data.json |
| Cities / districts | hosts (this PC, laptop, later nodes) | fleet.json nodes |
| Buildings / towers | subsystems: cadence tiers, dashboard, kernel, feeds | data.json subsystem health |
| Transit lines | job pipelines (cadence tick → jobs → feeds) | time-ledger.json, schedule.json |
| Denizens (population) | runs, sessions, workers | sessions.json |
| Flora — growth over structure | data accumulation: crumbs rows, feed sizes, ledger growth | crumbs.db counts, feed mtimes |
| Fauna — creatures that move/act | events: alerts, report-queue fires, handled/dismiss decisions | report-queue rows, operator-items.json |
| Weather / atmosphere | machine climate: load, temps, spend | readout.json, telemetry.json, system-ops.json |
| Edicts / proclamations | operator decisions + certificates | operator-approved.json, ledger rows, plans |
| Ruins / neglected districts | stale feeds, expired identities, parked plans | self-review rows, parked plan files |

## 3. Presentation rules (Nihei grammar)

- Verticality = stack depth: hardware at ground level (the live mesh ring already in the map), kernel above it, automation mid-levels, interface at the spire.
- Flora crawls where data accumulates; a district overgrown = storage-heavy subsystem (crumbs, archives). Pruned districts look swept.
- Fauna are small, fast, and die fast: an alert is a creature that lives from fire to settlement (handle/dismiss); the map shows them only while alive.
- Scale awe, sparse humans: the operator is a tiny figure on a walkway — the attention rail is their lantern. No avatars, no chattiness.
- Megastructure perspective: when a decision opens, the camera doesn't move; the relevant district lights and connects by line to the rail.

## 4. Simulation phases

- P0 — static (DONE): editorial seed nodes + live fleet ring (current broadsheet map, carried into the control room).
- P1 — live states: node intensity from queue pressure, beacons on operator-host for open attention, session-denizen nodes appearing/moving with sessions.json, weather layer from readout (plan Phase C2 scope).
- P2 — recorded playback: time-scrub through crumbs.db — the structure replays the last N hours (fauna fire/decay, transit flows per tier). Pure read of recorded events.
- P3 — predictive flora/fauna: cadence forecast (next tier schedule, expected feed refreshes) rendered as growing buds and scheduled transit; ML assist (world-model on crumbs sequences) flags "district likely to go dark" (feed staleness prediction from dashboard-self-review history). Bounded: predictions render as faint overlays, never as facts.
- P4 — federation skyline (with federation-two-pc.md): the second PC is a distant tower across the strait; certificates light the bridge when nodes admit each other.

## 5. Honesty constraints

- Every rendered entity maps to a queryable row; a "source" tooltip names it (the map already labels editorial nodes honestly — keep that discipline).
- No fabricated history: playback only renders rows that exist.
- Prediction overlays are labeled as such and consume the same fail-closed feed checks as the console.

## 6. Data source gaps (to close during P1/P2)

- fleet.json currently carries fleet-online only (0/3 online seen live) — needs node identity + last-seen per node for city rendering.
- crumbs.db lacks a compact "event class" column for fauna rendering — derive by report-queue kind mapping (alert/progress) client-side first; add a materialized view only if client-side costs show.
- No per-session district history — sessions.json is present-state; P2 playback for denizens uses session start/end rows only.
