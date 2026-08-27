# Hngh master plan — the staged path from sidecar to harness-harness

*Planning artifact (2026-08-26). Integrates three planning facets: the
architecture/dependency map, the research/design/alternation model, and
the roadmap/staging/sequencing. This plan is the PREREQUISITE for the
next stages: build phases below will not unlock before the named
design/research materials exist and are ceremonied.*

---

## 1. Current state (grounded)

- Kernel spine rungs 4–18 complete (evidence adapter, mutation
  executor, bounded model/terminal/worker transports, federation +
  attestation, pins + signature transports, policy profiles, wake,
  worker task); governance C0–C3 live; every rung since 9 bound +
  ceremonied through the self-governed loop and pushed.
- No-daemon automation: rotate-queue + schedule-heartbeat + the
  run-autonomous tick; watchdog + handoff ledger + webapp spine live;
  system-awareness probe live (system.json); cadence tiers 1m–month +
  lesson-harvest multi-cadence; the OMP bridge (orient/register/
  ceremony) exists and dogfooded itself; self-start leg lands
  (uncarded course → provisioned card → next beat drives it).
- Honest gaps: course-selection is fixed-rule, not written-policy;
  the domain models only *runs* (no system/session/roster values);
  the webapp re-derives flat JSON (no shared spine); the buddy/OSD
  exists but the animations are "awkward"; no multi-slice program
  scale class; push still operator-touched in places.

## 2. Intended state

Hngh as **both** a system harness (governing hardware/software/
network) and an **agentic harness-harness** (governing the harnesses
that run agents), under ONE spine: one governance core, one set of
gates, two governed planes, presided over through CLI + GUI + pixel-RPG
buddy surfaces. Self-improving runs: agents as characters in
task-appropriate stories, death-and-replacement always active, the
machine scheduling+completing its own development, alternating growth
with research/design production.

## 3. The spine (ArchPlan facet)

- **Layer map** — kernel (pure core) → application/ports → interface
  (driving adapters: CLI/TUI/buddy/webapp) → mechanism (driven
  adapters incl. NEW system-awareness, session-roster, config) →
  presentation (renders run + harness readouts); two governed planes:
  the system-harness plane (nodes/hardware/network) and the
  agentic-harness plane (= the harness-harness, governing session
  hosts + agent runs). **No second core** — the harness-harness is the
  same clean architecture one level up.
- **Dependency laws** — inward only; interfaces are pure readers
  (render + route, never mutate, never import adapters directly);
  steers are advisory reports; any apply is certificate-gated; no
  daemon until the bridge rung proves it.
- **Refactor spine** — R1 domain observables (system-snapshot, roster
  entry, session-state values) → R2 pure harness use cases
  (observe-system/sessions, select-course advisory) → R3/R4 pure
  awareness + roster adapters → R5 harness renderers → R6 main
  dispatch surface (status/summon/schedule/ask/expedite/dashboard/
  subagent verbs) → R7 omp-bridge sided adapter → R8 session-host
  (dormant, on-demand only).

## 4. Research ↔ design alternation (DesignPlan facet)

- **Alternation cycle** — grow beats (self-development, normal
  1m–10m cadence, roguelike death+replace + evolution loops) alternate
  with research/design beats (slowest tier, bounded cost) that only
  emit scoped, parseable materials (a spec, a menu tree, a brief,
  a sprite sheet) — **never code** during a research beat. The gate:
  research→grow when the artifact is a priced, parseable decision;
  grow→research when a grow run cannot proceed without a missing
  design and dies per the roguelike rule.
- **Research backlog (must precede the fun builds)** — buddy
  summoned-not-nagging menulearning; handoff-brief schema; the
  steer-vs-die threshold; self-hosting prior art; which biological
  abstractions are concrete vs branding; honest gamification
  mechanics. Each ties to a build rung.
- **Gamified runs** — one run = one named character + a story beat;
  real events (quest/victory/setback/death/reward) rendered only from
  real run fields; narrative tagged `perceptual:true` and **never**
  enters governance (the honesty leash).

## 5. Phased roadmap (RoadmapPlan facet)

- **P1 DEV** — self-driving leg + cadence continuum (already largely
  landed; close #1.5 machine-steered course = written policy + exit
  gate: selector ranked a card by policy with a justified report, and
  the repos push themselves).
- **P2 DESIGN** — command-center architecture (S1–S8), system-aware
  map, OMP-bridge + hosted-session design, lattice proposals,
  self-optimization + gamification design. Exit: ceremony-ready docs,
  open questions closed.
- **P3 DEV** — honest command center + driver bridge (S1 truth-telling
  dashboard, S2 system panel, S3 CLI read, S4 live roster, S5 summon,
  S6 consider + expedite ripple, webapp explicit-open).
- **P4 DEV** — harness-harness (OMP plugin, hosted interface +
  bridge-as-operator-host, S7 pause/label, navigable+gantt sessions);
  the session-host daemon may exist ONLY here, on-demand.
- **P5 DESIGN** — evidence hygiene + lattice + ledger standard
  (key-rotation, governance-benchmark, DSSE, self-funding).
- **P6 DEV** — gamified open self-optimizing megastructure (pixel-art
  agent surface, surface-evolution auto-grading, lattice rotation,
  resource-pool view, dancing/gantt-ports).

## 6. Sequencing rules + scale classes

- **Machine-steered order** — extend run-autonomous/rotate-queue with
  written-policy ranking (dependency, class, expedite, oldest/rump;
  tie = highest value ahead), a justified-choice report, cert-gated
  mount (self-prov art leg already lands cards).
- **Scale classes** — check-in-scale (single session, small gates);
  rotation-scale (full rotate + model + cert, ~6h); multi-slice
  program (P1/P3/P4/P6: split into slices with explicit Depends-on; a
  slice unblocking most pulls first).
- **Cadence placement** — longest window that turns it; event-fire
  over polling where an event exists; 1m/5m read-only, 10m+ small
  mutations, hourly+ cert-touch, agentic rechecks facts at action.
- **Expedite ripple (M5)** — read-only compute of new ETA + which
  items accelerate/cascade-delay; actual reorder rides rotate-queue,
  never fabricates, never bypasses a gate. Fail-closed: undefined next
  step → report, not busywork.

## 7. Plan-as-prerequisite staging

- activity-matrix.md → gates P1 build. ← exists
- **interface-plan.md + this master plan** → gate P3 (S1–S5) + P4
  (S6–S8). ← this doc is that prerequisite
- OMP-adapter + hosted-session-host design (P2) → gates P4 S8 +
  navigable gantt; session-host daemon lift justified only after P3.
- worker-driver bridge E2E (P3) → feeds P4.
- key-rotation + gov-benchmark + DSSE + ledger (P5) → gates P6
  lattice + evidence freshness.

## 8. Immediate next actions (this plan's own first slices)

1. Fold this master plan into `docs/project/` (ceremony), link it from
   `architecture-index.md` — the plan is now the prerequisite gate.
2. Close **P1 #1.5**: machine-steered course-selection as a written
   policy in a pure `select-course` use case (the ArchPlan R2 gap: it
   lives in a service tick today, not clean governance).
3. Stand up **P2 DESIGN** on the alternation cycle's slow tier: the
   command-center architecture doc + system-aware map + buddy-menu
   + gamified-run spec + OMP-bridge design, each ceremony-ready.
4. Only then **P3 DEV** (S1–S5) against closed contracts.