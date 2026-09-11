# Forethought and recursive decomposition design

Date: 2026-09-10. Scope: read-only research; this file is the only artifact.
Operator framing honored verbatim: hngh should decompose/reorder/reorganize
work whenever it can, simulate a task before executing it ("dreaming"), use
dream lessons as sanity-checks for subagent preparation, and optimize how much
effort forethought itself deserves.

Evidence bases read 2026-09-10: docs/project/plans/2026-09-09-omp-hngh-integration.plan.md
(steps 5/8/9/10/11 open), automation/scripts/overnight-cycle.sh,
automation/lib/context-pack.sh, automation/lib/launch-session.sh,
automation/prompts/overnight/, automation/handoff_briefs/,
docs/research/2026-08-30-handoff-brief-schema.md,
docs/research/2026-08-30-delegation-lane-parallelism-*.md,
docs/research/2026-08-30-steer-vs-die-threshold.md,
docs/research/2026-09-09-queue-dependency-inventory.md,
docs/research/2026-09-10-passthrough-and-quota-interleaving.md,
docs/design/descent.md, docs/design/bestiary.md, docs/project/plans/README.md,
automation/cadence-params.tsv, omp://extensions.md. No paid API calls; no
implementation. Repo probes only.

## 1. Recursive decomposition model

A plan step becomes a tree of subagent-sized tasks -- but the tree is
never a new artifact class. The plan file already carries the schema
(plans/README.md: front-matter, `## Steps` checkboxes, verification
contract, autonomy reference), so decomposition is an OPERATION on a
plan file, not a new state format.

### Node shape (what each node receives vs re-derives)

A node = one delegated session (lib/launch-session.sh) with:

- **Received:** the step text verbatim (build_plan_prompt), the context
  pack (context_pack, <=1500 bytes derived data, "cite, do not
  re-derive"), the known-context block (overnight-cycle.sh
  known_context: pointers bounding discovery to one citation), the
  standing-authorizations block, and the session loadout caps
  (context-limit 2000 / token-limit 50000 / cost-limit 2000 /
  time-limit TIMEOUT_S).
- **Re-derived:** nothing that a pack citation covers. The 2026-09-07
  telemetry (sessions burning 2x-70x input re-deriving repo facts, up
  to 3.6M input tokens) is the measured cost of getting this wrong;
  context budget per node is therefore exactly the existing cap chain:
  pack 1500 bytes + known-context pointers + loadout caps. No new
  budget number is invented.
- **Depth-2 nodes** (a subtask of a subtask) exist only when the parent
  session spawns them natively (task subagents) -- the cycle never
  orchestrates depth 2 itself. One level of explicit decomposition is
  the whole model; deeper is the parent session's own problem.
### Parallel vs serial edges

The edge test is the inventory's file-conflict method
(2026-09-09-queue-dependency-inventory.md): two tasks are parallel iff
their touched-file sets are disjoint; any shared written file
serializes them, in dependency order if one declares it, else in plan
order. Three grounded calibrations:

- Append-only shared files (CHANGELOG.md, docs/research/) are LOW risk
  -- the inventory itself marks them "git handles multiple concurrent
  appends cleanly"; they do not serialize.
- The parallelism budget is already failfirst: full=3 / standard=2 /
  cautious=1 concurrent sessions per beat (failfirst-dev-concurrent-*
  rows), clamped by sessions-day-max. Decomposition never widens the
  slot count; it only decides WHAT rides each slot.
