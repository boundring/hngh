# Meta-patterns - the load-bearing habits

Status: DESIGN - operator direction, 2026-09-09. The patterns
demonstrated across today's sessions and hngh's machinery, each with
the rule, where it lives, where it fired, and what reinforcement
means concretely. Cross-links:
[roguelike-orchestration.md](roguelike-orchestration.md),
[rehearsal-and-self-order.md](rehearsal-and-self-order.md),
[autonomous-development-control.md](autonomous-development-control.md),
[../records/2026-09-09-operator-flexibility-doctrine.md](../records/2026-09-09-operator-flexibility-doctrine.md).

> A pattern is only real when you can name where it is written down.

### 1. Director-worker fan-out
Rule: the director splits, workers execute, the director verifies by reading the files, not by trusting the reports.
Lives: every bounded delegated session is a worker behind the one-path launcher (`automation/lib/launch-session.sh`).
Fired today: the operator session retained two workers on design and inventory; the director verified both by reading the landed files.
Reinforcement: the dashboard sessions and story surfaces (already routed per [work-visualization-direction.md](work-visualization-direction.md)) render the fan-out as narrative.

### 2. Training wheels to ownership
Rule: every new machine job class starts operator-procedural with pre-chewed evidence, then graduates to a machine lane once proved safe on real data.
Lives: the operator-procedural backlog sweep ([2026-09-09-automation-schedule-optimization.plan.md](../project/plans/2026-09-09-automation-schedule-optimization.plan.md) step 1) precedes the curator skeleton (rehearsal-lane plan step 3).
Fired today: two operator-run sweeps proved the guardrails on real plans, then the curator beat was routed as a plan.
Reinforcement: the cadence drop-in that runs the curator, gated on the sweep's guardrail record in [rehearsal-and-self-order.md](rehearsal-and-self-order.md).

### 3. Reproduce-deterministic-now
Rule: a pure function of inspectable state is verified now, never scheduled for observation.
Lives: the TTSR rule `~/.omp/agent/rules/reproduce-deterministic-checks-now.md`, written today from the failure it names.
Fired today: `select_model` (env override, 24h bench, paid fallback) proved in 7 seconds by sourcing the function and running one live `omp -p` launch, against a planned 3-hour wait for the 00:30Z beat.
Reinforcement: one line in the overnight-cycle prompt block teaching the beats the same habit.

### 4. Rehearsal before act
Rule: run the governance loop minus the mutating tail before acting; a refusal is evidence, never authority.
Lives: [rehearsal-and-self-order.md](rehearsal-and-self-order.md); ceremony-drive's loop minus `mutation-check`, on scratch stores.
Fired today: the rehearsal-lane plan (2026-09-09-rehearsal-lane) proposed with the dry-run rung test-first.
Reinforcement: the plan itself; after step 1 lands, a dream beat on the idle hour cadence.

### 5. Evidence-gated disposition
Rule: every park, merge, or retirement cites paths; no counter-evidence means no action.
Lives: router disposition front matter (`cause=`, `reason=`, `disposed=`); the sweep reports ([2026-09-09-backlog-disposition-sweep.md](../research/2026-09-09-backlog-disposition-sweep.md), [2026-09-09-queue-dependency-inventory.md](../research/2026-09-09-queue-dependency-inventory.md)).
Fired today: the inventory found five merge-candidate groups and nine ordering conflicts, each with file-level evidence.
Reinforcement: the curator inherits the sweep guardrails verbatim; a merge proposal without citations is refused by the plan lifecycle.

### 6. Fail-closed refusal-as-evidence
Rule: blocked things are never silent; the refusal text travels verbatim into an alert row.
Lives: the 2026-08-28 ceremony-loop lesson ("refusal surfaces carry the refusal reason") in [autonomous-development-control.md](autonomous-development-control.md); `report-queue` alert identities; omp-bridge refusals breadcrumbed as data.
Fired today: the rc2 gate flap surfaced as alert rows that routed into plans, not as quiet blocks.
Reinforcement: already doctrine; the dashboard surfaces refused-run dispositions, making the bestiary visible per surface.

