# Bounded Design Review: Hngh Tight Cycles and Roguelike Run Model

**Verdict:** Hngh fits a Clean Architecture and tight-cycle model well, provided the game language names visible states and records rather than disguising control flow. The right synthesis is a small, deterministic run kernel with replaceable model, terminal, filesystem, and provider adapters. It is not an autonomous game master.

This review reads the supplied local bundle as a secondary index, then checks the core engineering claims against five Robert C. Martin blog posts. Reviewed local inputs: `artifacts/uncle_bob_practical_addendum.md`, `artifacts/uncle_bob_practical_addendum_references.md`, and `artifacts/chapter_5_content.md`, `chapter_7_content.md`, `chapter_9_content.md`, and `chapter_10_content.md`. The other supplied chapters were not reviewed line by line. This review excludes the bundle's social-political material by request. It does not implement the proposed design.

## 1. Contradictions

1. **The supplied bundle has no stable chapter map.** `uncle_bob_practical_addendum.md:100` labels Chapter 5 “Architecture and System Design,” while `chapter_5_content.md:1` labels it “Functional Programming.” This is not a substantive architectural disagreement, but it means chapter numbers cannot be cited as durable references. Use article titles and URLs, or a new Hngh-specific reading guide.

2. **The local transformation rule is presented as settled procedure, but the source treats it as a useful, incomplete premise.** `chapter_7_content.md:59-67` turns the Transformation Priority Premise into a four-step ordering. Martin explicitly calls its priority, completeness, and formalization open questions, even while recommending simpler transformations as a practical guide.[3] Hngh should use it as a prompt for choosing the next small test, never as a mechanical planner that declares a valid change impossible because it did not match a list.

3. **The local text overstates the relationship between types and tests.** `chapter_5_content.md:90-94` correctly says type checking does not establish external behavior. `chapter_5_content.md:104-110` then extends that into “you don't need static type checking if you have 100% unit test coverage.” For Hngh, this is unsafe. Schema checks, restricted parsers, permissions, and validated capability records protect boundaries before tests run; behavioral tests then protect intended outcomes. Neither substitutes for the other.

4. **The local text risks converting “testable” into “designed for the test harness.”** The addendum says tests should use a small public API and warns against test-induced design damage (`uncle_bob_practical_addendum.md:53-67`, `127-135`). The useful distinction in the primary source is separation by independent reasons to change, not extracting an interface merely to mock it.[4] Hngh must introduce a port only when an external concern is genuinely replaceable or needs controlled failure behavior: clock, filesystem, model call, tool execution, provider accounting, or rendering.

5. **The bibliography is a reading list, not a source ledger.** The reference addendum gives useful article links but repeats entries (`uncle_bob_practical_addendum_references.md:293-321`) and gives no per-claim citations in the chapters. The prose may be sound, but a future Hngh policy cannot rely on “drawn from the blog” (`uncle_bob_practical_addendum.md:9-11`) as evidence. Keep primary-source citations next to policy claims that affect safety, cost, or autonomy.

6. **The current campaign/expedition/room/camp draft and the requested run vocabulary are competing operator interfaces.** The existing plan treats “expedition” as the primary delivery unit. The requested vocabulary makes a **run** the primary delivery unit and gives clear names to setup, termination, salvage, learning, and scoring. The latter is better for ephemeral model sessions. Keep the old words out of the operator surface; retain only the underlying safeguards: bounded scope, tests, review, evidence, and a clean end.

## 2. Missing guardrails

1. **A run must be a finite state machine, not a colorful session label.** Define legal transitions and reject all others. The minimum path is:

   ```text
   draft -> created -> armed -> running -> checkpointed -> running
                                           |              |
                                           v              v
                                      evacuated         dead
                                           \              /
                                            -> afterlife -> scored -> archived
   ```

   `armed` means the operator-approved brief, loadout, budget, and tool permissions are present. `dead` is a controlled terminal outcome: exhausted budget, expired lifetime, failed gate, unsafe request, lost prerequisite, or explicitly abandoned objective. It is neither shame nor a trigger for automatic retry.

2. **The save file needs a precise boundary.** A system profile is durable local configuration, not a memory dump, a prompt transcript, or a global authority token. It selects allowed local roots, enabled capability classes, default safety posture, and named budget policies. Per-run state must live below a separate run identifier. No run may alter a save file without an explicit operator-approved operation, a before/after receipt, and a replacement rule.

3. **Character selection must describe capability, not personality.** A character is a versioned role template: allowed tools, default context ceiling, allowable model classes, review duties, and handoff format. It must not grant hidden permissions based on a narrative persona. A “Killy” or “Cibo” skin may appear in rendered text; the machine-readable role remains a narrow capability record.

