# The wired-state lens — what every refactor must consider

Hngh is now wired: a live cadence continuum (1m/5m/10m/day/week/month +
event-fire) beats under systemd, oversight ticks probe and steer, the
ceremony self-times and self-pushes, credentials self-rotate, and the
machine learns loops before they recur. A refactor is no longer a local
edit — it alters a living system that observes itself. Before touching
any slice, check it against every lens below. A refactor that regresses
a lens is a wiring regression even if its tests pass.

## 1. Observability
Can the machine see this change? Every new operation must emit the trace
the oversight tick reads: breadcrumbs, per-phase timing where cost
matters, failure labels. If a new component is invisible to STATE.md /
reports / the ceremony-timing path, it is a blind spot — a future 40s
or 40-step problem that nothing will catch until it becomes an incident.
**Rule:** no new perpetual action lands without a named watcher.

## 2. Cadence fit
Every recurring action must live on the tier that fits its cost:
- cheapest / reads-only → **event-fire** (git hooks, ceremony end, on-demand)
- cheap procedural → **1m**
- medium → **5m / 10m**
- slow / heavy → **hourly+**
- agentic / model-gated → gated to a slow beat (STEERING_BEAT_MIN),
  never on the procedural minute tier.
When a new periodic duty appears, either mount it as a drop-in on the
right tier *or* explicitly state why it is not yet mountable — never
leave it floating. A tier with "no mounted work" is a pulse with no
job; that is acceptable only as a sprint placeholder, not a home.

## 3. Cost, loops, and self-optimization
- Prevent repeated-expensive-identical-work: cache deterministic
  full-gate results by a *stable identity* (content + tracked-state, not
  git HEAD / porcelain-of-candidate), with fail-closed markers.
- Everything that computes anything costly must emit enough trace for
  the oversight loop (and a *self-review mode*) to improve its own
  operation: which probes fit which windows, what fired on-change vs
  by-poll, what cheap hooks exist.
- The instant a new failure class appears (in a ceremony, a drop-in, an
  agent), codify detect→react→prevent in the guardrails *before* the
  incident repeats. Fail closed; never widen.

## 4. Self-healing and security
- Credentials self-rotate under flock; a refresh is a single-writer
  critical section; a failure surfaces as an alert row, never as silent
  decay (see credential-health + the 401 class).
- A new trust boundary (new token, key, pin, endpoint) must come with
  its health probe and rotation story. Never widen a boundary to make a
  test pass; fail closed when unverifiable.

## 5. Governance integrity
- Mutation stays certificate-bound: one action per certificate, fresh
  evidence per mutation, no bypass.
- Self-modification (Hngh adjusting its own timers / cadence / units)
  rides the same queue→card→certificate path as anything else — an
  optimization suggestion is advisory until it passes governance.
- Push is post-ceremony only; a commit is pushed when it is verified,
  never half-way.

## 6. Fleet-scale shape
- Anything Hngh does locally should shape to N nodes without a new
  architecture: rows adoptable-by-peer (fleet.md), duties/health
  evidence per node under the same gates, no ambient daemon.
- A single-node insight (timing, cadence, steering) is the prototype of
  the N-node pattern — the fleet mirrors the single node.

## 7. Operator surfaces
- Every new state must surface: the dashboard spine (timeline, queue,
  lanes, roster, reports) carries it, or it is not shipped to the
  lens. Keep the surfaces honest: display is read-only, never
  governance input.

## 8. Continuity of the index
- Queue/backlog/roadmap stay in sync; an architecture-index entry maps
  the slice; a dated record preserves the verified outcome.
- Terminology shifts ride the governance-vocabulary rule: prose changes
  freely, symbols change only deliberately through a ceremony.

## 9. Simplicity (ponytail)
- Wired-ness must never mean sprawl. Reuse the existing helper, delete
  the weightless code, keep the smallest version of the mechanism that
  both works and is observable. A new abstraction is a new surface to
  observe, time, and fail — pay for it deliberately.

---

*Operational use:* weekly roadmap-review drop-in reads this as its
checklist before editing anything; the oversight steward applies it to
every propose. Anything that regresses a lens is a wiring regression.