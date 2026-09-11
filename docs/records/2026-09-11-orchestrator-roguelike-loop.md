# 2026-09-11 — the orchestrator roguelike loop (as-above-so-below)

Operator directive: "we need Hngh itself to be as roguelike as any of its
components, recognizing its own stalls and addressing them with
self-preparation for reattempt and re-run." The motivating incident: the
2026-09-11 beat stall (docs/records/2026-09-11-beat-stall-diagnosis.md) —
9 consecutive launch-plane failures sat unnoticed for 12 hours because
NOTHING inside hngh watched the orchestrator; detection came from an
external director session reading handoffs. The orchestrator now gets the
same lifecycle its run domain gives every component.

## The mapping table (run domain -> orchestrator twin)

| Run-domain concept | Orchestrator twin |
|---|---|
| created/armed/running/checkpointed | a beat runs; outcomes land in STATE.md breadcrumbs (results=) |
| dead run | a stalled beat: consecutive launch-plane failures, same-cause plan deaths, or beat silence |
| failure classified into the bestiary | one cause class per blocker row (lib/causes.sh vocabulary) |
| countermeasure route | dream-informed re-attempt: blockers force `is_risky_step` true and add the blocker line to the dream/plan prompt |
| dream-informed preparation, not blind retry | remediation loop in overnight-cycle.sh: attempt-with-dream bumps attempts, success clears |
| terminal states are permanent; retry = a new run | 2 consecutive same-cause dream-informed failures -> blocker row parks (state=parked) + beat-parked alert; the plan leaves the rotation until the operator clears the row |
| nothing loops unbounded | the park IS the bound: escalation is one threshold (blocker-escalate-n), then operator territory |

## The pieces

1. Detector — automation/jobs/beat-watchdog.py, mounted from the 30m tier
   (cadence/30m/46-beat-watchdog.sh; no daemon, no new state format). Pure
   functions over records the orchestrator already writes:
   (a) >= beat-stall-n (3) consecutive `failed` tokens across overnight-done
       breadcrumbs -> scope "overnight", cause bad-execution;
   (b) a plan/lane with >= blocker-escalate-n (2) consecutive same-cause
       `overnight-lead ... dead ... cause=<class>` rows in agent-handoffs.md
       -> parked (respawn-guard semantics at plan level);
   (c) beat silence: newest overnight-done crumb older than
       beat-stall-silence-hours (6) while cadence ticks kept arriving —
       the exact 12h signature.
   Output per detection: one report-queue alert (identity
   beat-stall:<scope>) + one row in state/beat-blockers.tsv
   (id<TAB>scope<TAB>cause<TAB>first-seen<TAB>attempts<TAB>state). Rows the
   overnight beat already owns (cycle-created rows) are never touched by the
   detector. Fail-first: any detector fault exits 0 and writes nothing —
   the tick always survives its watchdog.
2. Remediation loop — overnight-cycle.sh + lib/beat-blockers.sh. When the
   next beat picks a plan with an active blocker row:
   - the dream runs even for a mechanical step (blocker forces risky), and
     the dream/plan prompt gains: "this plan/lane previously died with cause
     class <X>: read state/beat-blockers.tsv + the lessons tail
     (state/ocgo-agent-lessons.md), state what you will do differently, and
     assert it in your sanity-checks." The dream's sanity-checks already
     flow to the executor via the existing mechanism.
   - accounting is sequential (never written from the concurrent
     subshells): success clears the row; a failure records/bumps attempts;
     attempts >= blocker-escalate-n parks the row + files beat-parked:<slug>.
   - a parked plan is skipped by selector (a) — it leaves the rotation
     until the operator fixes or removes the row.

## Forethought doc cross-links

This closes the re-decomposition trigger gap the forethought design named
(docs/research/2026-09-10-forethought-and-decomposition.md s3: an
under-specification shape should dream the remainder BEFORE die+replace):
the blocker ledger is what tells the next beat "this shape already died."

## What this loop still cannot self-heal (honest limitation)

- kernel-gate red: src/tests/Makefile/hngh.asd are forbidden to machine
  sessions; a red kernel gate parks work (missing-authority), it does not
  self-repair. The blocker row records it; the operator clears it.
- ceremony-required work: certificate-ceremony changes (the parked
  2026-09-06-worker-transport-wiring lane is the live example) can never be
  remediated by a delegated session — parked is their only route.
- a dead DETECTOR or a dead cadence tier: the detector watches the beats,
  not itself; if the 30m tier stops firing, only external oversight sees it
  (resume-gap-hours sweep is the existing sibling check).
- operator-owned surfaces: provider/credential config, systemd lifecycle,
  push protection (the openrouter-key push-protection block is live) —
  missing-authority routes to the operator packet, never retried.

## Tests

- automation/tests/test-beat-watchdog.py: 7 hermetic cases from the REAL
  incident data (the 2026-09-11 breadcrumbs verbatim) — 3x results=failed
  -> blocker + alert; 2 same-cause deaths -> parked; silence co-witnessed
  by live ticks; healthy ledger silent; cycle-owned row untouched; crash
  exits 0.
- automation/tests/test-beat-blockers.sh: dream forced + cause-class line;
  success clears; second same-cause death parks + beat-parked alert; parked
  plan leaves the rotation while a sibling still runs.