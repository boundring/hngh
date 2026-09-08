# Projects system — Owner-request intake packet

*Status: INTAKE PACKET — queued for Hngh research/design cycles.*
*Date: 2026-09-08.*
*Source: Owner feature request, not an implementation.*

## 1. Owner's requirements (verbatim-faithful)

The owner requested six things:

1. **Dashboard PROJECTS SECTION.** A new top-level section on Hngh's
   dashboard dedicated to multi-project state — not buried inside an
   existing tab, but its own landing area.

2. **PROJECT ELEMENTS IN THE CAMP TAB.** Within the dashboard's Camp tab
   (where beat-level checkpoints live), add project-oriented elements
   alongside existing beat items — so the operator sees per-project
   progress without switching contexts.

3. **PROJECT-RELATED LOGS.** Logs that include entries cross-referencing
   work done on other projects, not just Hngh's own runs. Findings,
   rotations, events — tagged or filterable by project.

4. **PROJECT MAINTENANCE TICKS IN SCHEDULED TASKS.** Periodic scheduler
   ticks whose job is multi-project housekeeping — repository health
   probes, cache refreshes, stale-entry sweeps — running on cadence
   rather than ad-hoc.

5. **QOL MATTERS FOR OPERATORS.** Practical quality-of-life features
   wherever Hngh's systems can absorb them: better visibility into
   cross-project dependencies, faster drill-down from a dashboard tile
   to a project's details, reduced friction when context-pack generation
   touches multiple repos.

6. **ADVERSARIAL / ANTAGONISTIC REVIEW.** A mandatory review cycle for
   changes and features that affect multiple projects or touch shared
   surfaces (dashboard, scheduler, logs). This review is antagonistic
   in the same vein as the UX cycle — the reviewer actively hunts for
   breakage, false assumptions, and weak edges, not a rubber stamp.

These are **requirements**, not specifications. Hngh's own cycles own
the research, design, and build that turns them into machinery.

## 2. Current state — what `multi-project.md` covers vs the gap

### 2.1 What `docs/design/multi-project.md` already specifies

`multi-project.md` is marked **"designed 2026-09-08"**. It fixes the
relationship between Hngh as the governance tier and other projects
(e.g. Cistern) as independent build/test/commit agents. Its scope:

| Section | What it defines |
|---|---|
| **§2 Project registry** | TSV row schema (`project`, `repo`, `test-command`, `context-pack-role`, `key-files`). Currently inline in `automation/lib/context-pack.sh`; a file deferred until a second reader exists. |
| **§3 What generalizes** | Context pack dispatch via `context_project_block`; research subject slugs (`cistern-*`, `govbench-*`); disposition spine handling any project's findings; cadence parameter rows prefixed per project. |
| **§4 What does NOT generalize** | Kernel ceremony (hngh-specific); automation gate (per-project runner); commit authority (Hngh commits Hngh repos; observes other repos). |
| **§5 Boundary** | Four-row table: Hngh provides context packs, research routing, review/disposition, dirty-file *status*; the project owns its build, architecture, ledger, working tree. |
| **§6 Cross-links** | Links to context-manager.md, operator-mirror.md, field report. |

**What is NOT in `multi-project.md`:** Nothing about dashboard rendering,
Camp tab content, log filtering, scheduled-tick vocabulary, QoL surfaces,
or adversarial review processes. These are the **GAP**.

### 2.2 The gap — what the owner's request adds beyond the design doc

The gap falls into five buckets:

1. **Surface (dashboard + camp tab):** `multi-project.md` describes data
   plumbing (registry, context dispatch). It says nothing about how an
   operator *sees* multi-project state. The dashboard has no Projects
   section; the Camp tab shows beats, not projects. How the registry
   maps onto dashboard panels is unbounded research.

2. **Logs:** The disposition spine handles any project's findings, but
   logs as presented to the operator currently center Hngh. Filtering,
   tagging, and cross-project correlation in the log surface is undefined.

3. **Scheduler vocabulary:** Cadence params exist as prefixed rows, but
   "project maintenance tick" is an owner coining term. What a tick *is*
   in the existing schedule-heartbeat / run-autonomous rotation — does
   it emit a store run? modify a card? append a timeline event? — is
   uncharted.

4. **QoL:** Unspecified beyond "anything that reduces friction." The
   backlog already lists dozens of QoL items (dancing interfaces,
   widget grids, notification surfaces). Some overlap with projects
   needs (e.g. resource-pool-view, config-manager); others do not.

5. **Adversarial review:** Not mentioned in `multi-project.md` at all.
   The process for reviewing multi-project changes — who reviews, against
   what criteria, what happens on refusal — must be invented or adapted
   from existing review machinery.

## 3. Open research questions (not answers — for Hngh's cycles)

The following questions must be answered by Hngh's own research cycles.
They are organized by touchpoint; answering one may spawn sub-questions
for another.

### 3.1 Dashboard / Camp tab

