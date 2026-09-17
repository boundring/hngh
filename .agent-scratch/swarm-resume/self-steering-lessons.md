# Self-steering lessons harvest — 2026-09-15 folds wave (live)

Method: workers file blockers verbatim to automation/agent-handoffs.md
before working around them; coordinator harvests at collection.

## L1 (17:58Z, alert-lifecycle worker): shared-registry contention
Two concurrent folds both add checks to jobs/patrol.py's shared CHECKS
registry; the second addition shifts count assertions in the shared
suite (test_check_crumb... len==12->13; healthy-ledger 16->17), making
the full gate red for out-of-slice reasons.
Pattern: parallel work on a shared registry needs either (a) a
serialization convention (append-only registry rows, count assertions
replaced by registry-length derivation), or (b) coordinator-assigned
test-ownership before dispatch.
Worker behavior: filed blocker verbatim, worked around with per-target
runs. Correct per contract; workaround does not scale past 2 workers.
Coordinator action: DM'd the slice owning the change to absorb the
count-assertion updates.
Standing lesson candidate: prefer derived assertions (assert registry
length == number of registered checks) over hardcoded counts.

## L2 (18:02Z, butterfly): self-resolved coordination
Butterfly independently noticed and fixed the shared-suite count drift
its own registry addition caused, before the coordinator note landed.
Pattern: when a worker's contract says "full gate must pass", it owns
the whole gate surface, not just its slice — self-reconciliation of
shared-surface side effects works when the gate is the acceptance
criterion. L1's dispatch race was benign redundancy, not a gap.

## L3 (landing discipline): split-sharing landed clean
Two slices touching one Makefile landed as two commits via
restore--staged + per-slice path commits; combined-tree full gate
passed both before (acceptance) and after (confirmation) the split.
The lock-contention retries with the concurrent research lane remain
routine (3 waits this session).

## L4 (18:25Z, node-lattice ceremony): packages.lisp dependency heuristic
ceremony-drive's evidence gatherer (verify-candidate.py) refuses any
candidate touching src/packages.lisp: the file legitimately declares
all packages, so it always matches the inward+forbidden heuristic.
Precedent landing shape: export-only additions go as a labeled chore
commit ("excluded from cert manifest by dependency guard" — five prior
examples), the substantive files go through ceremony separately.
Lesson: the queue item build must be PLANNED as multiple lane-landing
pieces, not one candidate.

## L5 (18:30Z, node-lattice rotation): rotate-queue contract
rotate-queue takes --item + evidence FILES, not prose-only: the
objective must be backed by the candidate's touched files. It flips the
queue row to done (certificate-bound), but the ## Next pointer advance
is a separate docs commit (free-commit lane), and bridge deps were
verified present before advancing. Rotation = candidate evidence +
row flip + pointer advance; two commits, one ceremony.

## L6 (18:35Z): dependency-verified Next advancement
Next advanced to bridge-operator-host only after checking its backlog
dependency list (bridge, worker-driver refusal, r13 reviewer, :model
loadout — all present). Self-steering rule: a Next pointer advance is
a dependency-verification act, not bookkeeping.

## L5b (18:31Z, badger): real seam gap between folds
View A's spec assumed a feed-level generated_at stamp; the landed
history/1 envelope deliberately pins (schema, entries) with extras
failing closed. Worker filed the blocker instead of inventing a
backend change — correct: schema evolution is an operator decision
(schema/2), not a view-lane workaround. Coordinator resolution: gate
on schema+entries-array, derive the caption from entries' own ts
extent, record the stamp contract as a feed-lane follow-up.
Lesson: cross-fold contracts need a pinned truth source (viz_schema.py
_ENVELOPE_FIELDS) checked at DESIGN time, not discovery time; the
validator file is the single source of truth and it already answered
the question.

## L6b (18:39Z, coordinator): respawn criterion refined
Bear stalled with a nuance: zero file edits + 30 min silent on ocgo
(same as sunflower's stall signature) vs dove's healthy 44-message
deep dive. Stall signature = (no artifact) AND (no messages) AND
(leg idle) — not runtime alone. Respawned on zai fresh window with
the contested-counts guidance baked into the prompt (L1).

## L7 (19:09Z, badger): new-view registration touches four shared files
View A's landing swept dashboard-server.py, app.js, index.html,
gantt.html, story.html, Makefile, and .gitignore (with an add -f
whitelist subtlety). No contention occurred — the other in-flight
workers held disjoint files. Observation: view-fold contention risk
scales with the number of folds touching the dashboard; two dashboard
folds in one wave would have reproduced L1.

## L8 (19:14Z, deer): worker finished without DM (ready+idle 6m)
Second no-DM completion (after ant/seedling). The completion contract
is best-effort on the worker side; the coordinator's lifecycle poll
("ready + idle > 5m + artifact exists") remains the reliable
collection path. Contracts reduce wake latency but must not be the
only collection mechanism.

## Wave summary (folds batch, 2026-09-15)
alert-lifecycle bdee3708; correction-convergence 789efb02; history/1
producer 61356953; View A 7b8529d3; roadmap/rotation checks 831c2343;
deck-off c6d485fd; node-lattice kernel slice fc2ab203 (ceremony
054f08f0) + rotation 9e0779b0 (331fc633). Kernel gate green, CI green
on the cured recipe, suite at 2931 checks.

## L9 (19:14Z, llama): live-ledger render beats clean fixtures
The context-pack block passed all fixture cases but concatenated with
the next section's header on the REAL 69-row ledger — `$(cat)` strips
the trailing newline. Caught only by rendering against live data.
Pattern: fixture tests prove logic; a live-render smoke proof proves
integration. Both belong in the contract ("live-ledger render proof"
is now part of the slice convention, alongside red-first).

## Wave close (folds + deep graph, 2026-09-15)
10 commits landed across the two days of waves; deep graph 5/8 nodes
closed pre-gate at last check (d1-surface, d6-routes-view, plan::gate
remaining); stall signature (L6b) and coordination lessons (L1-L5b)
are the operator-requested self-steering evidence base.
