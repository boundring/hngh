# Hngh Documentation Reorientation and Consolidation Plan

> **For Hermes:** Execute this only after the current card-147 review pause is explicitly reopened. Keep the workbench move and the planner fixture review separate.

**Goal:** Replace the current overlapping narrative with a small, authoritative set of Hngh documents that defines session control, afterlife analysis, project intent, and record ownership without losing evidence or mutating live state.

**Architecture:** Hngh has three different stores with different jobs: the repository holds reviewed policy, design, and implementation; `~/.hngh/` holds mutable runtime/workbench state; agent transcripts and raw artifacts are evidence, not the project’s working memory. A short-lived agent is a bounded execution lease. Its durable output is a verified task transition, evidence, receipt, and compact handoff—not a preserved conversation.

**Tech Stack:** Markdown, Git history, existing Hngh file lanes and append-only records, Common Lisp data contracts, Hermes/OpenCode/ACP adapters, llmtrim receipts, local fixture tests.

---

## Verified orientation

- Canonical workbench roots already exist and were migrated safely:
  `~/.hngh/.hngh-night/` and `~/.hngh/.hngh-day/`. The old paths are compatibility symlinks. Do not move, flatten, delete, or reclassify their contents in this documentation wave.
- The workbench state repository is intentionally dirty: runtime records plus both workbench trees are untracked. It is not a cleanup commit candidate until every path has a retention and recovery classification.
- `docs/project/next.md` identifies the active sequence as card 128 committed, card 147 independently reviewed, then card 127. The bounded review freezes card 147 and requires an independent review before its one serialized fast gate.
- The only current code diff is `tests/unit/test-hngh-planner.lisp`; its diff fingerprint at planning time is `11bdf5c1f89b3fcdfb4f2b764f2332473c0f9099844aa7ceb63c635aefe4e941`. This plan must not change it.
- Existing documents already establish much of the intended mechanism: `model-economy-and-context-lifecycle.md`, `situation-scoring.md`, `autonomous-action-policy.md`, `durable-coordination-records.md`, `workspace-migration.md`, and the active queue/card records. The problem is authority, overlap, chronology, and retrieval—not the absence of ideas.

## Assessment of the earlier response

The response correctly drew from the course notes: charter, WBS, scope, budget, risk, monitoring, closeout, and lessons learned all map well to Hngh. It is not yet an operational design.

1. It assigns numeric earned value to agents before defining an evidence model. `EV`, `CPI`, and `SPI` are not useful if “value” is a model’s self-assessment. Hngh must first measure verified acceptance, elapsed time, retries, token/price receipts, and impact on a named work package. Until then, cost is observed and value is `UNKNOWN`, not invented.
2. It treats every end as a failure/death. Hngh needs distinct terminal states: accepted, blocked, refused, expired, cancelled, failed, and compromised. “Death” is a useful internal metaphor, but it must not erase a successful closeout or turn a normal rate limit into moral failure.
3. It does not define a fact schema, data owner, retention rule, redaction rule, or authority path. An afterlife report without these becomes another transcript summary.
4. It has no transition rules. It does not say who may retire a session, release a claim, create a successor, reuse a lesson, or escalate to an operator.
5. Its Taoist references are decorative. Chuang Tzu is useful here as a restraint: do not force a stalled form to continue; preserve useful material while changing the vessel; prefer the smallest action that reveals reality. It is not a substitute for a state machine, fixture, or gate.
6. It proposes “hot-swappable strategies” without a fixed interface or promotion gate. Strategies must be adapters behind stable inputs/outputs, evaluated on fixtures, and unable to change task state directly.

## Core operating laws

These 24 laws become the front matter of the future session-control document. They are grouped for retrieval, but none is optional.

### A. Identity, scope, and authority

1. **Hngh persists; sessions are leases.** A session owns no durable truth. The task, claim, evidence, route receipt, and next action live outside it.
2. **One work package, one authority path.** Every session starts from a named card, exact write surface, named verifier, route class, budget cap, and stop condition.
3. **Scope is a boundary, not a preference.** A session may not broaden files, tools, privileges, research questions, or deliverables without a recorded change decision.
4. **Authority is narrow and named.** Model capability, a successful past run, or a persuasive response grants no authority. Only the task contract, verifier, and operator record do.
5. **The operator is the final authority.** Operator gates are explicit records. Workers release their claims and retire while awaiting a decision; they do not wait on a paid prompt.
6. **Policy, implementation, and evidence are separate.** A design document describes a rule, code enforces it, and a receipt proves one execution. No layer can impersonate another.

### B. Truth, evidence, and work control