- **Structure:** What is the visual hierarchy of the Projects section?
  Does it sit beside Timeline/Queue/Sessions as a fifth tab, or overlay
  them? How many project tiles fit before scroll becomes necessary?

- **Camp mapping:** How does a "project element" differ from an existing
  "beat item"? Both live in the Camp tab today. Is a project element a
  parent container (showing child beats), a parallel track, or a metadata
  overlay on beats?

- **Drill-down:** When the operator clicks a project tile, what detail
  pane appears? Does it reuse the existing session-run display or
  introduce a new format?

### 3.2 Logs

- **Tagging model:** How are log entries tagged with project identity?
  Per-event labels? Per-station routing rules? Filtered at render time
  or at ingestion time?

- **Cross-reference:** If a finding spans two projects (e.g. a credential
  affects both Hngh and Cistern), does it duplicate into two log streams
  or link between them?

- **Retention:** Do project logs follow the same retention policy as
  Hngh's (the 6,920-row problem in backlog lane "report-ledger-retention")
  or a separate policy?

### 3.3 Scheduler / Maintenance ticks

- **Tick action:** What does a project maintenance tick *do* in
  schedule-heartbeat's vocabulary? Options: launch a light-weight
  `present` scan of each project's store; run `git status` probes;
  update cadence-param rows; provision heartbeat cards for project
  lanes?

- **Cadence:** How frequently do maintenance ticks fire relative to
  the existing hourly/daily/night tiers? Per-project? Unified?

- **Failure propagation:** If a project's test command fails during a
  maintenance tick, does it block the tick? Create an alert row? Log to
  the project's dedicated stream only?

### 3.4 Adversarial review

- **Trigger model:** What starts an adversarial review? A specific
  change type (affects ≥2 repos)? Every dashboard addition? On-demand
  by the operator? Continuous monitoring of the Projects section?

- **Adversary role:** Who plays the antagonist — a model-session worker,
  a scripted probe, the same station that plays the beat-checks? Does
  it need its own loadout?

- **Integration with existing ceremonies:** How does adversarial review
  relate to mutation-check (certificate-bound, evidence-required) and
  the existing review adapter? Can it run in parallel, or must it wait
  for the certificate gate?

### 3.5 QoL

- **Priority:** Among the backlog's QoL items, which ones intersect with
  project management (resource-pool-view, widget grid, notification
  surface)? Which are duplicates of project features?

- **Incremental adoption:** Can QoL items be added independently of the
  core Projects section, or do they depend on the registry/touchpoints
  being built first?

### 3.6 Integration with existing surfaces

- **backlog-lanes extension:** Should backlog lanes inherit a project
  column? Or does the Projects section present a parallel view? The
  `lane_covers_queue_id` heuristic maps prose IDs to queue IDs; does
  project membership belong in the backlog or in the dashboard only?

- **timeline events:** Does `multi-project.md` §2 imply timeline event
  columns (DATE, KIND, ITEM, HASH) get a PROJECT column? Or are
  projects implicit in ITEM naming?

- **data_spine expansion:** `dashboard-readout`'s `data_spine()` produces
  `{timeline, queue, etas, sessions, roster, verdict}`. Does the
  Projects section need a `projects` key? What fields would it contain?

## 4. Quality bars inherited from the method suite

Every Hngh cycle that claims this work inherits these standing constraints.
They are not optional.

### 4.1 Roguelike lifecycles (`roguelike-agentic.md`)

- **Death-and-replacement:** Any stalled/looping/erroring session dies;
  the replacement starts with a handoff brief from the dead session's
  failures. Zero re-discovery.

- **Procedural hook:** When the next turn is predictable, kill early,
  run procedurally, respawn informed.

### 4.2 Operating precepts (`operating-precepts.md`)

- **Precept 1:** Watchers over gates — scheduling is watching, not
  policing.
- **Precept 2:** Cadence dictated by cost, not arbitrary ladder.
- **Precept 3:** Two optimization levels, both scheduled (continual +
  self-review).
- **Precept 5:** Clean-architecture governance — pure cores, injected
  ports, inward dependency, evidence before claims.
- **Precept 7:** Nervous-system-like control planes — sensory input up,
  motor output down, lateral information sharing.
- **Precept 8:** Continuity as primary value — wiring makes continuity
  the default.
- **Precept 10:** Model tiering — local/cheap first, expensive models
  held to higher bar (bounded payloads, right-sized context).
- **Precept 11:** Dogfood the whole loop — agents working ON Hngh run
  under the same roguelike rules as agents working IN Hngh.

### 4.3 Check-ins (`checkin.md`)

- Light heartbeats — catch drift, note health, inject small steering.
- Never create busywork. One entry per check-in, appended dated.

### 4.4 Agent guardrails (`agent-guardrails.md`)

Critical guards every cycle enforces:
- **Tool-call failure loops:** Fall back to `apply_patch`/edit tool;
  re-read anchor before next edit.
- **Stale-anchor re-verification:** Re-read after any skipped/interrupted
  tool result.