4. **Level selection must be an authority tier, not progression.** A level says what kind of side effect is permitted: local analysis, repository edit, test execution, external read, external write, or privileged machine operation. Reaching a higher level does not grant access. Each level has an operator-set entry gate and an explicit exit condition. A model cannot level itself up.

5. **The inventory/loadout needs hard limits.** A loadout is an immutable declaration of model route, context ceiling, maximum calls, token/cost allowance, time limit, writable paths, tool allowlist, network posture, and required test command. It is validated before a run starts. Any missing or unknown field denies start. A high-context single completion is allowed only as a named loadout item with a reason, an output path, and a verification step; it is an untrusted draft until the normal tests and review pass.

6. **“Profit margin” needs a non-gameable definition.** Do not collapse quality, cost, safety, and speed into a single score. Record separate measures: verified deliverable value, actual model/tool cost, remaining budget/time/permission headroom, test evidence, rework, and operator assessment. A run loses margin when it spends constrained resources without producing a verified artifact or a reusable lesson. Scores inform tuning; they never authorize an action or punish a model.

7. **Death and afterlife need salvage and containment rules.** On death, stop further side effects, preserve the last verified checkpoint, collect actual command output and changed-path list, close or invalidate temporary credentials, and write an afterlife record. The record contains cause category, evidence, salvageable artifacts, rejected hypotheses, and one candidate lesson. A lesson becomes policy only after review; otherwise it remains a local observation.

8. **Evacuation must be the preferred terminal path.** A successful run ends by producing named deliverables, test evidence, a concise handoff, cost facts, and a clean workspace. It does not remain alive for conversational convenience. “Live” means the next bounded step remains authorised and useful; it does not mean an agent is entitled to keep spending tokens.

9. **Parallel runs require ownership before concurrency.** Each active run claims an exclusive write surface and declares read-only dependencies. Independent readers may work in parallel. Two writers may not touch the same source, state root, receipt stream, or release artifact without a planned integration run. A reviewer checks the integrated result, not a collage of individual green tests. Model identity and a prior green result are not trust grants; trust comes from the evidence and review required for the risk of the change.[5]

10. **The scoreboard needs a privacy and retention policy.** Store aggregate, operator-useful evidence, not prompt transcripts, secrets, personal paths, or provider credentials. Every metric needs an owner, a calculation definition, a retention period, and a reason to exist. If a metric cannot change a decision, do not collect it.

11. **The architecture boundary must survive adapters.** Martin's dependency rule keeps source-code dependencies inward: policy does not name frameworks, databases, UIs, or external agencies.[1] For Hngh, model providers, Hermes, OpenCode, tmux, the filesystem, Git, and systemd are all outer details. Their response formats do not enter the run kernel. The kernel speaks only through its own ports.

12. **Tests require layers and a measured speed budget.** A fast trusted suite enables continuous cleanup, but fast tests alone do not prove a good boundary. Martin argues that separating independently changing concerns makes tests both faster and more changeable.[4] Hngh needs pure policy tests per room, fixture-backed port tests per run, and small end-to-end acceptance checks per release gate. Set time targets from measured baselines; do not invent a universal seconds limit.

## 3. Exact proposed section bullets

These are proposed document sections and architecture rules. They are ready to turn into the fresh Hngh documentation when the operator opens that implementation phase.

### `docs/operating-model.md` — “The Run Loop”

- **Save file:** A versioned, fail-closed system profile. It carries approved local policy, never transient agent memory.
- **New run:** A finite, uniquely identified attempt to deliver one bounded objective.
- **Character creation:** Select a declared role template and model route. The template grants no capability beyond its loadout.
- **Level select:** Select an operator-approved authority tier. A tier constrains effect classes; it is not a reward ladder.
- **Inventory/loadout:** Freeze context, token, time, tool, path, network, and review limits before start.
- **Mission brief:** State objective, non-objective, source facts, acceptance criteria, exact writable paths, verification commands, and evacuation condition.
- **Start run:** Create durable run state and a receipt only after all entry checks pass.
- **Live:** Repeat one behavior-sized RED → GREEN → REFACTOR room. Checkpoint only green, reviewed facts.
- **Evac:** End normally with deliverables, evidence, cost record, handoff, and clean ownership release.
- **Death:** End safely when a hard limit or safety rule trips. Preserve evidence; issue no automatic retry.
- **Afterlife:** Salvage verified work, record the failure category, distinguish fact from hypothesis, and propose at most one lesson.
- **Scoreboard:** Report delivery, quality, cost, safety headroom, and reuse separately. It has no authority to spend, launch, or approve.

