# Hngh Autonomy Strategy — Self-Developing, Self-Healing, System-Harnessing Engine

**Status**: Research synthesis — 6 threads, all COMPLETE (2026-08-07).*
Consolidated into a wave-ordered plan in §7; sources live in the companion
research reports `swe-selfdev-research.md`, `security-agentic-research.md`,
and `coordination-patterns-research.md`.
**Scope**: M9+ long arc — how Hngh becomes a self-developing, self-healing,
system-harnessing engine for a broad variety of agentic tasks, up to and
including part/all of an automated workforce for a consulting business, with
peer-deployed instances and a broad plugin/extension/hardware surface.
**Companions**: squad-autonomy.md, squad-startup-automation.md,
squad-metabolism.md, benchmark-sourcing.md, model-routing.md, model-pareto.md,
sentry.lisp (security substrate), phase2-claim-release.md.

---

## 0. North star

> Automate as much of the clean-architecture approach to project management,
> software design, and implementation as possible, using beans, squads,
> local + cheap-remote LLMs, and hard cost gates — so Hngh continuously
> develops and heals itself, and can later coordinate fleets of peer
> instances as a workforce.

This document is the synthesis of delegated research across six threads
(self-development, multi-agent memory, clean-arch self-modification,
security, cheap inference, ecosystem integration). Each section records the
findings, what transfers to Hngh, and the roadmap implications. It is a
living strategy doc — findings land, sections harden, and actionable items
graduate into docs/project/roadmap.md and the design docs.

---

## 1. Self-developing systems (research COMPLETE — delegated subagent; synthesis below)

**Source**: `swe-selfdev-research.md` (26-source cited report).

### From titled-agent → to spec → passing tests (verified ground truth)

- **SWE-agent** (Princeton, NeurIPS 2024) established the *agent-computer
  interface* (ACI) thesis: the agent's scaffold (which commands, what the
  observation format is) matters as much as the model. Design the harness
  surface deliberately — not just "give the model a shell." Hngh's dispatch
  tree + beans + tool hub *are* its ACI; keep improving that surface, it's a
  first-class lever.
- **OpenAI Codex agent loop** (engineering blog, 2026-01): a TDD-driven
  retry loop — generate test → run → get failure → repair → re-run until
  green — with code "unrolled" through sandboxed, parallel execution. The
  loop, not the model, is the product. Transfer: Hngh's C6 planner should
  own the *loop* (test→run→repair→re-run bounded by cost gates), not delegate
  the whole thing to one model call.
- **OpenHands Software Agent SDK** (arxiv 2511.03690): a *composable,
  extensible foundation* — agent = swappable planner + action executors +
  event stream, not a monolithic run. Transfer: keep Hngh's role/sense/bean
  decomposition composable; the "SDK shape" (compose primitives) beats a
  fixed pipeline.
- **Agentless** (SWE-bench): the strongest simple baseline is a clean
  **localize → repair → patch-validation** three-phase, *without* an agent
  looping — often beats complex agents because each phase is well-defined and
  validated. Transfer: make Hngh's phases explicit + independently verifiable
  (localize the fault, propose a minimal repair, validate the minimal patch),
  and only reach for agentic looping when the simple phases underperform.
- **Claude Code hooks** (PreToolUse/PostToolUse/Stop): deterministic hook
  points around every tool call allow policy enforcement (block/allow/edit).
  This is the *mechanism* for the governance guardrails in §3 and the least-
  agency tool scoping in §4 — a pre-use hook can veto a dangerous call with no
  model involved.

### Self-healing systems (survey arxiv 2504.20093 + production practice)

- The mature recipe: **detect → isolate → repair → verify**, with repair
  triggered by *failed verification* (test/health signals), not by time.
- Repair must be **minimal and reverting-aware**: patch the smallest unit,
  keep the failing test as the regression guard, and be ready to roll back on
  any new breakage. Matches Hngh's git-backed rollback (dispatch-tree §3).
- Best practice: don't auto-apply self-repair to unseen code; gate by
  "repairs are cheap to verify" (small, well-tested, reversible). Cost gate is
  the primary distinguisher between useful self-healing and a runaway bill.

### Reflexion / self-debugging (established)