- Steps within one plan stay sequential (overnight-cycle.sh: "steps
  within a plan stay sequential"); decomposition therefore expresses
  parallelism by SPLITTING a step into sibling subtasks that can ride
  different slots of the same beat -- via separate routed sub-plans or
  explicitly parallel session launches inside one step's session.

### Re-decomposition trigger ("bubbles up" mid-flight)

A step that turns out harder than its plan text assumed is observable
by the existing watchdog vocabulary (steer-vs-die rubric): loop
repetition (3x identical calls), stall windows, unrecovered errors.
Today those signals route to steer-or-die. The forethought addition is
one more branch, ordered BEFORE die+replace: if the session's failure
shape is "the step was under-specified, not mis-executed" (error text
shows discovery churn -- new files/surfaces found mid-flight, repeated
re-planning) then the response is a DREAM PASS on the remainder
(section 2), not a death. The replacement session launches
failure-informed (handoff brief) AND dream-informed (the dream brief).
This reuses the steer-vs-die decision ordering: error still outranks;
only the "correct small step" question gains a third answer -- "no
small step exists yet; decompose first".

### What is genuinely missing

Only two things, and both are rows or conventions, not machinery:

1. **A decomposition record format.** Not a file format -- a WHERE. The
   lazy answer: the dream's proposed subtask split is written INTO the
   plan file as new `- [ ]` sub-steps (or, for steps too small to
   warrant that, into the session's handoff brief). The plan file is
   already the task schema; a decomposition that does not fit there is
   a decomposition the cycle cannot execute.
2. **A depth/effort knob.** One cadence-params row (section 3). Every
   other convention needed (risk classes, brief schema, conflict test)
   already exists in bestiary, handoff-brief-schema, and the inventory.

Deliberately NOT missing: no queue, no scheduler module (the delegation
research line already contracted multi-lane management to an
omp-bridge queue IF telemetry ever justifies it -- it has not), no
tree serializer, no new ledger.

## 2. Dreaming, concretely

A **dream pass** is a bounded, read-only, good-model session that
simulates one plan step before an executor touches it. No daemon, no
new cadence lane: it is one `launch_session` call with a `dream` role,
runnable on a cheap leg.

### Inputs and outputs

**Given:** the step text, the plan file's surrounding context, and the
context pack (same assembly as any session). Read-only repo access.
Hard-bounded: same loadout caps as any delegated session; a dream
timed out or dead files an alert and its step executes undreamed
(fail-open -- a dream may delay, never veto).

**Emits, in the handoff-brief's flat field discipline** (one
`field: value` line per field, single-line values, `not established`
never guessed -- 2026-08-30-handoff-brief-schema.md section 3):

- `requirements:` the list of facts that must hold before execution
- `failure-modes:` anticipated problems, each tagged with a bestiary
  class (bad-execution / missing-knowledge / missing-design /
  missing-authority / obsolete)
- `surfaces:` required files and surfaces to touch or read
- `split:` the proposed subtask decomposition (or `single-session`)
- `sanity-checks:` assertions the executor verifies FIRST, before its
  first edit (the dream's cheap falsifiable predictions)

**Artifact location:** `automation/prompts/overnight/<slug>.dream.md`,
next to the existing per-session prompt and context files. Those files
are already the precedent (per-session derived artifacts, never
sources of truth); no new state file class is created.

### Where it rides the cadence

Two entry points, both pre-existing beats:

1. **Pre-beat of overnight-cycle.sh (primary):** when the selector
   picks a plan step, build_plan_prompt gains a conditional dream
   launch before the executor launch -- gated by the forethought-depth
   knob (section 3). The dream file's sanity-checks are appended to
   the executor prompt ("verify these assertions first"). Cost: one
   bounded cheap-leg session ahead of the executor, inside the same
   beat's slot budget (the dream spends the slot, the executor the
   next; or the dream rides slot 0 and the executor slot 1 when
   concurrency allows).
2. **Research beat (secondary):** a recurring step that has died N
   times (failfirst demotion already tracks this) files a research
   demand subject "dream-<slug>"; the research beat runs the dream as
   one model_call-shaped bounded session. This is the re-decomposition
   trigger's landing point for work already in flight.

### What it costs

One cheap session per dreamed step. Measured legs: lobehub in-pipeline
30.4 s / 24.6k tokens-in (2026-09-10 probe row), ocgo glm-5.3-flash
~60 calls per $0.30 bounded-call cadence, kimi 71-78 s, local unsloth
264-361 s (free but slow). A dream is a single bounded call, so at
knob=1 it costs cents against an executor session that costs a full
slot plus a budget row. Latency, not dollars, is the binding cost on
the overnight cadence -- the dream must not double the wall time of a
beat that also runs parallel slots, which is why knob=1 defaults to
dreaming only risky steps.

### Anti-pattern guards

- **Advisory only.** A dream session never mutates (read-only role
  hint, like hngh-scout); its output is advisory context the executor
  verifies, never a gate. A sanity-check the executor cannot confirm
  is evidence for the executor to stop and report -- not a blocker the
  cycle interprets on the dream's word alone.
- **Predicted blockers route like real failures.** A dream that
  predicts a bestiary-class blocker files the same routing a real
  failure would get (bestiary routing table): missing-design -> gated
  research demand BEFORE grow admission; missing-authority -> operator
  packet row; missing-knowledge -> research-subjects.txt. The dream
  never improvises a route.
- **No dream-of-dreams.** Depth is exactly one: a dream may propose a
  split, never a dream about a split.

## 3. Forethought-effort optimization

The operator's sharp question: can hngh optimize effort spent on
forethought? Yes -- as a decision rule, not a framework:

> Dream when the expected cost of a wrong preparation exceeds the cost
> of the dream session.

Concretely, in the quota analysis's terms: a wrong preparation costs
one wasted executor session (a budget row, a failfirst degradation,
possibly a die+replace cycle with a respawn session -- 2-3 slots) plus
2x-70x input-token re-derivation on the replacement. The dream costs
one bounded cheap-leg call (cents, 30-80 s). So the dream pays for
itself whenever the probability of executor flailing on the step is
materially above zero -- which is a function of step class, not of a
new risk model:

| Step class | Dream? | Rationale |
|---|---|---|
| Kernel-touching / critical-adjacent (ceremony paths, src/-adjacent docs, anything risk=critical) | always dream | failure costs a ceremony cycle or an operator round-trip (missing-authority route is the slowest loop) |
| Steps claiming a capability not yet proven in-repo (new lifecycle hook, new API surface) | always dream | the failure is missing-knowledge -- cheapest to discover in a 30 s read-only pass than a dead session |
| Mechanical automation step sharing files with a sibling step | dream only for the conflict split | the inventory's file-conflict check is cheap; a dream adds the sanity-checks |
| Routine doc/record step, no shared files | no dream | failure cost ~= one rerun of a 1-session step |

### The knob: one cadence-params row

```
forethought-depth	1	scripts/overnight-cycle.sh build_plan_prompt (forethought design 2026-09-10)	0=off, 1=risky-steps-only (kernel-touching, unproven-surface, file-sharing), 2=always; env FORETHOUGHT_DEPTH overrides
```

One row, same shape as `ttsr-fit-threshold` or
`kimi-research-share`: named consumer, dated rationale, env override.
No subsystem. The row's "risky" classification is the section-3 table
itself, restated in the row's notes column so the consumer script
needs no separate policy file. Default **1** (section 5).

## 4. Immediate application -- the wave decomposition

Remaining steps of 2026-09-09-omp-hngh-integration.plan.md, decomposed
for delegation NOW. In-flight ownership noted: siblings are executing
step 5 (untracked .omp/skills/hngh/SKILL.md already on disk) and step
9 (research-lines.tsv / research-dispositions.tsv dirty) as of this
writing -- the wave routes AROUND them, never duplicates them.

File-conflict matrix across remaining steps (touched-file sets):

| Step | Writes | Shares with |
|---|---|---|
| 5 skill | .omp/skills/hngh/SKILL.md (untracked, in-flight) | none |
| 8 context-seeding | ~/.omp/plugins/hngh-bridge/src/index.ts (repo-external file: plugin, landed by step 4); fallback .omp/rules/ | none (plugin dir private to step 8) |
| 9 research feed | automation/mcp/hngh_mcp_server.py; research-lines.tsv wiring | TSVs in-flight by step-9 sibling; mcp server unshared |
| 10 dashboard endpoint | automation/dashboard-server.py; automation/dashboard/ page | dashboard-server.py flagged in the 2026-09-09 inventory as touched by 2 other accepted plans (low risk, different code paths); plans.json read-only here |
| 11 records | CHANGELOG.md (append-only), docs/records/, maybe plans/README.md | CHANGELOG low risk per inventory; README edit only if propose surface gained behavior |

Verdict: steps 5, 9, 10 are pairwise disjoint -> ONE parallel beat
(three slots = failfirst full). Step 8 is also disjoint, but its
sanity-check outcome (does print-mode fire session_start?) can change
its shape (extension event vs rulebook fallback), so it rides after
the first wave returns. Step 11 serializes last by dependency.

### Step 5 -- hngh skill (.omp/skills/hngh/SKILL.md)

- **Requirements:** orienting skill covering ceremony loop, plan-file
  contract, commit-per-green rule, kernel side-effect boundary,
  omp-bridge --orient entry; terse, links docs/README.md and
  docs/design/autonomous-development-control.md instead of duplicating.
- **Files/surfaces:** .omp/skills/hngh/SKILL.md (front-matter name +
  description drives triggering); verification = skill lists in an omp
  session in this repo and triggers on a ceremony question.
- **Difficulty:** medium -- the writing is easy, the trigger semantics
  are the risk (description wording determines firing).
- **Routing:** GOOD (the skill text is the product; wording quality is
  the whole deliverable). Cheap anyway.
- **Anticipated problems (dream sanity-checks):** (a) the skill must
  match omp's skill front-matter contract -- verify against omp://skills.md
  before promising trigger behavior; (b) the file already exists
  untracked from the in-flight sibling -- the landing step must
  reconcile with, not overwrite, that draft; (c) a skill that loads
  but never fires is a silent obsolete artifact (bestiary class) -- the
  trigger probe IS the verification, do not skip it.

### Step 9 -- research feed MCP tool

- **Requirements:** hngh-scout / research-beat outputs wired into
  automation/research-lines.tsv and research-dispositions.tsv
  conventions; new `research_lines` tool in the MCP server (extends
  step 1's server); tool returns live TSV contents; a research beat
  write reflects in the tool.
- **Files/surfaces:** automation/mcp/hngh_mcp_server.py (add tool to
  tools_list + handle_request dispatch, ~4 existing tools as the
  pattern); TSVs read-only from the tool's side.
- **Difficulty:** low -- mechanical adapter code following the four
  existing tools.
- **Routing:** FAST (mechanical, local/cheap leg).
- **Anticipated problems:** (a) the sibling session owns the TSV
  edits -- the MCP tool must read whatever convention the sibling
  lands, so land the tool AFTER the sibling's TSV shape settles or
  have the tool's read path follow the existing parser;
  (b) dispatch-table drift -- the server's handle_request must route
  the new name or the tool silently 404s; the throwaway stdio client
  probe (step 1's verification pattern) covers this cheaply;
  (c) empty/degenerate TSV rows must return a real response, not a
  crash (bestiary: bad-execution on the read path).

### Step 10 -- dashboard as operator UI

- **Requirements:** read-only JSON endpoint (or extension of
  automation/dashboard/plans.json) covering queue + accepted plans +
  last ceremony commit; a dashboard page rendering it; verifiable
  against queue.md and plans.json; readable from omp browser relay or
  scripts/dashboard-tui.
- **Files/surfaces:** automation/dashboard-server.py (exists, serves
  automation/dashboard/); automation/dashboard/ page + JSON route.
- **Difficulty:** medium -- single script + page, but the endpoint must
  agree with two ledgers it does not own (queue.md, plans.json) and
  the inventory already flags dashboard-server.py as multi-plan
  touched (low risk, different code paths -- confirm the other plans'
  steps are landed before editing).
- **Routing:** FAST-to-GOOD -- the route handler is mechanical (fast),
  the page rendering deserves one good pass if time allows; default
  fast.
- **Anticipated problems:** (a) read-only discipline: the endpoint
  must derive from the ledgers, never cache or duplicate state
  (context-pack law: packs are derived data); (b) plans.json is the
  4-plan conflict file in the inventory -- extending it WRITES it, so
  prefer a new derived endpoint name (e.g. operator-view.json) over
  mutating plans.json, which other accepted plans write; (c) live-data
  verification needs the dashboard actually serving -- verify with a
  curl against the local server, not a mocked fixture.

### Step 8 -- context-seeding

- **Requirements:** omp-bridge --orient runs automatically for every
  omp session entering this repo; output read-only and small; fresh
  session receives the brief without operator action; logs show one
  orient call per session start.
- **Files/surfaces:** ~/.omp/plugins/hngh-bridge/src/index.ts
  (repo-external, file: dep landed by step 4); fallback surface:
  a rulebook condition rule in .omp/rules/ if events cannot inject.
- **Difficulty:** medium -- the code is small, but the capability claim
  is the risk.
- **Routing:** GOOD (lifecycle correctness and the capability question
  outrank speed).
- **Dream sanity-checks (verified against omp://extensions.md
  2026-09-10):**
  1. omp extensions DO expose a `session_start` lifecycle event -- the
     capability is real, not assumed.
  2. Injection at session start uses `pi.sendUserMessage(...,
     {deliverAs: "nextTurn"})` or `appendEntry` -- verified surfaces.
  3. PITFALL, documented in omp://extensions.md: runtime action
     methods (sendMessage etc.) THROW during extension load; the orient
     call must live inside the `session_start` handler, never the
     factory body.
  4. PITFALL: delegated sessions run `omp -p` (print/headless) where
     `ctx.hasUI` is false -- anything routed through ctx.ui is a no-op;
     the orient brief must ride the message/entry path. UNVERIFIED:
     whether `session_start` fires identically in print mode -- the
     dream pass or the executor's first probe must confirm before the
     shape is promised.
  5. PITFALL: extensions run in-process with no isolation; an orient
     subprocess hang stalls session start -- bound the orient call with
     a timeout (the bridge is fast, but fail-open beats fail-hung).
  6. Dedup: verification demands ONE orient per session start -- guard
     against the event firing twice on resume/branch (session_before_
     switch family also exists; listen to session_start only).
  If (4) fails in print mode, the fallback is the rulebook condition
  rule the plan already names -- do not redesign, switch surfaces.

### Step 11 -- records

- **Requirements:** CHANGELOG.md entry + docs/records/2026-09-XX-omp-integration.md
  describing the integrated surface set; plans/README.md update ONLY
  if the propose surface gained behavior; make test green;
  cross-linked from CHANGELOG.
- **Difficulty:** low. **Routing:** FAST (write-up, local/cheap leg).
- **Anticipated problems:** (a) it depends on all steps landing -- do
  not start early; (b) the surface set description must match what
  actually landed (steps 1-4, 6 already in; 5/8/9/10 per their final
  shapes) -- cite the steps' verification probes as evidence rather
  than re-describing.

### Proposed beat plan

| Beat | Slots | Steps | Rationale |
|---|---|---|---|
| B1 (now) | 3 (full) | 5 (in-flight), 9 (in-flight), 10 | pairwise disjoint file sets; failfirst full = 3 slots |
| B2 | 1-2 | 8 (+10 tail if B1 left residue) | 8's shape depends on the print-mode session_start answer; runs after B1 frees slots |
| B3 | 1 | 11 | depends on everything; single fast session; ceremony-free (automation docs) |

Fast-vs-good summary: 5 GOOD, 8 GOOD, 9 FAST, 10 FAST, 11 FAST.

## 5. Verdict block

- **Effort knob default: 1 (risky-steps-only).** One
  `forethought-depth` cadence-params row, consumer
  overnight-cycle.sh's build_plan_prompt. Depth 2 (always) is
  unjustified by the measured costs: most steps are mechanical on
  cheap legs where a dream doubles beat latency for near-zero risk
  reduction; depth 0 discards the one measured expensive failure class
  (unproven-surface steps dying whole sessions). Revisit only after a
  dreamed step's sanity-check demonstrably saves a session (one datum,
  not a study).
- **First dream candidate: step 8 (context-seeding).** It is the only
  remaining step resting on an unproven capability (session_start
  injection in print mode -- sanity-check 4 above is explicitly
  UNVERIFIED). One bounded read-only pass answering that question
  before the executor launches is exactly the cost asymmetry section 3
  encodes. Steps 5/9/10 need no dream: their uncertainties are
  in-repo and already enumerated here.
- **What NOT to build (ponytail):**
  - No decomposition framework, no tree serializer, no scheduler
    module -- the delegation-lane line already rejected multi-lane
    management; decomposition is an operation on plan files.
  - No new state files: the plan file IS the task schema, handoff
    briefs ARE the dream artifacts (the 2026-08-30 schema said it
    first: "no new machinery is proposed"), context packs ARE the
    node budget. A dream brief lives beside the existing
    prompts/overnight artifacts as derived data.
  - No depth-2 orchestration, no dream gating, no dream ledger: depth
    one, advisory-only, fail-open, routed through the bestiary like
    any other failure signal.
  - The only genuinely new lines: one cadence-params row, one
    conditional launch in build_plan_prompt, one dream role hint in
    context-pack.sh. Three small diffs, no subsystem.

## Grounding

- Capability claim for step 8 verified against omp://extensions.md
  (2026-09-10): `session_start` event, load-time action restriction,
  print-mode ctx.hasUI=false, in-process isolation warning.
- Step/file facts verified against the repo 2026-09-10: plan checkbox
  states; .omp/skills/hngh/SKILL.md untracked (sibling in-flight);
  ~/.omp/plugins/hngh-bridge/package.json file: registration;
  automation/mcp/hngh_mcp_server.py four-tool dispatch;
  automation/dashboard-server.py present; cadence-params.tsv row
  conventions; failfirst-dev-concurrent-* rows.
- Latency/cost numbers cited from
  docs/research/2026-09-10-passthrough-and-quota-interleaving.md and
  cadence-params.tsv rows only; no new probes, no paid calls.