### `docs/architecture.md` — “The Megastructure Has an Inside”

- **Entities:** Profile policy, run state, role template, loadout, mission brief, checkpoint, artifact manifest, outcome, lesson candidate, and score record.
- **Use cases:** Create run; arm run; admit next room; record checkpoint; evacuate; declare death; perform afterlife; score; archive; render read-only history.
- **Ports:** Clock, identifier source, state store, receipt store, budget ledger, model completion, tool executor, repository inspector, artifact store, and report renderer.
- **Interface adapters:** CLI, local filesystem, Git, terminal runner, Hermes bridge, model-provider clients, and later dashboard or webhook code. They translate into kernel data and own transport failure details.
- **Frameworks and drivers:** Common Lisp runtime, ASDF, SBCL, shell, tmux, systemd, provider SDKs, databases, and user interfaces. Each remains replaceable detail.
- **Dependency rule:** Dependencies point toward entities and use cases. Flow may cross outward through a port, but source dependencies and external payload shapes do not.
- **Boundary test:** A pure use-case test must run with a fake clock, fixture store, fake budget ledger, fake completion port, and fake tool executor. If it needs a provider client or the real home directory, the boundary has failed.

### `docs/testing.md` — “Tight Cycles, Not Tiny Thoughts”

- **Nano-cycle:** Write the smallest failing behavioral assertion or fixture case. Make only the code needed for that case pass.
- **Micro-cycle:** Run the focused check, make it green, then improve names, duplication, and seams while all checks remain green. No green result ends without the refactor question.
- **Specific/general check:** After several rooms, ask whether production code is merely mirroring examples or already accepts plausible unwritten cases. Prefer the simplest change that genuinely broadens the solution. Martin describes this as a practical heuristic, not a formal algorithm.[2][3]
- **Boundary check:** At each handoff or other measured primary interval, inspect dependency direction, state ownership, test speed, and whether a new external detail has leaked inward. Martin explicitly describes this larger architectural cycle alongside the fast TDD cycles.[2]
- **Test design rule:** Tests assert behavior through stable use-case boundaries. They do not require production classes or ports that have no independent reason to change.
- **Fixture rule:** External input, state, time, and tool output are fixtures. Live services are never a prerequisite for a policy test.
- **Failure rule:** A red test, malformed state, unknown quota, or missing acceptance criterion blocks advance. The response is containment, not optimistic continuation.

### `docs/agent-session-contract.md` — “Ephemeral Cognition”

- **Session role:** An agent session is a replaceable worker for one run or one explicitly named read-only task. It does not own product memory.
- **Run packet:** Every new session receives a compact, source-grounded packet: mission brief, relevant facts and their paths, loadout, current checkpoint, allowed paths and tools, verification command, and evacuation condition.
- **Handoff packet:** Every session emits only durable facts: changed paths, actual verification output, artifact locations and digests, cost facts, unresolved blockers, and the next smallest admissible move.
- **Compression rule:** Summaries are references to durable records, not new authority. A resumed session must revalidate state and repository facts before acting.
- **Context benchmark:** Test a fixed corpus of representative rooms at several context ceilings and model routes. Measure pass rate, repair rate, elapsed wall time, input/output tokens, cost, review findings, and quality of the afterlife record. Change one variable per benchmark. Do not infer a context policy from anecdote.
- **Large-output exception:** A one-time large-context completion may write a named draft or generated artifact. It receives no exemption from path limits, test gates, review, cost recording, or attribution.
- **Model policy:** Use local and low-cost models for bounded retrieval, fixture drafting, mechanical edits, and narrow repair attempts. Use Luna as the normal high-quality implementation/review route when its loadout admits it. Use Terra where its trade-off is adequate. Reserve K3 for operator-approved, compact questions or a one-off high-value artifact with a fixed budget; never treat its quota as an invitation to create a standing session.

### `docs/aesthetic.md` — “Quiet Megastructure, Plain Interface”

- Use Nihei influence in names, visual hierarchy, status phrasing, and short narrative receipts. Keep operational language concrete.
- A **Safeguard** is a guardrail, never an armed automated actor. A **Silicon Life** is an untrusted external agent or adapter, never a person. A **Garde** is a validated protective boundary. These references remain optional presentation labels.
- A green checkpoint may be rendered as a quiet maintained sector; an evacuation as a returned artifact cache; afterlife as a salvage record. No system state depends on metaphorical wording.
- Avoid lore that obscures risk, privilege, cost, ownership, or failure cause. The operator must be able to read any status line without knowing *BLAME!*, *Knights of Sidonia*, or *Tower Dungeon*.
- Do not make survival, death, achievement, or score mechanics socially manipulative. The point is clear endings and retained learning, not gamified pressure.