- Self-debugging agents that feed their own test failures + tracebacks back
  into the next attempt measurably improve pass rates; the value concentrates
  when the model can *see the actual error*, so Hngh's runner must surface
  real tracebacks to agents that already fix bugs (the probe/perf work shows
  Hngh's agents already do this).
- **Reflexion** (arxiv 2303.11366): after a failed trial, the agent writes a
  *verbal reflection* on what went wrong + why, stores it in episodic memory,
  feeds it into the next trial — 91% pass@1 HumanEval (vs 80% GPT-4). This is
  exactly "squad tests and regenerates fix" with a mandatory reflection
  artifact between attempts. Map: squad writes "what failed, why, what I'll
  change" into OptMem/dispatch tree before the next attempt.
- **Self-Debugging** (arxiv 2304.05128): iterate until tests pass or max
  turns, feeding execution results back (up to +12%); **reusing failed
  predictions makes the loop sample-efficient** — one generation + K cheap
  repair turns, not N fresh generations.

### Verified cross-system mechanics worth copying (full report §1–§3)

- **Codex agent loop**: context grows every turn (hundreds of tool calls/turn
  can exhaust the window) — context-window management is a first-class harness
  responsibility; an explicit `update_plan` tool keeps a plan artifact
  mid-task; auto-compact preserves a latent summary on exceed.
- **SWE-agent ACI**: curated command set, not a raw shell; **malformed
  generations trigger an error response and all but the first error message
  are omitted from context** (anti-bloat); invalid edits discarded → retry
  told; +10.7% over same model with a default shell.
- **Claude Code containment**: per-action approval gates fail from **approval
  fatigue** (~93% auto-approved); a model classifier catches ~83% of overeager
  behaviors blocking only ~0.4% benign (≈17% of risky actions still slip —
  defense-in-depth, not a guarantee). Consequence for Hngh: **contain at the
  environment/sandbox + deterministic hook layer first**, model-layer steering
  second. Hooks (`PreToolUse`/`PostToolUse`/...) are the directly
  transplantable mechanic — **exit-code 2 from a hook = block/deny**; the cost
  gate belongs in a PreToolUse hook.
- **OpenHands**: event-sourced state with deterministic replay (audit + rerun),
  immutable agent config, typed tools w/ MCP — "negligible event-sourcing
  overhead." Hngh's beans/event-bus log is the same shape; make squad runs
  replayable deterministically (fixed seeds, pinned model+config) so a fix
  that passes is reproducible before touching the trunk.
- **Agentless** (arxiv 2407.01489): a *fixed* localize→repair→validate
  pipeline beat open-source agent frameworks on SWE-bench Lite (32% @ $0.70)
  at the time; **localization is where accuracy lives and it's cheap**;
  verifier = generated reproduction test + regression suite makes sampling
  viable; returns plateaued ~40 patch samples. (Number is the paper's 2024
  claim — the architecture lesson stands, the figure is dated.)
- **aider**: tree-sitter **repo map** (model sees structure, not whole files) +
  **architect/editor split** (strong planner model + cheap editor model = lower
  session cost) + atomic message-committed git commits.
- **MetaGPT** (arxiv 2308.00352): SOP "assembly line" with **structured
  intermediate artifacts** as the interface between stages — the deterministic
  spine that makes failures attributable to a stage.

### Pitfalls to engineer against (full report §4 — high value)

- **Runaway retry loops**: an agent re-fixes a failing test, sees a different
  timestamp in the error, reads it as "progress," loops forever. Counter-
  measures: hard step counts, per-run/per-week budget caps with circuit
  breakers, "no progress = escalate" (same failing test N times → stop), and
  **reflection-artifact diffs** (trial k+1's plan textually near-identical to
  trial k's → it's looping).
- **Regressions**: the only reliable guard is a verifier richer than "target
  test passes" — run the **pre-existing suite (PASS_TO_PASS)** and reject
  patches that break it (Agentless's regression filtering; self-healing
  prototype's revert-up-to-3-then-escalate). Never accept "target test green"
  as completion.
- **Context overflow**: compact/summarize old turns, keep the ACI terse,
  feed structure/skeletons not whole files, make reflection text the
  *compressed* artifact that survives across trials.
- **Approval fatigue**: a human gate with per-action approvals degrades
  (93% auto-approve); deterministic policy hooks (deny-list, cost gate,
  sandbox) beat probabilistic supervision.

### What transfers to Hngh (the executable seed, fullest form)

1. **The loop is the product** — C6 owns test→run→repair→re-run, bounded by
   the cost gate; `generate-pm-prompt` + squad dispatch feed it.
2. **Cost gate = PreToolUse hook** — gate every tool call + model query on the
   weekly budget *before* execution, checked in the harness, never the prompt;
   add per-task step-cap + per-task token budget as independent circuit
   breakers (the AutoGPT loop pathology: an agent reading a changing timestamp
   as "progress" and looping forever).
3. **Verifier richer than "target test passes"** — regression suite + generated
   reproduction test, accept only all-green, revert-and-regenerate with a
   Reflexion artifact on failure; cap attempts ~3–5/sub-task, explicit
   escalate path.
4. **Planner = localization stage** — C6's real job is narrowing the edit
   surface (files→functions→lines in Hngh's own tree) before dispatching,
   keeping squad context small and cost low.
5. **Structured artifact hand-off** between stages (planner spec → squad
   tests+patch+reflection → verifier pass/fail) — no free-form chatter; the
   ACI / beans are the interface.
6. **Keep failed predictions** — reuse failed patch + test output as the next
   attempt's seed (sample efficiency), don't regenerate from scratch.
7. **Event-sourced + replayable** — deterministic squad runs (fixed seeds,
   pinned model/config) so a fix that passes is reproducible before trunk.
8. **When Hngh modifies Hngh**: test-first only — write failing test → squad
   makes it pass → full suite → only then merge to the git-backed dispatch
   tree, with the harness's own budget gate guarding the loop that guards the
   loop.
9. **Surfaces matter as much as models** — the ACI (dispatch tree, beans,
   tool hub, sense events) is a first-class lever to keep polishing; keep the
   tool surface and error-feedback formatting terse and deliberate.

*(Self-development thread fully folded from the 26-source subagent report:
SWE-agent ACI, Codex agent loop, Claude containment + hooks, OpenHands
event-sourcing, Agentless, Reflexion, self-debugging, aider, MetaGPT, GPT-
Engineer, and the §4 pitfalls — runaway loops, regression guards, context
overflow, approval fatigue.)*

---

## 2. Multi-agent memory & coordination (research: partially done by orchestrator)

### The taxonomy confirms Hngh's design (verified 2026-08-07)

The agent-memory field has converged (over 2025–26, incl. a 218-paper survey
arXiv:2602.06052 and production reference systems Letta/MemGPT, Mem0, Zep/
Graphiti) on a three-tier long-term taxonomy that maps almost 1:1 onto what
Hngh already built:

| Taxonomy (field) | Hngh equivalent | Where |
|---|---|---|
| **Episodic** — past interaction/task records | squad journals, husks, `journal/*.md`, git history | dispatch-tree `/journal`, beans husk |
| **Semantic** — declarative facts, domain knowledge | AGENTS.md, OptMem, knowledge-base, design docs | shared memory |
| **Procedural** — learned task patterns | Hngh skills, prompt matrix skeletons, "how we do X" | skills/, prompt-matrix.md |
| **Working/short-term** — current context | dispatch tree state, inbox, current wave | per-role inbox/tasks |

Critical confirmation: **working + archival (Letta/MemGPT page-in/out)** — a
small working context plus a large external store, with a manager that pages
episodes in/out. Hngh's `squad-metabolism` (avatar `:endurance` = context
window, episodic husks paged via git) already encodes this. No architectural
change needed; the taxonomy validates the current shape.

### Additions worth adopting

1. **Provenance on episodic/semantic facts** (Letta/Graphiti + Atlan):
   record *event time* (when true in the world), *ingestion time* (when the
   agent observed it), and *whether the source was authorized to assert it*.
   This is both a correctness and a security property — ties directly to
   §4 (an injected model output that "remembers" a false fact must carry the
   provenance that it was unauthorized). Hngh journal entries should carry
   author + timestamp + source-authority.
2. **Memory-aware planning** (case-based reasoning from episodic memory): at
   planning time, retrieve the K most similar past tasks, review outcomes,
   generate a plan that repeats successes and avoids documented failure
   modes. This is a cheap, high-value addition to the C6 planner — the husks
   are already the dataset; add a "learn from past husks" pass.
3. **Bitemporal / stale-fact handling**: the survey flags that vector memory
   returns stale facts with high confidence (the net-revenue example) until
   manually corrected. File/git + explicit timestamps (Hngh's model) avoids
   the embedding-staleness trap — keep it, don't drift toward blind vector
   stores.

### Shared vs individual perception (Hngh current + confirmation)

Hngh already models this explicitly (squad-metabolism §3 sense taxonomy and
per-role defaults; squad-startup-automation §4 sense layers). The external
research reinforces the two properties to preserve:
- **Single-writer per path** (PM owns dispatch.md; each role owns its outbox)
  — the concurrency lesson from blackboard/event systems; Hngh's dispatch
  tree already enforces it.
- **Provenance marking on all tool/model output** (see §§4, 6) so the shared
  senses can't be silently poisoned.

(to fill — supervisor/hierarchical vs flat/peer coordination patterns from
AutoGen/CrewAI/LangGraph/MetaGPT and feedback/review loop patterns, from
delegated research.)

### Coordination topologies (research COMPLETE — delegated subagent, 29KB report)

Full report: `research-multi-agent-coordination-patterns.md` (in the
workspace). Updated synthesis:

**The single most load-bearing finding: Hngh's PM ≈ Magentic-One's
Orchestrator, and the two-ledger discipline is the missing piece.** Magentic-
One (arxiv 2411.04468) runs an outer loop (durable **Task Ledger**: facts,
guesses, plan) + inner loop (transient **Progress Ledger**: per-step self-
reflection), and re-plans when progress stalls (>2 stall → new plan).
Hngh's git tree + OptMem gives the durable shared state; what's missing is an
explicit *progress-reflection step per task* and stall-triggered re-planning
— instead of CrewAI-style unbounded delegation chains (a documented failure
mode: "endless loop, never reaching a proper end state").

**Topology guidance (mapped to Hngh):**
- **Hierarchical/supervisor wins** for dynamic planning + capability routing
  (LangGraph supervisor, AutoGen GroupChat manager, MetaGPT waterfall SOP).
  Hngh's PM-led design is validated; keep it.
- **Avoid fixed-member distraction**: Magentic-One notes unused agents degrade
  orchestrator focus — route by *task-need*, don't force all 6 roles onto
  every task. (Directly qualifies the "every role on every wave" tendency.)
- **Heterogeneous models per role** is explicitly recommended (strong/cheap
  orchestrator, cheap workers) — Hngh's model-pareto routing already matches.
- **Planner-to-worker / code-orchestrated** (OpenAI Agents SDK) is cheapest
  and most auditable when the pipeline shape is known — use it for the C6
  loop's phases; reserve agentic handoffs for genuinely dynamic spots.

**Task decomposition & aggregation:**
- **MetaGPT's lesson**: structured intermediate artifacts (schema'd documents)
  are "the key to increasing final-code success rate" — every bean/artifact
  should carry a fixed schema, one artifact per task, next agent's prompt
  built from it. Hngh task files already do this; make it the rule.
- **Avoid over-fragmentation — hard cost evidence**: multi-agent systems
  incur **4–220× token consumption** vs single-agent; a single-agent pipeline
  matched quality at **86% fewer tokens, ~2× speed** (arxiv 2505.18286).
  Hngh should keep tasks at "one reviewable artifact" granularity and treat
  "task count × fixed overhead" as an explicit cost term; cap concurrent
  workers (fan-out multiplies spend N×).
- **Aggregate by re-reading state, not chat**: LangGraph reducers (declared
  commutative merge), CrewAI typed `expected_output`, Magentic-One ledger re-
  read. Hngh's git tree + artifact dir is already the reducer.
- **Explicit dependency edges between tasks** (CrewAI `context=`) so the PM
  doesn't re-describe inputs in every file.

**Shared perception/communication (file-system channel discipline):**
Hngh already has the right hybrid (event bus + inboxes = MetaGPT subscription;
OptMem = blackboard; git = write-ahead log + conflict detector + audit trail).
Adopt LangGraph's typed-state rules as file rules:
- **Single-writer per path** (each subtree one owning role) — the file analog
  of `LastValue` (concurrent write = error). Hngh's CLAIM gate + verifier-
  only `.done/` already encode it; extend to every path prefix.
- **Append-only for shared logs** (OptMem signposts, beans, git) — appends
  commute, updates don't.
- **Declared merge for fan-in** (namespaced artifact files + a PM-written
  index), never two agents editing one file.
- **Correlation ID through every bean** (task-id) for cross-hop tracing.

**Review/verification loops:**
- **Review verdict = control flow** (AutoGen: reviewer message is the
  termination trigger). Hngh's verifier-only `.done/` already matches —
  formalize that the verifier's verdict is the *only* legal state-transition
  input, bounded retries (CrewAI `guardrail_max_retries=3` → Hngh max 3
  verify-fail loops then escalate).
- **Checkpoint-before-consequence HITL** (LangGraph `interrupt()` + check-
  pointer): Hngh owner-gated tasks already have this; add the *correction*
  affordance (owner edits task file / injects context bean, then resume =
  LangGraph `update_state`).
- **Sandbox = half the job is output sanitation**: the verified trap is
  return-value poisoning — code returns output to the agent, so *sanitize and
  truncate all tool/artifact output before it re-enters context* (control
  chars, size caps). Cap + timebox every verification command; per-worker
  write boundary; fail closed (UNKNOWN ≠ pass).

**Runaway/context-overflow controls — the single most repeated lesson:**
**hard caps enforced by the runtime, not the prompt.** Verified defaults to
adopt as Hngh config: LangGraph `recursion_limit=1000` super-steps +
`GRAPH_RECURSION_LIMIT` (catchable fail-closed); OpenAI `max_turns` default
10; Magentic-One `max_round_count=10, max_stall_count=3, max_reset_count=2`;
CrewAI `guardrail_max_retries=3`. **Stall detection ≠ liveness** — heartbeat
is activity; a task whose state hasn't *advanced* after N heartbeats is
stalled, re-plan regardless of liveness. Context = subscription + compression
(OptMem's 280-byte cap is exactly MetaGPT's per-agent curation); wire the
context-pressure sense to the same stall logic. **Cost gate as a first-class
termination condition** (per-task token budget checked by Accountant/dispatch;
exceed → fail closed, escalate).

### Self-modifying / prompt-transfer risk (coordination + security converge)

**Structural in Hngh**: one agent's output becomes the next agent's prompt
via beans/artifacts — this is inherent. Verified mitigations:
- Treat **every bean and every file read from the dispatch tree as untrusted
  data, not instructions**.
- **Write-time tagging**: every note/artifact signed with agent+model+route
  (Hngh convention) upgraded to explicit "untrusted unless verified".
- **Sanitize at the executor boundary** (truncate + control-strip test logs /
  tool output before including in any context) = Hngh's AutoGen-7420 lesson.
- **Memory poisoning via OptMem is demonstrated, not theoretical** (Unit 42 /
  Forcepoint persistent-memory-poisoning): durable shared memory is the
  biggest attack surface. Mitigations that fit: append-only + signatures
  (already), owner-audited culling (already), and **human review of anything
  that changes long-lived policy memory** (AGENTS.md, role charters) — HITL-
  gated files, never agent-rewritable without owner approval. (Reinforces §4
  MUST-HAVE 1: immutable policy layer.)
- **Evidence-first verification of all claims** (already Hngh rule): a
  poisoned memo claim must fail the file-exists check before it steers anyone.

---

## 3. Clean-architecture self-modification (research: partially done by orchestrator)

### The core principle: guardrails are deterministic, not advisory

Docs/skills/agentic-reviews are *guidelines* (soft, costly, ignorable).
Guardrails for verified autonomous edits must be **deterministic fitness
functions** — executable checks the agent can't talk its way out of, run on
every self-generated diff. Sources: codesai "Guardrails for AI-Generated
Code", maintainable.software "Agentic Engineering Part 3", Building
Evolutionary Architectures (Ford et al).

### Concretely enforceable rules (Hngh-adaptable)

For a Common Lisp plugin-based image, the minimal structural guardrail set,
each an automated test:

1. **Domain must not depend on infrastructure** (dependency rule of
   ports-and-adapters / hexagonal). In Hngh: core (`src/core/`) must not
   reference plugins; plugins depend inward on core interfaces.
2. **No circular dependencies** between components.
3. **Production code must not depend on test code** (and tests only exercise
   public/stable interfaces).
4. Packaging/naming conventions as structural properties.
5. A **plugin-registration contract**: a change can only add/modify a plugin
   behind the plugin host boundary, never the core host.

Enforcement in Lisp: an ASDF/compile-time or a test-suite structural check
using `find-symbol`, package-level `use-package` inspection, and dependency
graph over `hngh.asd` component lists. Cheap, deterministic, no LLM — same
spirit as Hngh's existing precondition gates (squad-startup-automation §2).

### The guardrail gate in the self-dev loop

The C6 planner's implementation wave should run: **fitness functions →
unit/regression tests → verification** before a self-generated change lands.
If the structural tests fail, the change is rejected and regenerated — an
objective, low-cost signal the agent can act on (the "agent catches an
architectural error → regenerates" pattern documented in the agentic-guardrail
sources). This is distinct from asking the model to self-review (expensive,
unreliable).

### Mutation testing as a diff-quality signal (verified)

- Mutation testing: inject deliberate faults ("mutants"); a test that fails on
  a mutant is *protective*; a mutant that survives means a gap. Meta (2025)
  released research on **LLM-powered mutation-guided test generation** for
  mutation testing at scale; Facebook Engineering published a follow-up
  (2025-09) framing LLMs as "the key to mutation testing".
- For Hngh's autonomous loop: before promoting a self-generated patch, run a
  **small mutation pass on the touched code** — surviving mutants on the new
  code indicate the agent's own tests are shallow. Kill them by asking the
  agent to add the missing assertions, or reject. This gives verification
  depth that plain "tests pass" cannot.
- Practical caution: full mutation testing is expensive/notoriously hard to
  scale (Meta's point). Use it as a *focused* gate on newly-added generated
  code only, not the whole suite.

### TDD drive for autonomous generation

Spec-first, RED-GREEN-REFACTOR: the planner decomposes a roadmap item into
testable units, the squad writes the failing test (RED), implements minimally
(GREEN), then refactors against the fitness functions (REFACTOR). The fitness
functions + regression suite are the loop's objective completion criterion —
matching the "complete design is the target, not the constraint" principle in
squad-metabolism §6 (design may change, but the *architecture rules* are
immutable).

---

## 4. Security & takeover resistance (research COMPLETE — delegated subagent)

Full report: `AGENTIC_AI_SECURITY_RESEARCH.md` (in the workspace; 27KB, all
claims sourced). Highlights and the Hngh-specific bottom line:

### OWASP Top 10 for Agentic Applications 2026 (ASI01–ASI10)

1 Agent Goal Hijack · 2 Tool Misuse · 3 Identity & Privilege Abuse ·
4 Agentic Supply Chain · 5 Unexpected Code Execution (RCE) · 6 Memory &
Context Poisoning · 7 Insecure Inter-Agent Communication · 8 Cascading
Failures · 9 Human-Agent Trust Exploitation · 10 Rogue Agents.
Framing shift: **least privilege → least agency** (restrict not just what a
tool can access but what the agent may *do* with it, how often, where).

### The three pillars to internalize (CIA-Triple-A)

Subagent's honest note: "CIA-Triple-A" as a *named* framework is **not
findable** in public sources — treat as an internal label, but all three
pillars are real, well-sourced:
- **Context integrity** (≈ ASI06): authentic, fresh, unpoisoned context;
  IFC (arxiv 2505.23643) + spotlighting (arxiv 2403.14720) enforce at data
  level; embedding-space poisoning is the threat.
- **Agent identity** (≈ ASI03/10): cryptographically rooted, verifiable
  per-agent identity; attribution of actions; CSA AIGF for lifecycle.
- **Action accounting** (audit axis): append-only, tamper-evident log
  linking each action to originating prompt + identity + policy + human
  approver. This is the enabler of post-incident attribution.

### MUST-HAVE hardening for Hngh (from §MUST-HAVE list; all sourced)

1. **Immutable safety/policy layer** — agent code can never modify its own
   approval policy, sentry rules, sandbox config, or threat-detection config
   (hash-verified, separate process/user). JAWS-Bench shows code agents are
   1.6× *more* vulnerable than base LLMs and 27–32% of accepted attacks
   produced runnable malicious code — direct for a self-modifying Hngh.
2. **Human gate on privileged actions** — extend the `:operation` class to
   dependency installs, core-file commits, cross-instance actions.
3. **Peer auth + encrypted integrity-checked messaging** — mTLS or
   OAuth 2.1/OIDC, signed messages with freshness checks (A2A + MCP both
   require; MCP remote = OAuth 2.1 + PKCE).
4. **Short-lived least-privilege credentials** — no static secrets on agents;
   dynamic, expiring, revocable-on-compromise.
5. **Least-agency tool scoping** — read-only defaults; no send/destructive
   tools unless explicitly granted.
6. **Untrusted-content isolation** — every tool output / retrieved doc /
   web fetch / inter-instance message tagged + quarantined as *data*, never
   fed to planning as instruction (spotlighting + IFC).
7. **Output-side exfiltration guards** — extend sentry regex guards to all
   egress + **canary tokens** planted in context with output scanning.
8. **Execution sandboxing** for agent-generated code — default-deny FS/net,
   per-task sandbox.
9. **Pinned, hash-verified, allowlisted deps** — new deps = human-approved
   `:operation`; OSV scan (this is the slopsquatting defense: Endor Labs
   shows agents hallucinate plausible names for attackers to pre-register).
10. **Action accounting** — append-only tamper-evident logs.
11. **Per-instance quarantine + revocation** — rogue instance can't poison
    peers (ASI07/08/10, prompt-transfer Morris-II worm).
12. **Resource/rate limits** on tools and inter-instance traffic.

### Direct mapping to Hngh today

Already present: sentry regex guards (output-side, item 7 partial), threat-
detection L1/L3 procedural + L2/L4 LLM layers, `:operation` human-gate class,
model-runtime resource gating. Immediate gaps to close before networking:
immutable policy layer (item 1), least-agency tool scoping (5), untrusted-
content tagging/provenance on tool+model output (6), canaries (7), sandboxing
(8), allowlisted/pinned deps (9), append-only action log (10). See §7
roadmap implications for the hardened baseline wave.

Nice-to-haves (as the workforce scales): SLSA+SBOM, full IFC, agent-identity
registry, narrowly-scoped critic agents, prompt-shields classifiers, JAWS-
Bench-style jailbreak eval per release.

---

## 5. Cheap inference & cost control (research: partially done by orchestrator)

### Local serving on RX 7900 XT 24GB (8B-35B) — verified c. 2026-08-07

Grounded from side-by-side benchmarks on 24GB GPUs (RTX 3090 home-lab,
Red Hat, d-central.tech):

- **Concurrency is the decisive difference.** vLLM's continuous batching
  scales aggregate throughput 3.9–5.4x from concurrency 1→8; llama.cpp only
  1.2–1.9x (it pre-declares fixed KV-cache slots at server start, so
  concurrency is a *config decision*, not runtime). At c8 vLLM beat
  llama.cpp 2.9–3.7x and beat Ollama's serialized default 6.3–16.4x.
- **Rule of thumb VRAM**: ~0.6 GB per B params at Q4_K_M → 24GB holds up to
  ~34B, well past the 35B ceiling for the models we run (Qwen3-Coder-30B-A3B,
  Gemma 4 26B-A4B fit comfortably at Q4).
- **vLLM OOMs on RAM-spill; llama.cpp/Ollama degrade to single-digit tok/s**
  instead. So: pick a model that *fits*, don't rely on CPU offload for
  serving. (Hngh's model-runtime should enforce "fits or refuse", not spill.)
- **AMD ROCm**: vLLM supports AMD GPUs (the 7900 XT) but setup floor is
  higher; llama.cpp/Ollama are turnkey on ROCm. Practical split for Hngh:
  - **llama.cpp/ollama** = default local engine (simplicity, ROCm turnkey,
    single/concurrent user up to small squad).
  - **vLLM** = when multiple squad roles need concurrent serving on the same
    GPU (batch scheduling wins), and for speculative decoding acceleration.
  - Keep **Unsloth** as the fine-tune/train substrate (it can serve, but the
    tuned model is better exported/served by vLLM or llama.cpp).

### Quantization for coding models

- GGUF Q4_K_M is the practical default (0.6GB/B, preserves coding ability);
  Q8 costs ~2x VRAM for marginal quality. AWQ/GPTQ/FP8/INT4 also supported by
  vLLM. Modern 4-bit keeps near-full accuracy on coding/reasoning (DeepSeek
  FP8/INT8 benchmarks near-perfect).

### Speculative decoding — the "free" speedup (verified)

- Multi-fold latency win on supported hardware. Two practical vLLM paths for
  consumer GPU:
  - **Draft model** (small same-family, same-tokenizer helper) — works, but
    costs extra VRAM (whole second model).
  - **MLP speculator / Medusa / EAGLE head** — prediction quality of a draft
    model without the *memory* cost of loading a second LLM. Best fit for
    the 24GB card. EAGLE/MTP/Medusa give best latency reduction; n-gram/
    suffix are lighter, no extra model.
- Sodality for Hngh: enable a cheap speculator on the biggest served model;
  measure tok/s with the probe suite (benchmark-sourcing section 3.1) to
  confirm gains before adopting.

### Remote cheap-model + routing + budget architecture (verified c. 2026-08-07)

Existing Hngh substrate: model-routing.md (LiteLLM single-proxy pattern),
model-pareto.md (Pareto frontier per role), llm-budget sidecar, OpenRouter
weekly ~$48 cap, DeepSeek direct-API delegation default.

Decision-grade price/capability data (mid-2026, from provider pricing + two
independent routing cost studies) — all per 1M tokens, input/output:

| Model | Input | Output | Cache hit (input) | SWE-bench Verified | Notes |
|---|---|---|---|---|---|
| DeepSeek V4 Flash | $0.14 | $0.28 | ~$0.0036 (≈40x) | 52.6 (Pro variant 79–80.6) | price floor, 1M ctx |
| DeepSeek V4 Pro | $0.435 | $0.87 | ~$0.0036 | 80.6 (Pro-Max) / 55.4 | best open-weight value |
| Kimi K2.6 | $0.95 | $4.00 | auto caching | 80.2 | 1T/32B active, 256K ctx |
| Qwen 3.6 | $1.30 | $7.80 | — | — | 256K ctx |
| GPT-5.5 / Opus-4.x | $5.00 | $25–30 | 0.1x/90% off | top | ~18–20x the DeepSeek price |

**Key actionable numbers for Hngh:**

- **Running-cost proof of routing**: a real 2,415-turn coding-agent session
  routed across Kimi (82%), GPT-5.5, local Qwen, DeepSeek Flash/Pro, GLM cost
  **$76.77 total**; the same log through GPT-5.5-only was estimated
  **$1,272.77**. The savings come from *not pretending every task is the same
  task* — route by task value, not one model for everything. This validates
  Hngh's per-task policy routing (`:prefer-tool/:local-openai-api` +
  model-pareto assignment) as the correct arc.
- **Value metric to use**: SWE-bench score ÷ cost per M input. DeepSeek Flash
  = 52.6/$0.14 = 375; Opus = 64.3/$5 = 12.9. **Cheap-by-default, expensive-
  only-when-the-task-earns-it** — the single most important routing rule.
- **Cache is the hidden lever**: DeepSeek cache hits ≈ $0.0036/M input
  (~40x cheaper). For Hngh's autonomous loop (which re-sends the same system
  prompt + repo context every turn), cache-aware serving is worth more than
  headline price. Design prompts to hit cache (stable system prompt, stable
  ordering).
- **Free tiers to keep in the chain**: GLM-4.7/4.5-flash free on Z.AI API;
  Qwen/others :free on OpenRouter. Keep the budget-level `:free` fallbacks in
  every role chain (model-routing already does).
- **Thinking/reasoning tokens inflate cost 3–5x** — use thinking level
  *per task class* (low for the cheap/logging/edits route, high only for the
  escalation route), as the routed-session study config shows. Hngh should
  carry a "thinking level" dimension through policy routing.
- **Assignment floor**: below ~52–55 SWE-bench, a cheap model causes rework —
  track **cost per *successful* task**, not cost per token (a cheap model
  that forces a second pass is expensive).

**Cost-control architecture for Hngh** (converged pattern):
1. Single routing proxy (LiteLLM-style or Hngh's own) in front of local +
   remote, with named routes + **per-route budget caps** + fallback chains.
2. Classify each task (cheap/logging/edit vs workhorse vs frontier) locally —
   no hosted router sees the prompt; classification is local and cheap.
3. Track cost-per-successful-task per model/route (probe suite + llm-budget
   ledger as the dataset; C8 benchmark squad scores routes by this, not by
   tokens).
4. Pricing-change alerts: if OpenRouter/DeepSeek change a model price, flag
   the route for re-review (ties to nightly cron C9).

(to fill — final subagent cross-check on any price deltas vs this snapshot.)

---

## 6. Ecosystem integration & peer coordination (research: started by orchestrator)

### MCP (Model Context Protocol) — verified 2026-08-07

- Current spec: **2026-07-28**. Stateless HTTP tool calls; **no handshake or
  sessions** — each call self-describes via `MCP-Protocol-Version` header +
  `Mcp-Method`/`Mcp-Name`. JSON-RPC 2.0 bodies.
- Standard for agent→tool/context. Hngh's own tool hub should speak MCP:
  - **As server**: wrap hngh's tools/plugins as MCP servers so any MCP client
    (Claude, opencode, other agents) can drive them. This is the clean-est
    way to "be used by the ecosystem."
  - **As client**: consume third-party MCP servers as tools added to the tool
    hub (registry of tools, see shared-queue.md v3 "tool and MCP registry").
- **Security angle (ties to §4)**: MCP servers are a prime injection vector —
  every MCP tool's output must carry provenance + be treated as untrusted
  input, and MCP tool grants must be least-privilege. (OWASP agentic treats
  cross-plugin/MCP injection as a named threat.)

### A2A (Agent2Agent) — verified 2026-08-07

- Google, Apr 2025, Apache-2.0, now Linux Foundation. Open protocol for
  *opaque* agent↔agent: an agent can delegate/coordinate with another agent
  without exposing internal state/memory/tools.
- Complements MCP (MCP = agent→tool; A2A = agent→agent).
- **Direct fit for Hngh M3 (The Network)**: Hngh peer instances speaking A2A
  for delegation/coordination; each instance stays opaque. This is the
  consulting-workforce multi-instance story's interoperability layer.
- Adoption lens: outbound (Hngh calls remote agents) + inbound (Hngh as an
  A2A agent served to remote peers), with enterprise-grade auth (must-haves
  before any networking).

### ComfyUI / vLLM / Odysseus etc. (partially verified by orchestrator)

- **ComfyUI is fully scriptable over its API** (verified): POST the workflow
  graph (JSON, from "Save (API format)" / developer mode) to
  `http://127.0.0.1:8188/prompt`, set node inputs (positive/negative text,
  seed, latent size, filename prefix) by mutating node dicts, queue it, poll
  for completion, read output images (base64 or file). This is a clean
  ports-and-adapters plugin: an Hngh `image-gen` tool wraps the ComfyUI API
  behind the tool hub, exactly as `model-runtime` wraps local inference.
- **vLLM** exposes an OpenAI-compatible `/v1/chat/completions` + `/v1/completions`
  API — a drop-in for the existing OpenAI-compatible adapter (Hngh probe
  runner and tool hub already speak this protocol). Enabling it behind
  `model-runtime` is the concurrency win from §5.
- **General principle**: adopt every third-party project as a *plugin adapter*
  behind the tool hub / ports-and-adapters boundary, never tight coupling.
  The tool hub already has a registry (shared-queue.md v3 "tool and MCP
  registry"); each external service becomes one registered tool with a
  declared auth policy and least-privilege grant.

(ecosystem sub-thread on A2A/MCP adoption depth + any remaining open-source
projects — delegating/collecting; fold in when available.)

---

## 7. Roadmap implications

The research telescopes into a small set of concrete, wave-ordered programs
(collapsing to what already exists in M9 C1–C10 + M3). Each is gated by
verification and cost, in keeping with Hngh's zero-further-interview style.

### M9.x line — make the self-dev loop real and governed

**Wave A — C6 planner (roadmap → task → squad → roadmap write-back).**
The keystone (§1). Owns test→run→repair→re-run, bounded by the cost gate.
Precondition: roadmap made current first (it is the planner's input). Adopt
the Agentless 3-phase style (localize → repair → patch-validation) and only
escalate to a looping agent when simple phases underperform. Feed husks back
for memory-aware planning (§2). [C6 design exists in squad-autonomy §8 +
startup-automation W7]

**Wave B — Governance guardrails for self-modification (§3).**
Deterministic fitness functions as tests, not advisory docs: (1) domain
never depends on infra (core must not reference plugins), (2) no circular
deps, (3) production never depends on tests, (4) plugin-registration contract
only. Enforced structurally over `hngh.asd` + package graph. Run in the C6
loop before any self-generated change lands; reject + regenerate on failure.
Focused mutation pass on newly-added generated code as a diff-quality gate.

**Wave C — Hardened security baseline (MUST-HAVE list from §4).**
Immutable safety/policy layer (agent can't edit its own approval policy /
sentry config / sandbox config); least-agency tool scoping; untrusted-content
tagging + provenance on every tool/model output; canary tokens + output scan;
execution sandboxing for agent-generated code; allowlisted/pinned deps as
`:operation`; append-only action log; `:operation` human gate extended to
core-file commits + dependency installs. **Gate: no C6 self-modification of
core files until this wave lands.** [JAWS-Bench: code agents 1.6× more
vulnerable; 27–32% of accepted attacks ran malicious code]

### M9.x line — make the loop data-driven and cheap

**Wave D — Benchmark circuit (C8/C9).** `benchmark-runner` squad strategy +
nightly Hermes cron producing a real dataset (§6 of benchmark-sourcing; probe
runner exists). Score routes/roles by **cost-per-successful-task**, not
tokens; pricing-change alerts flag routes for re-review. Fold in the C4/C10
work already in M9 wave 3.

**Wave E — Cheap-inference rollout (§5).** vLLM for concurrency + speculative
decoding (MLP/EAGLE head fits 24GB), llama.cpp/ollama for turnkey local, keep
Unsloth as train substrate. Remote: DeepSeek-first routing, cache-aware
prompts (≈$0.0036/M cache hits), per-task-class thinking level, free-tier
fallbacks. Route by SWE-bench÷cost value metric; cache is the hidden lever.

### M3 line — interop and fleet (only after Waves A–C)

**Wave F — MCP + A2A adapters (§6).** Hngh tool hub speaks MCP (server: wrap
Hngh tools for any client; client: consume third-party servers as tools).
A2A for agent↔agent peer coordination — *opaque*, so fleet instances delegate
without exposing internals. ComfyUI/vLLM/third-party as plugin adapters behind
the tool hub.

**Wave G — Networked fleet hardening (M3; §4 MUST-HAVEs 3–4, 11).**
mTLS/OAuth 2.1 + OIDC peer auth, short-lived creds, integrity-checked
encrypted messaging, per-instance quarantine + revocation. **Gate: nothing
for this wave until Waves A–C.** [A2A = the interop layer; MCP remote servers
require OAuth 2.1 + PKCE]

### Ordering rule (why)

C6 (A) is the loop; guardrails (B) keep it clean; security (C) keeps it safe;
benchmark/cost (D/E) keep it cheap and data-driven. Then interop (F) and the
fleet (G), which are explicitly gated on A–C being solid. This matches the
research consensus: **the loop is the product, guardrails are deterministic,
security is an immutable boundary, cheap costs come from routing + caching,
and networking is last and gated.**

### Future arc (consulting workforce / broad org needs)

Long-horizon: deployed instances as peers (A2A), fleet-wide cost ledger
(upgrade llm-budget from per-host to shared), per-instance plugin/hardware
surface, learning-from-husks across instances (federated episodic memory with
provenance). Every step rides on the Waves above; none is a prerequisite for
the single-host autonomous loop.

---

## 8. Open questions / to verify

- **CIA-Triple-A naming**: "context integrity, agent identity, action
  accounting" is not a findable *named* framework — treat as an internal label
  over three real, well-sourced pillars (see §4). Fine to keep internally.
- **Cheap-inference price snapshot**: cost table (§5) is mid-2026 provider
  pricing; prices move. Treat as a starting snapshot, re-confirm against live
  catalogs (the fetch-model-benchmarks + probe suite already pull live
  OpenRouter catalog data).
- **vLLM-on-RX-7900-XT specifics**: the concurrency/scaling data is from an
  RTX 3090 (24GB NVIDIA) home-lab. AMD ROCm numbers should be confirmed with
  a local smoke run before committing vLLM as the default local engine; llama
  .cpp/ollama are the safe turnkey fallback meanwhile.
- **Guardrail fitness-function tooling**: §3's structural checks need
  implementing in Lisp (find-symbol/package-graph over hngh.asd); no off-the-
  shelf equivalent — low risk, deterministic, but new code.
- **MCP/A2A adoption depth**: adoption strategy (§6/F) needs a decision on
  which MCP server/client SDK (if any) versus implementing the wire protocol
  directly in Lisp — a scoping decision for the Wave F brief, not settled here.
- **Fleet cost ledger**: whether llm-budget becomes fleet-wide is deferred to
  the M3 wave-G design (matches the existing NET-1 open question).
