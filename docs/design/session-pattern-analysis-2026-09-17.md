# Session pattern analysis: queue growth vs. drain convergence

## What happened (the arc)

This session started with 32 seed nodes across three study graphs. By the time
of this writing: 600+ nodes, 391 completed, 209 queued, 0 failed, and the
driver had terminally exited after hitting its 200-loop cap. The session
survived on a manual dispatch workaround for its final 12+ hours.

The graph grew from 32 → 600 through a single mechanism: **gates inject gaps**.
Every gate critique found real unexplored surfaces (they were real — the
findings landed as fixes), injected children, those children completed and
spawned their own gates, which injected more. The graph is a breadth-first
search over "what haven't we checked" with no natural terminal condition.

## The three phases of the session

**Phase 1 (healthy expansion, ~hours 0–6):** Growth was productive. Each
generation found real defects (the identity leak, credential exposure classes,
redaction blind spots). Fixes landed with tests. The audit was finding and
fixing at a sustainable ratio.

**Phase 2 (diminishing returns, ~hours 6–14):** Gates kept injecting but the
findings shifted from "real defect" to "contradiction between earlier
children's claims" and "unexplored-but-plausible surface." Real, but each
injection added 2–6 nodes while only 1–2 completed. The queue grew faster
than it drained.

**Phase 3 (stall and boundary, ~hours 14–24):** The driver wedged, the manual
workaround couldn't keep pace with generation growth, and the session needed
an operator hard-stop to prevent indefinite expansion. Three consecutive
sweeps flagged the same "persistent stalls" that were actually gate-injected
sub-probes — real work, but work the session could no longer afford to do.

## The structural problem

Deep-mode task graphs have a **convergence deficit**: they are designed to
expand (gates must inject or they're not doing their job) but have no
mechanism to contract. The only forces pushing back are:
- the parallel budget (6 slots, but manually overridable to 10+)
- the operator's patience
- the driver's 200-loop cap (which kills the driver, not the queue)

None of these are convergence mechanisms. They are throttles. A throttle
slows growth but doesn't produce a terminal state.

## What the session proved about hngh's architecture

The session accidentally ran a live experiment in governance scale. The
findings map directly onto hngh's design:

1. **hngh's certificate chain held perfectly.** Zero unauthorized content
   landed across 600 nodes and 20+ hours. The deterministic evaluator, the
   closed vocabulary, the content-hash binding — all functioned as designed.

2. **The operational layer was the bottleneck.** Every failure was in the
   orchestration machinery (swarm dispatch, gate ownership, ledger integrity),
   not in the governance kernel. This confirms hngh's architecture: the
   kernel is sound, the adapters are fragile.

3. **Evidence-before-claims worked but was expensive.** Every finding was
   verified before action (six workers independently confirmed the ACP
   replay; three workers cross-checked the identity census). The cost was
   time and coordination overhead, not correctness.

4. **The session needed a boundary it didn't have.** The operator's
   "optimize to find the balance" directive arrived at hour 24. A built-in
   convergence mechanism would have arrived at hour 6.

## Proposed optimizations for hngh's development process

### 1. Generation budget on gate injection

**Problem:** Gates inject without limit, causing exponential graph growth.
**Proposal:** Each task graph carries a `max_generation` counter (default: 3).
Gates may inject into generations 1–2 freely. Generation 3+ gates may only
inject if the gap is a **factual error** (not an unexplored surface).
Generation 4+ gaps go to a backlog document, not the graph.

**Why this works:** The session's generations 1–2 found and fixed real
defects. Generations 3–4 found contradictions and unexplored surfaces —
valuable knowledge, but not actionable in the current session. A backlog
note preserves the finding without paying the coordination cost.

### 2. Drain-rate monitor with auto-boundary

**Problem:** No one noticed the queue outpacing the drain until hour 14.
**Proposal:** The coordinator tracks `queued_count / drain_rate` each sweep.
When projected completion exceeds a threshold (e.g., 4 hours), the coordinator
automatically invokes the boundary: stops accepting new injections, dispatches
only from the existing queue, and starts the closure sequence.

**Why this works:** The boundary was effective but arrived too late because
it required operator intervention. An automatic trigger applies it at the
right time without operator attention.

### 3. Gate injection taxonomy

**Problem:** Gates treat all gaps as equally injectable.
**Proposal:** Gates classify gaps before injecting:
- **Factual error** — an existing artifact states something demonstrably
  wrong. Must be injected (the artifact is load-bearing for downstream
  decisions).
- **Unverified claim** — an artifact asserts something without evidence.
  Note in the artifact's `open_questions`, don't inject unless downstream
  nodes depend on the claim being true.
- **Unexplored surface** — something no child checked. Note under
  `residual surfaces` in the gate artifact. Don't inject unless the surface
  is on the critical path.

**Why this works:** The session's generation-3+ injections were almost all
"unexplored surface" class. Validating them as backlog notes instead of
graph nodes would have saved ~150 nodes of coordination overhead while
preserving the findings.

### 4. Manual dispatch as first-class (not a workaround)

**Problem:** The driver's autonomous dispatch failed (wedge, loop cap), and
the manual workaround was more reliable but treated as an abnormal mode.
**Proposal:** Expose `assign_task` as a first-class coordinator surface with
batch dispatch (assign N nodes to N workers in one call). The manual lane's
100% acceptance rate vs. the driver's ~30% effective rate makes it the
primary path, not the fallback.

### 5. Completion receipts for the ledger-erasure defect

**Problem:** Workers completed nodes but the ledger showed them as queued
(state=None, assigned=None). The work existed only in the worker's report.
**Proposal:** Every completion writes a receipt to a durable file (not just
the in-memory plan store). The coordinator's sweep reads receipts, not the
ledger, to determine actual state.

---

## The deeper pattern: hngh needs a convergence principle

hngh's ten principles are all expansion principles: evidence before claims,
fail closed, dependency direction, etc. They ensure correctness but not
termination. The session proved that a correct system that cannot terminate
is operationally equivalent to an incorrect one — both leave work unfinished.

**Proposed eleventh principle: convergence.** Every open work item must have
a terminal condition that is reachable within the current session's budget.
If the terminal condition requires another session, the item must be
explicitly transferred to a durable backlog with enough context for the next
session to resume without re-deriving the approach.

This is not a new constraint — it is the operational complement to
"evidence before claims." Evidence ensures claims are true; convergence
ensures claims are eventually made or explicitly deferred. Without it, the
system produces ever-more-verified work that never ships.

---

## Immediate actions for the next session

1. Adopt the backlog at `~/.jcode/scratch/BACKLOG.md` as the starting queue
   (already prioritized, dependency-ordered, effort-estimated).
2. Set `max_generation = 3` on the first task graph and enforce it.
3. Run the drain-rate monitor from the first sweep, not as a late addition.
4. The 6 upstream jcode defects need a response before attempting another
   deep-mode plan — the manual workaround works but doesn't scale.
5. The Typesafe integration assessment needs synthesis from banked artifacts
   (all ts-* children that completed are preserved; the remaining ts-* queued
   nodes are coverage, not blockers).