### `docs/roadmap.md` — “Recommended implementation order”

1. Seal the archive and establish the test harness, documentation index, decision log, and pure domain data.
2. Implement the profile and run state machine with invalid-transition fixture tests.
3. Implement immutable loadouts, capability tiers, budget ledger ports, and admission tests. Unknown ledger state denies automatic action.
4. Implement checkpoint, evacuation, death, afterlife, and artifact-manifest use cases with fixture stores.
5. Implement the read-only scoreboard from stored outcomes; validate retention and no-secret rules.
6. Add a manual CLI adapter. Prove it against fixtures before it resolves any live root.
7. Add one model-completion adapter behind a fakeable port and an explicit loadout. Keep execution manual.
8. Run the context-ceiling benchmark and record the evidence before adding a scheduler, watcher, dashboard, or multi-session coordination feature.
9. Add further adapters one at a time. Every adapter starts disabled and earns automation only after its manual run loop is trusted.

### Acceptance criteria for the synthesis

- A complete run can be created, armed, run through a fixture-backed room, evacuated, and archived without contacting a model provider, starting a process, or touching `~/.hngh`.
- Every illegal state transition, unknown budget value, missing loadout field, path escape, malformed state record, and missing verification result fails closed in a fixture test.
- The inner policy packages mention no provider, terminal, filesystem, Git, Hermes, tmux, systemd, or UI symbol.
- A run that dies produces a bounded afterlife record and no automatic retry.
- A successful evacuation produces a deliverable manifest, actual verification evidence, and a concise next-session packet.
- The scoreboard can be regenerated from receipts and manifests alone. It does not inspect prompts or secret-bearing logs.

## 4. Questions operator must decide

1. **Operator-gated — What is the first useful deliverable?** Choose one: (A) a pure local run kernel plus fixture CLI; (B) a read-only session/quotas scoreboard; or (C) one manual model-completion adapter. Recommendation: **A**. It proves the state and boundary contracts before external cost or process risk enters.

2. **Operator-gated — What does “profit margin” optimize first?** Choose the reporting priority: verified deliverables per cost, safety headroom, turnaround time, or learning reuse. Recommendation: track all four separately and select one as the first dashboard sort order; do not authorize work from a composite score.

3. **Operator-gated — May Hngh ever store prompt bodies?** Recommendation: no by default. Store hashes, provenance, bounded summaries, and artifact links. Allow a separate explicit retention mode only for reproducible benchmarks with a defined deletion date.

4. **Operator-gated — Which capability tier may be automated first, if any?** Recommendation: none in the first campaign. The first enabled automation should be read-only health observation after the manual equivalent has passing fixtures and a reviewed failure policy.

5. **Design-gated — Should theme names be stored as canonical enums or render-time aliases?** Recommendation: canonical technical enums such as `:evacuated` and `:afterlife-complete`, with optional display text such as “artifact cache returned” in the renderer. This keeps receipts searchable, interoperable, and durable.

6. **Design-gated — Is a character a reusable static role or a per-run copy?** Recommendation: versioned static role template plus immutable per-run loadout snapshot. This makes later policy changes auditable without rewriting history.

7. **Design-gated — What proves a lesson earned promotion to policy?** Recommendation: one reproducible failure or benchmark, one proposed guardrail, one fixture that would have caught it, and operator acceptance. Repeated narrative summaries alone are not evidence.

8. **Design-gated — What context ceilings should the benchmark test?** Recommendation: choose tiers from actual model and provider limits, then hold the task corpus and loadout constant. Do not choose numerical ceilings in this document; they are calibration facts, not architecture.

9. **Design-gated — When should a stronger model be admitted?** Recommendation: only when a cheaper route has a recorded failure category that the stronger route is expected to resolve, or when a one-off artifact needs its larger effective context. The run record must name the reason before the call, not rationalize it afterward.

10. **Design-gated — How much Nihei flavor belongs in the first CLI?** Recommendation: one quiet status line and optional display aliases only. The first kernel should be legible to an operator who has never read the works; richer presentation waits until the underlying lifecycle is stable.

## Sources

[1] https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
[2] https://blog.cleancoder.com/uncle-bob/2014/12/17/TheCyclesOfTDD.html
[3] https://blog.cleancoder.com/uncle-bob/2013/05/27/TheTransformationPriorityPremise.html
[4] https://blog.cleancoder.com/uncle-bob/2014/05/01/Design-Damage.html
[5] https://blog.cleancoder.com/uncle-bob/2014/02/27/TheTrustSpectrum.html

Attribution: Hermes — gpt-5.6-terra via openai-api, Hermes TUI. 2026-08-11.