7. **Evidence before narrative.** A claim is valid only through an evidence object: fixture result, command output, source probe, receipt, or operator decision. A model’s prose is a hypothesis.
8. **A baseline precedes a metric.** Cost, quality, duration, retries, and acceptance must be recorded before trends, scores, or forecasts are trusted.
9. **Metrics are decision aids, not theatre.** Use hard measurements first. Derive cost/schedule indices only when the work package has an accepted baseline and an independently verified completion value.
10. **Unknown is a first-class outcome.** Missing price, route, token receipt, source state, or test result is `UNKNOWN`, never zero, success, or a reason to guess.
11. **Claims have one writer and a visible release.** A work surface cannot be silently taken over. Completion, handoff, and retirement reconcile the claim at the registry read surface.
12. **Verification is independent of production.** The agent that writes a deliverable may supply evidence but may not mark its own work accepted unless the task explicitly names that self-check as sufficient.

### C. Session economy and control

13. **Retirement is normal.** Completion, verified blocker, refusal, no-progress bound, context threshold, budget bound, or safety breach ends the lease. Continuation is an exception with a recorded reset-loss justification.
14. **Failure is classified, not punished.** The system records a factual terminal class and a remediation class. It never infers intent, competence, or blame from one run.
15. **The handoff is the bridge.** A successor receives a compact factual packet and current state, never an entire transcript by default.
16. **Context is a budgeted physical resource.** Record components, set thresholds, compress at phase boundaries, and refuse unrelated continuation before a window becomes a crisis.
17. **Cost is bilateral and pre-admitted.** Count both input and output, reserve scarce capacity before dispatch, reconcile actuals afterward, and fail closed when the route or quota is unknown.
18. **Least action beats forced continuation.** Read source and current state before probing; choose the smallest safe next verification; do not keep an unsuitable agent alive merely because it already has context.

### D. Afterlife, learning, and adaptation

19. **Afterlife is a reduction pipeline.** Raw material is retained only under a defined privacy and retention policy; a deterministic extractor produces receipts and events; a local summarizer may propose a lesson; a verifier decides whether the lesson enters the case base.
20. **Chain of custody survives compression.** Every derivative report carries its session/task identity, source references, redaction class, producer route, and evidence digest. A summary without provenance is disposable prose.
21. **Lessons compete with prior lessons.** A candidate is searched against the local case base and MisakaNet, marked accepted/adapted/rejected/deferred, and expires or revisits on a stated condition. Repetition is not learning.
22. **High capability teaches; low cost executes.** A scarce model returns bounded decisions, invariants, counterexamples, and unknowns. Workhorse/local agents convert those into cards, fixtures, adoption maps, and measured outcomes.
23. **Promotion requires a measured improvement.** A new prompt, adapter, policy, or model route enters the default path only after a fixture comparison shows sufficient quality, cost, latency, or recovery benefit.
24. **Communication is bounded by need.** A heartbeat reports state transition, evidence, blocker, or next action. It is not a conversational diary. Chuang Tzu’s contribution is restraint: preserve what proved useful, change the vessel freely, and do not force a stalled form to continue.

## Canonical records to create

Create these files only in the documentation reorientation wave. They are deliberately absent today.

| File | Authority | Purpose | Must not contain |
|---|---|---|---|
| `docs/project/charter.md` | Project intent | Business need, portfolio case, target users, scope, non-goals, stages, success measures, operator authority | Implementation history or active cards |
| `docs/design/roguelike-session-lifecycle.md` | Session control | Lifecycle state machine, transition guards, terminal taxonomy, afterlife schema, succession protocol, Taoist restraint principles | Tool-specific configuration values or raw transcripts |
| `docs/design/document-governance.md` | Documentation topology | Source-of-truth map, status labels, archival rules, naming, ownership, review/update triggers | Duplicate policy prose |
| `docs/project/active-frontier.md` | Volatile execution index | One ordered table: card, dependency, claimed surface, verifier, current gate, next evidence | Long historical narratives |
| `docs/project/metrics-and-evaluation.md` | Measurement rules | Baselines, receipt fields, when EV/CPI/SPI are permitted, quality and cost metrics, unknown semantics | Motivational scoring or unverifiable quality ratings |

`docs/project/next.md` remains the new-session handoff. After consolidation it links to `active-frontier.md`, rather than carrying the full project history and competing priority lists.

## Session lifecycle contract

The new design must define this state machine before a new lifecycle implementation card exists:

