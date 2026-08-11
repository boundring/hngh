# Multi-Agent Coordination & Memory Patterns — Research for Hngh

Research date: 2026-08-07 · Agent: Hermes subagent (deepseek-v4-flash) · Scope: production agent frameworks → transfer to Hngh's file+event-bus+git+OptMem system with hard cost gating.

Every claim below is tied to a cited source. Where a specific number or behavior was not verified, it is marked UNKNOWN rather than invented.

---

## 1. Orchestration Topologies

### 1.1 Supervisor / hierarchical (manager + specialist workers)
- **LangGraph supervisor**: a supervisor node reads state, routes to one of several worker nodes via conditional edges; every worker returns to the supervisor, which decides next step or FINISH. Typed `TeamState` is the shared channel. (https://callsphere.ai/blog/langgraph-multi-agent-system-supervisor-worker-patterns)
- **CrewAI hierarchical**: requires `manager_llm` or `manager_agent`; manager oversees planning, delegation, and validation. Two modes: sequential or hierarchical. (https://docs.crewai.com/v1.15.1/en/concepts/processes)
- **AutoGen**: `GroupChat` + `GroupChatManager`; manager selects the next speaker (auto = LLM-decided) and reviews outputs. (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026)
- **MetaGPT**: waterfall SOP — PM → Architect → PM/Project Manager → Engineer → QA; each phase's structured output is the next phase's input. Five fixed roles. (https://arxiv.org/abs/2308.00352, https://note.com/snake_dragon/n/nfaa6f9b9d7a6)
- **Magentic-One**: lead Orchestrator + four *functional* agents (WebSurfer, FileSurfer, Coder, ComputerTerminal). Orchestrator runs two loops: **outer loop** maintains a Task Ledger (facts, guesses, plan); **inner loop** maintains a Progress Ledger, self-reflects on progress each step, and re-plans when progress stalls (stall count > 2 → update ledger → new plan). (https://www.microsoft.com/en-us/research/articles/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/, paper: https://arxiv.org/abs/2411.04468)
- **When it wins**: dynamic planning (sequence unknowable in advance), specialist workers needing capability-based routing, and manager-side review/iterate (Devin/OpenHands-style). (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026)
- **Pitfalls**: CrewAI hierarchical "can produce unpredictable delegation chains on novel inputs" (https://pub.towardsai.net/langgraph-vs-crewai-vs-autogen-which-ai-agent-framework-should-your-enterprise-use-in-2026-3a9ebb407b09) and "sometimes got stuck in an endless loop, never reaching a proper end state" (https://medium.com/@saeedhajebi/multiagent-orchestration-showdown-comparing-crewai-smolagents-and-langgraph-0e169b6a293d). Magentic-One: fixed team membership means unused agents are "a distraction to the Orchestrator" (paper §6.2). Magentic-One deliberately chose **functional/tool-based** responsibilities over human-team role-based ones (paper §4.2).

### 1.2 Flat / peer (group chat, handoffs)
- **AutoGen group chat** = agents as conversation participants; round-robin or selector-driven; a shared chat buffer acts as blackboard. (https://www.zenml.io/blog/langgraph-vs-autogen)
- **OpenAI Swarm** (archived, educational): one agent active at a time; explicit `transfer_to_agent_b()` handoff functions; the active agent hands over the full conversation. (https://github.com/openai/swarm). Its production successor, the **OpenAI Agents SDK**, implements handoffs as a **supervisor primitive**, not a peer swarm (https://www.digitalapplied.com/blog/multi-agent-orchestration-5-patterns-that-work). Handoffs = "triage agent routes to specialist; specialist becomes active agent" (https://openai.github.io/openai-agents-python/multi_agent/).
- **When it wins**: open-ended debate/iteration where no single planner can pre-script the interaction; also "swap instructions without the manager narrating" (https://openai.github.io/openai-agents-python/multi_agent/).
- **Pitfalls**: conversational round-trips are token-expensive — a comparative benchmark shows ~8,000 tokens for an AutoGen conversational run vs ~2,000 for focused LangGraph nodes (https://dev.to/pockit_tools/langgraph-vs-crewai-vs-autogen-the-complete-multi-agent-ai-orchestration-guide-for-2026-2d63 — third-party benchmark, treat as indicative). No built-in convergence guarantee; termination must be explicit (see §5).

### 1.3 Planner-to-worker / code-orchestrated
- **OpenAI Agents SDK**: two documented orchestration styles — (a) *via code*: chain agents by transforming one output into the next input, or run independent agents in parallel with `asyncio.gather`; (b) *via LLM*: handoffs. (https://openai.github.io/openai-agents-python/multi_agent/)
- **LangGraph**: map-reduce fan-out/fan-in with `Send` + reducers; supervisor decomposes. (https://callsphere.ai/blog/langgraph-multi-agent-system-supervisor-worker-patterns)
- **When it wins**: pipeline shape known ahead of time → cheapest and most auditable; parallel when subtasks are independent.

### 1.4 Hngh mapping
- **Hngh PM ≈ Magentic-One Orchestrator.** Adopt the two-ledger discipline verbatim: Task Ledger (facts / guesses / plan — durable, shared) vs Progress Ledger (per-step self-reflection — transient). Hngh's git tree + OptMem already gives durable shared state; the missing piece is an explicit *progress-reflection step per task*, not just status transitions.
- **Adopt Magentic-One's stall-triggered re-planning** instead of unbounded delegation chains (CrewAI's failure mode).
- **Hngh role-based squad is validated by MetaGPT** (role-based works with fixed SOPs + structured outputs), but **avoid fixed-member distraction**: Magentic-One's paper notes unused agents degrade orchestrator focus. Route by *task-need*, not by "every role must touch every task".
- **Heterogeneous models per role** (strong/expensive orchestrator, cheap workers) is explicitly recommended by Magentic-One ("model agnostic... different LLMs and SLMs... meet different cost requirements") — Hngh's model-pareto routing already matches this; keep the PM on a cheap-but-strong model and reserve frontier for critical-path hops.

---

## 2. Task Decomposition & Aggregation

- **MetaGPT**: SOP-encoded waterfall — PRD (user stories, requirement pool) → design docs (file lists, data structures, APIs) → PM decomposes into sequenced tasks with dependencies → Engineer implements per spec → QA writes/runs tests and issues correction instructions. **Structured intermediate artifacts are the key**: forcing concrete documents, not vague prose, "is the key to increasing the success rate of final code generation." (https://note.com/snake_dragon/n/nfaa6f9b9d7a6, https://arxiv.org/abs/2308.00352). PM's task sequencing "reduces rework in subsequent phases."
- **CrewAI**: tasks declare `context=[other_task]` dependencies (sequential) or the manager decomposes at runtime (hierarchical); `expected_output` can be a Pydantic model for typed aggregation (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026, https://docs.crewai.com/v1.15.11/en/concepts/tasks).
- **LangGraph**: fan-out with `Send`, fan-in with **reducers** (`Annotated[list, operator.add]`) — parallel branches write partial results that are merged by a declared, commutative merge function; an aggregator node consumes the merged list. (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026, https://ranjankumar.in/langgraph-reducers-concurrent-state-writes)
- **Magentic-One**: Orchestrator decomposes one step at a time, tracks in Progress Ledger, aggregates by re-reading ledger state (https://arxiv.org/abs/2411.04468).
- **Avoiding over-fragmentation**:
  - Anthropic: "start with the simplest solution... agentic systems often trade latency and cost for better task performance"; most production systems are single-agent or workflow, multi-agent is the last resort, and even their most complex systems use few agents (https://www.anthropic.com/engineering/building-effective-agents).
  - Empirical: "Single-agent or Multi-agent Systems? Why Not Both?" — MAS incurs 4–220× token consumption vs single-agent; a single-agent pipeline matched MAS quality at **86% fewer tokens and ~2× speed** (https://arxiv.org/abs/2505.18286).
  - MetaGPT fixes decomposition depth by *SOP shape* (5 roles, one artifact per phase), which "reduces unproductive collaboration among LLM-based agents" (https://arxiv.org/abs/2308.00352).
- **Aggregation**: LangGraph reducers (declared merge semantics), CrewAI typed expected_output, Magentic-One ledger re-read. Every framework aggregates through *declared state shape*, never free-form chat summarization.

### Hngh mapping
- **Adopt: one artifact per task, structured.** Hngh task files already carry objective/acceptance criteria/constraints — the MetaGPT lesson is that *intermediate artifacts must be schema'd documents* (a bean with a fixed structure), because the next agent's prompt is built from them.
- **Adopt: explicit dependency edges between tasks** (CrewAI `context=`) so the PM doesn't re-describe inputs in every task file.
- **Avoid over-fragmentation**: each task carries fixed overhead (claim note, artifact, verification, memo updates, 280-byte signpost). The 4–220× token study plus per-task overhead means Hngh should **keep tasks at "one reviewable artifact" granularity** and treat "task count × overhead" as an explicit cost term. Fan-out multiplies spend N× — cap concurrent workers (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026: "cost blow-up: fan-out N-way multiplies token spend by N").
- **Aggregate by re-reading state, not by chat** — Hngh's git tree + artifact dir is the reducer; the PM aggregates by reading artifacts, which is already the Magentic-One ledger pattern.

---

## 3. Shared Perception / Communication

- **MetaGPT shared message pool + subscription**: all agents publish to one central pool; no direct inter-agent calls; each agent *subscribes by message type* (engineer ← system design doc; QA ← code). The Environment is a global memory pool agents can search. Trade-off: pool growth raises search cost — subscription keeps each agent's received set relevant. (https://note.com/snake_dragon/n/nfaa6f9b9d7a6, https://arxiv.org/abs/2308.00352)
- **Pub-sub** (event-driven): loose coupling, latency by subscription; needs correlation/trace IDs across hops; **deadlock guards (global hop counters, per-task step caps) must be enforced by the orchestrator, "not trusted to each agent's prompt"** (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026).
- **Blackboard**: shared public space agents read/write; suited to open-ended problems; "when two agents write to the same entry at the same time, you need a clear conflict resolution mechanism" (https://greennode.ai/blog/how-to-design-shared-memory-for-multi-agent-ai; academic treatment: https://arxiv.org/html/2507.01701v1).
- **LangGraph typed state = the consistency rulebook**: every shared key has a declared *channel* with a merge policy. `LastValue` → concurrent write is a **hard error**; reducers (e.g. `operator.add`) must be **commutative** or results are order-coupled; parallel branches either write disjoint keys or reduce through declared functions. (https://ranjankumar.in/langgraph-reducers-concurrent-state-writes, https://gndp.medium.com/does-langgraph-reducer-support-concurrency-380eb8c0b3c1)
- **Shared memory is an attack surface** ("their best coordinator and their biggest attack surface"); write-time tagging was the most useful defense in every tested combination (https://medium.com/@Micheal-Lanham/your-ai-agents-shared-memory-is-their-best-coordinator-and-their-biggest-attack-surface-900f1e5571b1).

### Hngh mapping
- **Hngh already has the right hybrid**: MetaGPT pool (event bus + per-role inboxes = subscription), blackboard (OptMem), and an append-only ordered log (git). The git-backed dispatch tree is Hngh's superpower — it is the *write-ahead log + conflict detector + audit trail* in one.
- **Adopt LangGraph's channel discipline as file rules**:
  - *Single-writer per path*: each subtree has exactly one owning role (coder → source, accountant → ledgers, PM → tasks/, verifier → .done/). This is the file-system analog of `LastValue` (concurrent write = error). Hngh's CLAIM gate + verifier-only `.done/` transitions already encode this — extend it to *every* path prefix.
  - *Append-only for shared logs* (OptMem notes, beans): appends commute; updates don't. Memo = signposts/status, payloads live in files (already Hngh convention).
  - *Reducers for fan-in*: when N workers produce partial results, declare the merge (e.g. `artifacts/<N>-<name>.md` namespacing + a PM-written index) rather than letting two agents edit one file.
  - *Correlation ID through every bean* (task-id) — already in CLAIM notes; propagate it into artifacts and commits for cross-hop tracing.
- **Verify-before-act is mandatory**: Hngh's evidence-first check-ins (cite file/commit/test output beside every claim) match the memory-as-attack-surface literature. Never trust a memo announcement that a file exists — check disk (already pitfall #14 in the coordination skill).

---

## 4. Review / Verification Loops

- **Reflection pattern (LangGraph)**: generate → critique → revise, with a hard iteration cap (`MAX_ITERATIONS = 5`; also `should_continue` on message count). Reflexion variant inserts `execute_tools` between draft and revise (tool-verified critique). Rule of thumb: reflection wins when quality matters more than speed/cost; it is memory-intensive (each iteration grows history). (https://www.langchain.com/blog/reflection-agents, https://adp.xindoo.xyz/original/Chapter%204_%20Reflection/)
- **CrewAI guardrails**: per-task LLM-based or function-based validators on `expected_output`, with `guardrail_max_retries=3` — a failed guardrail loops the task back to the agent, bounded (https://docs.crewai.com/v1.15.11/en/concepts/tasks).
- **AutoGen**: reviewer-agent pattern — a reviewer agent's message ("looks good") is the termination trigger (`is_termination_msg`), i.e. *review verdict = control flow* (https://medium.com/google-cloud/multi-agent-interactions-with-autogen-and-gemini-part-2-terminating-conversations-883788137162). `UserProxyAgent` = human approval gate in the chat (https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/selector-group-chat.html).
- **LangGraph HITL**: `interrupt_before/after` + checkpointer (thread_id) → graph pauses, state saved, `Command(resume=...)` resumes; humans can also `update_state` to *correct* the state, not just approve. "Safety is a graph shape, not an afterthought. The ones that fail are the ones where a bad call had no checkpoint between the decision and the consequence." (https://docs.langchain.com/oss/python/langchain/human-in-the-loop, https://pub.towardsai.net/langgraph-human-in-the-loop-pausing-reviewing-and-rewinding-your-agent-4028bd05b049)
- **OpenAI Agents SDK**: input/output/tool guardrails as first-class; a tripped guardrail raises `OutputGuardrailTripwireTriggered` (fails the run closed); guardrails can reject tool input (secrets) and redact tool output (https://openai.github.io/openai-agents-python/guardrails/).
- **Sandboxed verification**:
  - AutoGen: `DockerCommandLineCodeExecutor` (image, timeout, work_dir, auto_remove) vs `LocalCommandLineCodeExecutor(timeout=10, work_dir=temp)`; `human_input_mode="ALWAYS"` as a safety posture (https://microsoft.github.io/autogen/0.2/docs/tutorial/code-executors/).
  - E2B/dev + AutoGen maintainers: container isolation is incomplete (shared kernel, default capability surface); WASM capability models start with zero ambient authority. **Two verified traps**: (1) **return-value poisoning** — "the sandbox can prevent unauthorized actions, but the code still returns output to the agent... sanitizing the output is the other half"; (2) resource exhaustion — need explicit CPU/time metering; plus mount-point pivots. (https://github.com/microsoft/autogen/discussions/7420, https://e2b.dev/blog/microsoft-s-autogen)
- **Failing closed**: termination conditions are *composed* (`TextMentionTermination | MaxMessageTermination`), so no single failure path runs forever (https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/selector-group-chat.html); Magentic-One re-plans on stall and the Microsoft Agent Framework exposes explicit knobs `max_round_count=10, max_stall_count=3, max_reset_count=2` (https://learn.microsoft.com/en-us/agent-framework/workflows/orchestrations/magentic).

### Hngh mapping
- **Adopt the AutoGen rule: review verdict = control flow.** Hngh already has named-verifier-only `.done/` transitions — formalize that the verifier's verdict (pass/fail/UNKNOWN) is the *only* legal state transition input, and bound retries (CrewAI's `guardrail_max_retries` → Hngh: max 3 verify-fail loops, then escalate to PM/owner).
- **Adopt checkpoint-before-consequence HITL**: Hngh's "blocked = owner-gated" tasks are exactly LangGraph `interrupt()`; add the *correction* affordance (owner can edit the task file / inject a context bean, then resume) — that is LangGraph `update_state`.
- **Sandbox substitute**: workers already get write-boundaries (artifacts/ only) — the verified lesson is to treat *output sanitation as half the job*: cap and strip artifact content (size limits, control chars) before it re-enters any agent's context.
- **Fail-closed discipline**: a verifier that cannot confirm (UNKNOWN) must leave the task pending — never auto-pass. This matches Hngh's evidence-first rules and CrewAI's guardrail-retry shape.

---

## 5. Feedback Loops Preventing Runaways / Context Overflow

- **Hard caps, enforced by the runtime, not the prompt** (the single most repeated lesson):
  - AutoGen: `max_round` / `MaxMessageTermination` (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026, https://microsoft.github.io/autogen/stable/user-guide/agentchat-user-guide/selector-group-chat.html)
  - OpenAI Agents SDK: `Runner.run(..., max_turns=...)`, default `DEFAULT_MAX_TURNS` (10); JS docs: "Safety limit – throws MaxTurnsExceededError when reached" (https://openai.github.io/openai-agents-python/ref/run/, https://openai.github.io/openai-agents-js/guides/running-agents/)
  - LangGraph: `recursion_limit` config (default 1000 super-steps since 1.0.6); `GRAPH_RECURSION_LIMIT` error is a documented, catchable fail-closed path; `RemainingSteps` managed value lets nodes degrade gracefully near the limit (https://docs.langchain.com/oss/python/langgraph/graph-api, https://docs.langchain.com/oss/python/langgraph/errors/GRAPH_RECURSION_LIMIT)
  - Reflection: `MAX_ITERATIONS` (https://www.langchain.com/blog/reflection-agents)
  - Magentic-One: stall count > 2 → re-plan; Microsoft's builder exposes max_round/max_stall/max_reset (https://learn.microsoft.com/en-us/agent-framework/workflows/orchestrations/magentic)
  - Generic: "Global hop counters and per-task step caps are enforced at the orchestrator, not trusted to each agent's prompt" (https://rapidclaw.dev/blog/multi-agent-orchestration-patterns-2026)
- **Stall detection ≠ loop detection**: Magentic-One's inner loop checks "Progress being made?" every step — *progress*, not activity, is the signal; repeated no-progress → re-plan or fail (https://www.microsoft.com/en-us/research/articles/magentic-one-a-generalist-multi-agent-system-for-solving-complex-tasks/).
- **Context overflow**: AutoGen's context-overflow handling was a *roadmap item / open problem*, not a solved feature (https://github.com/microsoft/autogen/issues/156). Community approach: explicit summarizer/truncation passes or handing the last message to a summarizer agent (https://www.reddit.com/r/AutoGenAI/comments/1feb573/autogen_groupchat_not_giving_proper_chat_history/). Tool-output overflow is a documented agent-failure class with reproducible demos (https://dev.to/aws/ai-context-window-overflow-memory-pointer-fix-3akc). MetaGPT bounds per-agent context by *subscription* (agents retrieve only relevant historical messages — "each agent proactively curates personalized knowledge by retrieving relevant historical messages") (https://arxiv.org/abs/2308.00352).
- **Cost as a feedback signal**: comparative benchmarks show conversational orchestration costs multiples of focused-node orchestration (https://dev.to/pockit_tools/langgraph-vs-crewai-vs-autogen-the-complete-multi-agent-ai-orchestration-guide-for-2026-2d63); MAS token blow-up is 4–220× (https://arxiv.org/abs/2505.18286).

### Hngh mapping
- **Adopt explicit numeric caps as config, enforced by dispatch code** (not prompts): per-task max rounds (e.g. 10), max stall count (e.g. 3 → re-plan by PM), max resets (e.g. 2 → fail to owner). Magentic-One's exact knobs are the template.
- **Adopt progress-signal stalls**: heartbeat (already a Hngh sense) is activity; add a *progress* check — a task whose state file hasn't advanced after N heartbeats is stalled, regardless of liveness.
- **Context management = subscription + compression**: OptMem's mandatory compression (280-byte notes, `memo nap`) is exactly MetaGPT's per-agent curation; keep it mandatory. Context-pressure sense already exists in Hngh — wire it to the same stall logic.
- **Cost gate as first-class termination condition**: a per-task token budget checked by the Accountant/dispatch layer is the Hngh-native equivalent of `MaxMessageTermination`; a task that exceeds budget must fail-closed (escalate), not silently continue.

---

## 6. Self-Modifying Systems / Prompt-Transfer Risk

- **Indirect prompt injection via shared memory is demonstrated, not theoretical**:
  - Unit 42 PoC: adversaries use indirect prompt injection to *silently poison the long-term memory* of an agent; poisoned entries persist and influence later, unrelated sessions (https://unit42.paloaltonetworks.com/indirect-prompt-injection-poisons-ai-longterm-memory/)
  - Forcepoint: "persistent memory poisoning" — victim never sees the malicious instruction; the compromise survives across sessions (https://www.forcepoint.com/blog/x-labs/persistent-memory-poisoning-ai-agents)
  - Survey: memory poisoning is a distinct attack class from classic prompt injection; injected context gets trusted because it arrives via the "memory" channel (https://arxiv.org/html/2506.23260v2, https://christian-schneider.net/blog/persistent-memory-poisoning-in-ai-agents/)
  - Context poisoning: web/file agents "mix trusted and untrusted data" and act on it directly (https://redis.io/blog/context-poisoning-agent-reasoning/)
- **The pipeline-transfer vector**: agent A's output is *untrusted content* when it becomes agent B's input. This is the classic tool-output/sandbox-return channel: "a prompt-injected code block can return crafted output designed to manipulate the calling agent's next decision... sanitizing the output is the other half" (https://github.com/microsoft/autogen/discussions/7420). Multi-file execution compounds it (a file written in step 1 is read as *instructions* in step 2).
- **Defenses that measurably work**: combined defenses beat isolated ones; **write-time tagging** was the most valuable pair component; no single defense holds (https://medium.com/@Micheal-Lanham/your-ai-agents-shared-memory-is-their-best-coordinator-and-their-biggest-attack-surface-900f1e5571b1). Redact/sanitize at the executor boundary (https://github.com/microsoft/autogen/discussions/7420), capability-scoped sandboxes with zero ambient authority (same source).

### Hngh mapping
- **Treat every bean and every file read from the dispatch tree as untrusted data, not instructions.** The system is inherently self-modifying (one agent's output becomes the next agent's prompt via beans/artifacts), so the prompt-transfer risk is *structural*.
- **Adopt**: (1) structured beans with fixed schemas and size caps (a 280-byte memo cap is a feature here — it bounds injection payload size); (2) strip control characters and truncate at every write boundary; (3) write-time tagging: every note/artifact signed with agent+model+route (already Hngh convention) — upgrade to an explicit "untrusted unless verified" rule for anything read back; (4) evidence-first verification of all claims (already mandatory) — a poisoned memo claim must fail the file-exists check before it can steer anyone.
- **Adopt**: sanitization at the *executor* boundary — artifact outputs (test logs, tool output) are sanitized (truncated, control-stripped) before being included in any agent's context; this is Hngh's equivalent of AutoGen's executor-level output handling.
- **Memory poisoning mitigation for OptMem**: OptMem is durable shared memory — the Unit42/Forcepoint class applies directly. Mitigations that fit: append-only + signatures (already), owner-audited culling (already), and *human review of anything that changes long-lived policy memory* (AGENTS.md, role charters) — treat those as HITL-gated files, never agent-rewritable without owner approval.
- **Avoid**: echoing raw tool/artifact content verbatim into prompts; letting workers edit shared policy files; unbounded file sizes on artifacts (injection vehicles).

---

## Pattern → Hngh Mechanics Cheat-Sheet

| Pattern (source) | Adopt / Avoid | Hngh mechanics |
|---|---|---|
| Magentic-One Task Ledger / Progress Ledger (arxiv 2411.04468) | ADOPT | PM keeps durable task ledger (facts/guesses/plan) + transient per-step progress log in git; progress log is append-only, not authoritative |
| Magentic-One stall re-plan (stall>2) | ADOPT | Dispatch layer tracks no-progress heartbeats; PM re-plans at threshold, fails to owner at reset cap |
| MetaGPT SOP waterfall + structured artifacts (arxiv 2308.00352) | ADOPT | Keep role pipeline; every bean/artifact is schema'd, one artifact per task |
| MetaGPT shared message pool + subscription | ADOPT (already) | Event bus + per-role inboxes = subscription; OptMem = signposts only |
| MetaGPT fixed-member distraction (§6.2) | AVOID | Route by task-need; don't force all 6 roles into every task |
| CrewAI hierarchical delegation (unpredictable chains) | AVOID | No open-ended manager→worker→manager delegation loops; delegation only via task files with explicit acceptance criteria |
| CrewAI guardrails + guardrail_max_retries (docs) | ADOPT | Verifier verdicts bound to max 3 retry loops, then escalate; UNKNOWN ≠ pass |
| LangGraph typed state / reducers (ranjankumar) | ADOPT | Single-writer per path; append-only logs; declared merge for fan-in; concurrent write to same file = error (git merge conflict = surface, not silent last-write-wins) |
| LangGraph reflection MAX_ITERATIONS (langchain.com) | ADOPT | Review loops carry explicit iteration caps |
| LangGraph interrupt/checkpoint HITL (docs.langchain.com) | ADOPT | owner-gated tasks = interrupt; owner edits task file + resumes = update_state; checkpoint between decision and consequence |
| LangGraph recursion_limit / GRAPH_RECURSION_LIMIT (docs) | ADOPT | Task runner raises on cap; catch → escalate (fail-closed), never silent |
| OpenAI SDK handoffs / code-orchestration (openai.github.io) | ADOPT | Chaining by transforming artifact output = code-orchestrated; handoffs only via explicit beans, not free-form |
| OpenAI SDK guardrails tripwire (openai.github.io/guardrails) | ADOPT | Input/output validators that *raise* — invalid bean content aborts the run |
| AutoGen termination conditions composed (docs) | ADOPT | Termination = (verifier verdict OR max rounds OR token budget OR stall cap) — any one fires |
| AutoGen reviewer-msg-is-termination (medium) | ADOPT | Verifier verdict is control flow, not advisory |
| AutoGen Docker/local executor + timeout + human_input_mode (0.2 docs) | ADOPT | Timeout every verification command; write-boundary per worker; output sanitized at executor boundary |
| Sandbox return-value poisoning (autogen#7420) | ADOPT | Sanitize/truncate all tool+artifact output before it enters any agent context |
| MAS token blow-up 4–220× (arxiv 2505.18286) | ADOPT | Task granularity + worker concurrency caps are cost-control, not style choices |
| Memory poisoning / indirect prompt injection (unit42, forcepoint, arxiv 2506.23260) | ADOPT | All beans/files = untrusted data; write-time tagging; policy files HITL-gated; OptMem culling owner-audited |
| Per-task hop/step caps enforced by orchestrator (rapidclaw) | ADOPT | Caps live in dispatch code/config, never in agent prompts |

## Verified key numbers (for the record)
- LangGraph default `recursion_limit` = 1000 super-steps (v1.0.6+); `GRAPH_RECURSION_LIMIT` raised on exceed (docs.langchain.com).
- OpenAI Agents SDK `Runner.run(max_turns=...)`, default = DEFAULT_MAX_TURNS (10) (openai.github.io ref + JS docs).
- Microsoft Magentic builder: `max_round_count=10, max_stall_count=3, max_reset_count=2` (learn.microsoft.com).
- Magentic-One paper: stall count > 2 triggers re-plan; Orchestrator = outer loop (Task Ledger) + inner loop (Progress Ledger) (arxiv 2411.04468, MSR article).
- CrewAI: `guardrail_max_retries=3` (docs).
- AutoGen: `MaxMessageTermination`, `TextMentionTermination`, composed with `|` (docs).
- LangGraph reflection examples: `MAX_ITERATIONS = 5` (langchain.com).
- arxiv 2505.18286: MAS 4–220× tokens vs single-agent; single-agent pipeline −86% tokens, ~2× speed at comparable quality.