- **Untracked sibling changes:** Stage ONLY owned files.
- **State before acting:** Peek resulting state after each gate.
- **Trust self-reported evidence as claims, not facts:** Verify
  subagent hashes/counts before accepting.

### 4.5 Steering lessons (`PROCESS-RETRO.md`)

- **Lesson 1 (measurement before layout rulings):** Any ruling about
  width/geometry/visual layout is preceded by a render probe with the
  numbers. The director (or reviewer) rules on the numbers, not reasoning.

- **Lesson 2 (merge dependency chains):** Dependent directives go into
  one group with one green boundary. No discovered-at-batch-time merges.

- **Lesson 3 (batch cadence ≤4 directives):** Batches larger than 4
  directives leave director rulings unratified for the whole batch.

- **Lesson 4 (probe discipline up front):** Throwaway probe scripts have
  high defect rate. Brief probe discipline at turn one, not learned
  per-session.

- **Lesson 5 (route-don't-invent):** Contract questions return as
  routings with options. Zero silent inventions found.

- **Lesson 6 (mid-turn steering):** Owner observations enter the running
  turn as steering, not post-mortem.

### 4.6 Tool-shape rules (TTSR, from cistern-intake README)

- **Large-file-incremental-writes:** No write ≥150 lines in one
  generation. ≤60 lines per append.
- **Heredoc-rewrite-caution:** Write tool for whole-file rewrites;
  heredocs only for surgical edits <40 lines.
- **Sed-surgery-nudge:** 2nd+ `sed -i` on one file = stop, re-read,
  one verbatim rewrite.
- **Doc-heredoc-length-guard:** No ≥150-line heredoc in one generation.
- **Subprocess-timeout-cap:** Cap subprocess timeouts; don't hang.
- **Restructure-don't-retry:** For structural changes, restructure the
  target instead of retrying failed commands.
- **Commit-per-green:** Every green boundary is a commit boundary.

### 4.7 Handoff-phase lessons (from PROCESS-RETRO §4)

- **Halt at a green boundary** with a verbatim recovery block.
- **Capture proof anchors** before generation-affecting changes.
- **Peer coordination works** without a director for parallel designers.
- **Not everything is TTSR-expressible** — some lessons route genuinely
  and need different treatment.

### 4.8 Adversarial review — mandatory cycle

Per the owner's requirement, this is **not optional**. The adversarial
review mirrors the two-round UX cycle that ran on Cistern:

- **Round 1:** Antagonist renders/measurements against proposed changes.
  Width/geometry violations documented with numbers.
- **Round 2:** Owner observation enters steering; targeted fix.
- **Closing review:** Structural findings ledgered, never fixed in passing.
- All rounds produce ledger entries and inform the successor cycle.

## 5. Suggested sequencing (for Hngh's queue)

These are suggestions. Hngh's cycles may reorder, merge, or split them.

```
Phase 1 — Research & scoping
├── Probe 1a: Map registry onto existing surfaces
│   - Where does each registry field appear? (dashboard tabs, log filters,
│     scheduler tick outputs)
│   - What data flows from multi-project.md §3-4 into dashboard-readout's
│     data_spine()? Additive keys only?
│
├── Probe 1b: Survey existing QoL backlog intersections
│   - Which backlog lanes intersect with projects needs?
│   - De-duplicate: widget-grid, resource-pool-view, notification-surface
│     may cover parts of the request.
│
└── Probe 1c: Define adversarial review as a ceremony
    - Does it slot into the existing review adapter? Mutation-check?
      Standalone? Output contract?

Phase 2 — Adversarial review of Phase 1's output
├── Render the proposed surface changes
├── Measurement probes on geometry, width, interaction flow
├── Antagonist findings → ledger
└── Revision based on findings

Phase 3 — Design (concrete contracts)
├── Dashboard: Panels, tabs, tile schemas
├── Logs: Tagging model, filter spec, retention
├── Scheduler: Tick action spec, cadence params
├── Adversarial review: Trigger model, loadout, output
└── QoL: Priority list, incremental delivery order

Phase 4 — Implementation (incremental)
├── Registry file (promote from inline to disk)
├── Dashboard Projects section (read-only wireframe first)
├── Camp tab extensions (project elements)
├── Log tagging/filtering
├── Scheduler tick (first maintenance action)
├── Adversarial review ceremony wiring
└── Remaining QoL items
```

**Rationale for the sequence:**

1. Research before design — unanswered questions from §3 determine
   whether Phase 3 can start.
2. Adversarial review before implementation — catching false assumptions
   early costs less than retrofitting after code lands.
3. Implementation last — builds what design contracted, not what the
   first guess guessed.

**Alternative order considered and discarded:** Implement dashboard
first, then fill in log/scheduler/QoL. Discarded because: (a) the
adversarial review catches geometry issues that require redesign, making
an early dashboard a rework risk; (b) the scheduler tick depends on
understanding what the registry exposes, which is a research question.

---

*This is an intake packet, not a plan or spec. Hngh's cycles own the
research, adversarial review, design, and build that turns these
requirements into standing machinery.*