```text
proposed
  -> admitted | refused
admitted
  -> running | cancelled
running
  -> checkpointed | awaiting-operator | retired
checkpointed
  -> running | retired
awaiting-operator
  -> retired
retired
  -> afterlife-pending
afterlife-pending
  -> closed | successor-ready | case-review
case-review
  -> closed | successor-ready
```

Terminal reason is one enum, not free prose:

```text
accepted | blocked | refused | expired | cancelled | failed |
policy-denied | budget-exceeded | context-exceeded | safety-incident |
external-unavailable | unknown
```

The afterlife reducer may add contributing factors, but it may not change the terminal reason or reopen work. Only the task/verifier/operator path may do that.

### Minimum session charter

```lisp
(:session-id :task-id :attempt-id :parent-session-id
 :role :route :provider :model :route-class
 :write-boundary :verifier :authority :budget-envelope
 :acceptance-command :stop-conditions :started-at)
```

### Minimum terminal receipt

```lisp
(:session-id :task-id :attempt-id :terminal-reason :ended-at
 :claim-state :deliverables :evidence-refs :next-action
 :usage-receipt :context-ledger :safety-events :redaction-class)
```

`usage-receipt` accepts `:unknown`; unknown cost, token count, or provider mapping is never rendered as zero. `deliverables` list paths and digests, never copied content.

### Lesson promotion path

```text
raw transcript / logs (restricted evidence)
  -> deterministic event and receipt extraction
  -> redacted local summary candidate
  -> duplicate search (case base and MisakaNet)
  -> verifier disposition: accept | adapt | reject | defer
  -> case-base record with evidence and expiry/revisit condition
```

A candidate lesson cannot steer a live session, rewrite policy, or alter routing. It becomes operational only through a named card, fixture, or operator decision.

## Wave-ordered execution

### Wave 0: Preserve the present boundary

**Objective:** Do not contaminate the current independent-review boundary or runtime state.

**Files:**
- Do not modify: `tests/unit/test-hngh-planner.lisp`
- Do not modify: `~/.hngh/` state or workbench content
- Read: `docs/review/project-review-2026-08-10.md`, `docs/project/next.md`, current claims registry

**Steps:**
1. Obtain the independent review on the exact card-147 diff fingerprint.
2. Reconcile the stale card-128 claim at the registry read surface.
3. Run the one serialized fast gate only after the reviewer verdict is pinned to the reviewed diff.
4. Record those results separately from documentation consolidation.

**Acceptance:** card-147’s review and gate are not diluted by reorientation work; no runtime/workbench mutation occurs.

### Wave 1: Produce a read-only records manifest

**Objective:** Classify every current document and runtime top-level path before consolidation.

**Files:**
- Create: `docs/project/consolidation-manifest-2026-08-10.md`
- Read: `docs/`, `~/.hngh/`, `~/.hngh/.hngh-night/`, `~/.hngh/.hngh-day/`

**Steps:**
1. Enumerate paths with byte size, modification time, Git tracking status, and content digest.
2. Mark each document one of: `canonical`, `active index`, `implementation spec`, `research`, `journal`, `historical`, `superseded`, `runtime evidence`, `raw transcript`, `duplicate candidate`, or `unknown`.
3. For every duplicate candidate, identify the canonical source and whether the duplicate holds unique historical evidence.
4. Assign a retention class: `versioned`, `runtime-git`, `append-only`, `ephemeral`, `redacted archive`, or `operator decision required`.
5. Do not move, rename, delete, or rewrite a path in this wave.

**Acceptance:** every planned move has a source, destination, reason, recovery route, and reviewer. Unknowns block a move.

### Wave 2: Establish the small canonical design set

**Objective:** Write the five canonical records above, using links instead of copying policy.

**Files:**
- Create: `docs/project/charter.md`
- Create: `docs/design/roguelike-session-lifecycle.md`
- Create: `docs/design/document-governance.md`
- Create: `docs/project/active-frontier.md`
- Create: `docs/project/metrics-and-evaluation.md`
- Modify: `docs/project/next.md`
- Modify: `docs/project/roadmap.md`
- Modify: `CHANGELOG.md`
- Modify: `docs/journal/YYYY-MM-DD.md`

**Steps:**
1. Draft the charter from project intent, current scope, safety posture, and consulting portfolio purpose.
2. Draft the lifecycle document from the contract in this plan; link existing context, route, claim, watcher, and situation documents as subordinate implementation/design sources.
3. Define document status labels: `DRAFT`, `DESIGN`, `IMPLEMENTED`, `VERIFIED`, `SUPERSEDED`, `HISTORICAL`.
4. Reduce `next.md` to the handoff and active order. Place the detailed active table in `active-frontier.md`.
5. Replace stale project status summaries with links to current evidence. Do not fabricate a test baseline.
6. Add a dated changelog and journal entry that states the documentation changes, no code behavior changes, and the exact review boundary preserved.