### 7. Honest-state columns
Rule: every design doc splits implemented from aspirational; estimates are labeled projections; no invented dates.
Lives: the state column of [roguelike-orchestration.md](roguelike-orchestration.md); the gantt's honesty rule in [work-visualization-direction.md](work-visualization-direction.md).
Fired today: the roguelike map marked dreams and meta-progression aspirational while death, difficulty, and permadeath are implemented.
Reinforcement: a lint over docs/design (cross-link existence, the accept-plans missing-designs check generalized) as a cadence job.

### 8. Commit-per-green
Rule: a verified boundary is a commit boundary; death costs the current slice only.
Lives: the standing rule `~/.omp/agent/rules/commit-per-green.md`; ceremony-drive's one-candidate-one-commit shape.
Fired today: the automation gate recovery (digest increment repaired, sibling slice landed concurrently, post-commit gate rc=0).
Reinforcement: already a TTSR rule and doctrine invariant; next action is the death-telemetry rung of [roguelike-orchestration.md](roguelike-orchestration.md).

### 9. Voice as contract
Rule: register rules are enforced by checks, not taste.
Lives: the voice rules of [presentation-direction.md](presentation-direction.md); the presentation boundary's factual-renderer and lexicon limits; the machine-checkable plan contract (accept-plans.py regexes).
Fired today: both new design docs were re-read end to end and grep-checked for exclamation marks and link targets before reporting.
Reinforcement: a docs lint (epigraph budget, exclamation-free prose, link existence) wired into the docs gate.

### 10. Queue hygiene as acceleration
Rule: caps, burn discipline, and enabling-work priority are the meta-layer that makes every other queue item faster.
Lives: the sessions-day-max ceiling, the fail-first ladder (`automation/lib/failfirst.sh`), the `priority=high` selector key, doctrine section 3.
Fired today: the dependency inventory reclassified 22 accepted plans into merge groups and serializations, turning parallel-slot spend into an engineering decision.
Reinforcement: the inventory's merge and ordering sections become the curator's first real work items; the work-graph builder renders the resulting order.

## Reinforcement status

| Pattern | Today's state | Next reinforcement action |
|---|---|---|
| Director-worker fan-out | demonstrated | story view renders the fan-out |
| Training wheels to ownership | sweeps done, curator routed | curator cadence drop-in |
| Reproduce-deterministic-now | TTSR rule landed | one prompt line in the cycle beats |
| Rehearsal before act | plan proposed | dry-run rung executes (plan step 1) |
| Evidence-gated disposition | inventory + sweeps landed | curator inherits guardrails |
| Fail-closed refusal-as-evidence | doctrine, in production | dashboard refusal surface |
| Honest-state columns | practiced in two docs | docs lint job |
| Commit-per-green | rule plus doctrine | death-telemetry aggregation |
| Voice as contract | practiced by grep | docs lint job (shared with above) |
| Queue hygiene as acceleration | inventory landed | curator merges from the inventory |

### 11. Bounded evaluation / dead-end recognition
Rule: cap the time spent evaluating a suspected dead-end; the
identification is the deliverable, not the workaround.
Lives: the router's dedup and escalation (scripts/router-tick.py
suppresses repeats, escalates at the third); the TTSR rule
`~/.omp/agent/rules/dead-end-timebox.md`; the plan lifecycle's
parked-with-cause disposition.
Fired today: the readout race - two structural fixes bounded the
problem, and the test-budget residual was routed, not hand-fixed in
place; the plan-verification-line failure - identified and fixed at
the regex seam in minutes once the checker was read; the bench
triggering design - a benchmark with no pending decision is expense
wearing a lab coat, so evaluation was bounded to decision-pending
cases.
Reinforcement: evaluation time-boxes become normal - a probe, a
bounded analysis, then either a fix or a documented park. Revisiting
a known dead-end requires new evidence; trying is not spending.