**Acceptance:** each live policy has one home; `next.md` has one active frontier; no canonical document duplicates another document’s normative rules.

### Wave 3: File existing material without information loss

**Objective:** Turn the manifest into reviewed archival moves and compact indices.

**Files:** exact paths selected from the Wave 1 manifest only.

**Steps:**
1. Move only documents classified `historical` or `superseded` into `docs/archive/YYYY-MM/` with a one-line pointer from their former logical index.
2. Keep Git history intact; use `git mv` only after a review of the manifest row.
3. Replace duplicated prose in canonical files with a short scope statement and a link to the authority.
4. Keep research as research. It may inform a design but never silently become policy.
5. Preserve raw transcripts outside public documentation. If an extract needs to be public, redact first and retain a digest/reference to the restricted original.

**Acceptance:** no path is deleted; every archived item remains findable from an index; `git diff --check` passes; the documented authority map resolves every link.

### Wave 4: Reconcile workbench state safely

**Objective:** Clean the `~/.hngh/` state repository without mistaking operational evidence for disposable clutter.

**Files:** exact files selected by the Wave 1 manifest only.

**Steps:**
1. First create a scratch-HOME fixture for every proposed move/ignore/retention rule.
2. Separate runtime state, workbench records, secrets-adjacent records, raw transcripts, and backup-manager bookkeeping.
3. Preserve the canonical hidden roots and compatibility symlinks. Introduce the work-root getter/referencer sweep as a separate code card, as `workspace-migration.md` specifies.
4. Add `.gitignore` entries only for explicitly ephemeral/generated paths. Do not ignore evidence merely because it is inconvenient.
5. Make an auditable backup-manager capture in a separate bounded commit only after the manifest and retention classes are approved.

**Acceptance:** a scratch fixture proves idempotence and rollback; tracked runtime records have an explicit retention reason; no secrets or unredacted user text enter a public surface.

### Wave 5: Convert the lifecycle design into fixture-backed implementation cards

**Objective:** Build only the minimum procedural seams required to enforce the contract.

**Files:** to be selected after Wave 2; likely `src/plugins/`, `tests/unit/`, and adapter-specific launch scripts.

**Order:**
1. Session charter/terminal receipt validation and append-only journal writer.
2. Context ledger and retirement predicate (card 131).
3. Compact handoff generator (card 132).
4. Adapter receipt ingestion and actual-route verification.
5. Afterlife reducer with fixed terminal taxonomy and redaction gate.
6. Case-base lesson promotion, duplicate search, verifier disposition, and expiry.
7. Metrics evaluator using fixture records; add EV/CPI/SPI only where the baseline is measurable.

**Acceptance:** every transition has a fixture; malformed records fail closed; an afterlife strategy cannot change task state; a fresh successor can complete its next verification from a packet without loading an old transcript.

## Verification

Documentation-only waves:

```bash
git diff --check
find docs -type f -name '*.md' -print0 | xargs -0 grep -nE 'TODO|TBD' || true
python3 scripts/lint-parens.py <touched-lisp-files>  # only if Lisp changes
make lint-counts                                    # when current-state records change
```

Implementation waves add focused FiveAM suites first, then exactly one serialized repository gate. The review-pause rule remains: do not run a replacement gate merely to obtain a prettier status line.

## Risks and controls

| Risk | Control |
|---|---|
| Deleting the only copy of a useful artifact | Manifest first; archive/move with digest and Git history; no destructive cleanup wave |
| Mistaking runtime state for source code | Separate retention classes and scratch-HOME fixtures |
| Moving active lanes while a seat writes | Phase-boundary acknowledgement; append-only lane contract; watcher pause only in a separately approved migration |
| A prose “lesson” silently changing policy | Lesson disposition requires verifier and named card/fixture/operator record |
| Privacy leak from transcript mining | Raw text off by default; redaction class and digest-only public references |
| Measuring fictional value | `UNKNOWN` until a work package baseline and independent acceptance exist |
| The Taoist vocabulary masking missing mechanisms | Every philosophical principle maps to a testable record, state transition, or refusal rule |
| Parallel editors colliding with reorientation | Claims and explicit write boundaries; one canonical-document writer at a time |

## Decision gate

Proceed with Wave 1 only after the operator confirms this scope: preserve all raw evidence, make no destructive move, treat `docs/project/next.md` as the handoff and `active-frontier.md` as the single volatile execution index, and adopt the session terminal taxonomy above.
