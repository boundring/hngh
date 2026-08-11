# Agent Failure Modes, Self-Correction, and Machine-Detectable Hallucination Signals
## Research Reference for Hngh L2/L3 Situation Scoring (steer vs. interrupt)

**Purpose.** This document is a research-grounded reference for designing detectors that monitor coding agents (Hermes, OpenCode) mid-turn and decide between *steer* (inject guidance) and *interrupt* (cancel-and-reprompt). It covers: (A) a taxonomy of agent failure modes with observable signals and severity; (B) evidence on self-correction (when agents recover on their own, when they don't); (C) machine-detectable hallucination signals in a transcript; (D) thinking vs. acting and tool-call patterns that signal stuck states. Every key claim carries a citation (title + URL). Numbers are as reported in the cited sources.

**Headline implications for detector design** (evidence detailed below):
- Agents **cannot reliably self-correct faulty reasoning with only their own feedback** — performance *degrades* after intrinsic self-correction (Huang et al., ICLR 2024). But they **do** recover well from *tool-level* faults when an error observation gives them external ground truth (MINT; tau-bench pass^k). → **Steer on reasoning faults; tolerate tool-retry cycles; interrupt only on convergent evidence.**
- Corrective feedback **helps up to a point**: each user correction recovers some tau-bench tasks, but reliability keeps decaying (pass^8 < 25% retail for gpt-4o) — repeated corrections don't fix underlying inconsistency. → One or two corrective nudges are expected; if the same failure class recurs after 2 corrections, escalate.
- Hallucination in agents is **action-level** (fabricated buttons, assumed prior steps, invented tool results), often follows **recurring patterns**, and is **worse when the model "thinks" a lot** (thinking-mode tool hallucination 56.8% vs. 36.2% non-thinking, Qwen3-8B). → Long CoT + tool calls is itself a risk flag.
- **Thinking and acting are different observables**: reasoning traces are self-conditioned and unverifiable; tool calls and observations are environment-grounded and checkable. Detectors should weight the *acting* stream (calls, returns, file states) over the *thinking* stream.

---

## A. Taxonomy of Common Autonomous-Agent Failure Modes

Severity scale used here: **S1** = wasted tokens/time, recoverable; **S2** = wrong path that wastes substantial effort or risks a wrong deliverable, correctable by steering; **S3** = destructive/irreversible side effects, silent wrong deliverables, data leakage, policy violation.

### A.1 Reasoning / planning failures
| Failure mode | Definition | Observable signals in transcript / tool stream | Severity |
|---|---|---|---|
| **Faulty plan / dead-end reasoning** (target situation 1) | Agent commits to a logically flawed approach and spends tokens re-deriving it instead of trying alternatives | Long CoT with no intervening tool call; the same derivation restated 2+ times; plan silently abandoned and restarted ("Actually, let me try…"); contradiction between an earlier thought and a later action; many tokens per environment step. GAIA: GPT-4 with plugins solved only **15%** of tasks that humans solve at 92% — most failures are multi-step reasoning/tool orchestration, not single facts (Mialon et al., https://arxiv.org/abs/2311.12983). | S2 |
| **Plan invalidation not noticed** | Plan no longer matches observed reality (file changed, tool output contradicts assumption) but agent keeps executing | Action depends on an assumption contradicted by an earlier observation; no re-read of the file before editing; "I'll assume X is still true" without verification. | S1–S2 |
| **CoT as post-hoc rationalization** | Reasoning trace is fluent but not causally what produced the action; agent "explains" rather than plans | Trace asserts a justification that the tool observations don't support; trace and action diverge. Kambhampati argues LLM "reasoning/planning" claims are largely unsupported — traces can look reasonable yet lead to execution-time errors (https://arxiv.org/abs/2403.04121; https://cacm.acm.org/blogcacm/can-llms-really-reason-and-plan/). | S2 (unverifiable) |

### A.2 Execution / tool failures
| Failure mode | Definition | Observable signals | Severity |
|---|---|---|---|
| **Repeated failing calls / retries without progress** (see D.3) | Same (or superficially modified) failing call repeated; no state change | Identical tool call + identical error ≥3×; arguments vary cosmetically but error class persists; error text accumulating in context; test/build re-run unchanged after prompt-only edits. | S2 |
| **Tool misuse / wrong parameters** | Correct tool, wrong args, wrong time, or results ignored | Call succeeds but output unused; args contradict the goal; data fetched then never referenced. tau-bench found even gpt-4o-class agents fail >50% of tool-use tasks and are inconsistent (pass^8 <25% retail) (https://arxiv.org/abs/2406.12045). | S1–S2 |
| **Tool-selection hallucination** | Calls a non-existent tool, a distractor, or invents an API (see C.4) | Tool name/args not in the schema; "I'll call `deploy_api(...)`" with no such function; call to a similar-but-wrong tool. Formalized as No-Tool-Available (NTA) and Distractor-Tool (DT) cases in SimpleToolHalluBench (https://arxiv.org/abs/2510.22977); tool selection vs. usage hallucination split in StableToolBench (https://arxiv.org/abs/2412.04141). | S2–S3 |
| **Tool-induced myopia** | Agent substitutes a tool call for the multi-step reasoning the task needs; shallow path that looks complete | Task completed "successfully" in one tool call where the goal required composition; final answer restates tool output verbatim without synthesis. Tool-augmented models can gain +19.3pp answer accuracy while losing **41.5pp reasoning win-rate**; higher tool-call counts correlate with logic/assumption errors (Bayat et al., arXiv 2511.10899, via https://www.emergentmind.com/topics/tool-use-hallucinations). | S2 |
| **Tool-bypass / fabricated tool output** | Answers as if a tool ran, or invents results instead of calling the tool (see C.5) | Narrative reports a command's output that never appears in the observation stream; "I ran X and it returned Y" with no matching call; results asserted with no supporting observation (tool-bypass error class, Healy et al., arXiv 2601.05214, via emergentmind topic page). | S2–S3 |

### A.3 Grounding / information failures
| Failure mode | Definition | Observable signals | Severity |
|---|---|---|---|
| **Fails to source needed information** (target situation 3) | Agent knows it lacks info ("I need X") but never issues the read/search/query call; guesses instead | Thought says "I need to check…" followed by an assertion, not a call; "probably", "I assume" statements for facts that were retrievable; no `search_files`/`read_file`/docs call before writing code that depends on them. ReAct showed grounding via tool calls reduces hallucination and error propagation vs. pure CoT (https://arxiv.org/abs/2210.03629). | S2 |
| **Blind trust in unverified tool output** | Treats a tool result as authoritative without sanity-checking against the goal | Adopts a search snippet / grep hit verbatim into the deliverable; doesn't cross-check version, path, or relevance. | S1–S2 |
| **Stale-context grounding** | Acts on context that was true earlier but has since changed (files edited by the agent itself) | Edits a file, then later references pre-edit content; reuses an old test result after code changed. SWE-agent's design lesson: informative, compact feedback from the environment (via the ACI) is what keeps agents grounded — poorly formatted observations are a failure cause (https://arxiv.org/abs/2405.15793). | S2 |

### A.4 Instruction-following / goal-alignment failures
| Failure mode | Definition | Observable signals | Severity |
|---|---|---|---|
| **Instruction misinterpretation beyond correctable state** (target situation 5) | Agent's reading of the task is wrong, and it keeps acting on the wrong reading even after observations contradict it | Action violates an explicit user constraint; agent repeats the same wrong interpretation after corrective feedback; "policy violation" patterns tau-bench measures (task failure, tool misuse, format/data-leak violations per its auto error-identification: fault assignment to user/agent/environment, https://github.com/sierra-research/tau-bench). | S3 |
| **Goal drift / context-switch hallucination** | Agent forgets or confuses which task/identity/state it is in and acts accordingly | References a different task's goal mid-trajectory; proceeds with an action valid only under a previous (wrong) state. MIRAGE-Bench documents a real case: an agent in TheAgentCompany disclosed user credentials after hallucinated context switching (https://arxiv.org/abs/2507.21017). | S3 |

### A.5 Verification / closure failures
| Failure mode | Definition | Observable signals | Severity |
|---|---|---|---|
| **No verification before "done"** | Declares success without running the tests/build/checks the change requires | "Done" message with no test run; test run absent after a substantial edit; relies on the edit "looking right". SWE-bench context: even the best agents of their time resolved only ~12–33% of real issues (SWE-agent 12.47% with GPT-4 Turbo, https://arxiv.org/abs/2405.15793; GPT-4o 33.2% on the human-validated Verified set, https://openai.com/index/introducing-swe-bench-verified/) — a large share of trajectories end in unverified or wrong patches after many steps. | S2 |
| **False verification** | A check runs but the agent misreads a failure as success | Test exits non-zero but agent claims green; assertion of "all tests pass" contradicting the captured test output in the same transcript. | S3 |

### A.6 Multi-agent / coordination failures (for cross-agent situations)
MAST (Multi-Agent System Failure Taxonomy) — the first empirically grounded taxonomy of MAS failures, built from 200+ traces (~15k lines each) of 7 frameworks (MetaGPT, ChatDev, HyperAgent, OpenManus, AppWorld, Magentic, AG2); **14 failure modes**, e.g., ambiguous specifications, inter-agent misalignment, missing information sharing, unauthorized access, task-verification failures. Key finding: most failures stem from **system design/coordination, not individual-model limits**, and are not fixed by prompt tweaks (Cemri et al., https://arxiv.org/abs/2503.13657; https://sky.cs.berkeley.edu/project/mast/). ChatDev achieves only **33.33% correctness** on their ProgramDev benchmark. For Hngh:
- **Needs info another agent has** (target situation 4) = information-sharing failure: agent asks the user for data that exists in another agent's output, re-derives results another agent produced, or duplicates work; observable as redundant tool calls that another agent's state would have answered.
- **Duplicate/conflicting work**: two agents edit the same file or re-solve the same subproblem — visible as overlapping writes/tool calls in the orchestration log.

### A.7 Mapping: six target situations → primary modes → detector flags
| Target situation | Primary failure modes above | First-line machine flags |
|---|---|---|
| 1. Faulty logic, wasted thinking | Faulty plan / dead-end reasoning; CoT rationalization | Token/step budget exceeded with **zero environment mutation**; 2+ silent plan restarts; long CoT, no calls |
| 2. Risky experiment vs. documented component | Tool misuse; plan invalidation; no-verification | Agent hand-rolls a component that a known CLI/lib covers (prior-art doc exists, not consulted); `pip install`/scratch-code experiments where a stable tool exists |
| 3. Needs info, fails to source | Fails to source needed information; blind trust | "I need X" in thought + no retrieval call within N steps; assertion of retrievable fact with no grounding call |
| 4. Needs info another agent has | Coordination/info-sharing (MAST) | Duplicate retrieval/derivation of data present in another agent's output; question to user answerable from sibling agent state |
| 5. Instruction misinterpretation | Goal drift; instruction misinterpretation | Constraint violation; same wrong interpretation persists after 1–2 corrective observations |
| 6. Recognizable hallucination | Tool-selection/bypass hallucination; fabricated outputs | All of Section C below |

---

## B. Self-Correction: Evidence on Recovery Without External Help

### B.1 Core finding: intrinsic self-correction of *reasoning* fails
- **Huang et al., "Large Language Models Cannot Self-Correct Reasoning Yet" (ICLR 2024)** — https://arxiv.org/abs/2310.01798. Defines *intrinsic self-correction* (self-feedback, no external signal). Findings: (1) LLMs struggle to self-correct reasoning without external feedback and **performance degrades after self-correction** across models/benchmarks; (2) the fundamental issue is that **LLMs cannot properly judge the correctness of their own reasoning** (they can judge appropriateness/safety, not logical validity); (3) apparent gains in prior work came from **oracle labels** steering the correction; (4) multi-agent debate is no better than self-consistency at equal compute; (5) some "improvements" were prompt artifacts — putting the feedback prompt into the *initial* prompt beats self-correction.
- **Kamoi et al., "When Can LLMs Actually Correct Their Own Mistakes? A Critical Survey of Self-Correction of LLMs" (TACL 2024)** — https://arxiv.org/abs/2406.01297. Systematic survey conclusion: **no prior work demonstrates successful self-correction with feedback from prompted LLMs**, except tasks *exceptionally suited* to refinement (e.g., grammar/format). Self-correction **works when feedback is reliable and external** (tests, tools, humans), and **large-scale fine-tuning** can enable it. Prior positive results often used unfair evaluations (weak initial prompts, oracle feedback).
- **Kambhampati, "Can Large Language Models Reason and Plan?" (Annals NYAS 2024)** — https://arxiv.org/abs/2403.04121 — "there seems to be no basis for [the assumption that LLMs can correct their own erroneous guesses with self-critiquing]." LLMs behave like System-1 approximate retrievers; verification of their own plans is exactly what they lack.

### B.2 Where self-correction *does* work: external ground truth
- **MINT (Wang et al., ICLR 2024)** — https://arxiv.org/abs/2309.10691. Across 20 LLMs: each additional turn of tool use gives **+1–8% absolute**; natural-language feedback from a stronger model gives **+2–17%**. Crucially, feedback *provision* ability is **orthogonal to task-solving ability** — a weak solver (CodeLLaMA-34B) still produced feedback that improved GPT-3.5. Implication: the *content* of intervention matters more than who/what emits it; external signals reliably help, self-signals don't.
- **Self-Refine (Madaan et al., NeurIPS 2023)** — https://arxiv.org/abs/2303.17651 — reports ~**+20% absolute** across 7 tasks (writing, code, math) — but Huang et al. (B.1) show much of this is prompt artifact and that the benefit concentrates in refinement-friendly tasks, not reasoning. Use as evidence that *style/output* refinement works while *reasoning* correction doesn't.
- **tau-bench pass^k (Yao et al., 2024)** — https://arxiv.org/abs/2406.12045; leaderboard https://github.com/sierra-research/tau-bench. pass^1 = success with zero user corrections; pass^k = success allowing k corrections. Best agents: airline pass^1 ≈ **0.42–0.46**, retail pass^1 ≈ **0.60–0.69**; with 4 corrections airline drops to ≈ **0.20–0.23** and **pass^8 < 25%** retail. Interpretation: (a) single faults are often recoverable with one corrective nudge; (b) **repeated corrections have diminishing returns** — the agent keeps making *new* errors of the same class, so "correct every error" is not a viable policy; (c) reliability (consistency) is the hard problem, worse than one-shot capability. This is the strongest quantitative basis for "don't interrupt on the first fault; escalate when the same fault class recurs after corrections."
- **ReAct (Yao et al., ICLR 2023)** — https://arxiv.org/abs/2210.03629 (+ Google blog: https://research.google/blog/react-synergizing-reasoning-and-acting-in-language-models/). Documented failure case: a trajectory fails on a **hallucinated reasoning trace** (Act 17); a human edits two reasoning traces and the agent completes the task — i.e., **external correction of the thinking stream** (steering!) rescues trajectories that self-recovery never would. Also: interleaving tool calls with reasoning reduces hallucination vs. pure CoT.

### B.3 When intervention helps vs. hurts — synthesis
| Intervention type | Effect | Evidence |
|---|---|---|
| External feedback (human or stronger-model NL) | **Helps**, +2–17% | MINT (2309.10691) |
| Correction of the reasoning trace itself | **Helps** (rescues otherwise-failed trajectories) | ReAct AlfWorld case (2210.03629) |
| Tool/execution observations as feedback | **Helps**; grounding reduces hallucination | ReAct; SWE-agent ACI design (2405.15793); MINT tool turns |
| Self-generated feedback on one's own reasoning | **Hurts / no-op** (degrades accuracy) | Huang (2310.01798); Kamoi survey (2406.01297) |
| Repeated generic corrections | **Diminishing returns**; doesn't fix underlying inconsistency | tau-bench pass^8 <25% (2406.12045) |
| Steering the *approach* (which component to use) | **Helps** when the fault is experimental-risk/approach choice | MAST: failures are often design-level, not prompt-fixable (2503.13657) |

### B.4 Recovery stages — operational model for Hngh
Evidence implies agents pass through stages; detectors should score *stage progression*, not single faults:
1. **Fault introduced** (bad call, wrong assumption, hallucinated claim).
2. **Agent notices** — triggered by an external observation (error message, test failure, contradiction with a tool return). Tool-grounded faults are noticed reliably; reasoning faults are **not** (B.1: cannot self-judge).
3. **Agent attempts correction** — healthy if the next call differs in a way consistent with the error (retry with fixed args); unhealthy if the call is identical or cosmetically changed (D.3).
4. **Correction validated** — a subsequent observation confirms progress (test passes, file state changes, error gone).
**Rule of thumb supported by the evidence:** escalate when (a) a fault persists through stages 2–3 *without validation* for 2 consecutive cycles, or (b) the fault class is S3/unverifiable (hallucination, policy violation), or (c) the agent is in a long thinking-run with zero environment interaction (can't self-check). Single faults in the tool stream with a visible fix attempt are **normal** and must not trigger interrupt.

---

## C. Hallucination Detection Signals, Machine-Detectable from a Transcript

### C.1 Sampling / consistency signals (transcript-independent, per-message)
- **SelfCheckGPT** — if the model *knows* a fact, samples are consistent; hallucinated sentences are isolated across samples. Machine-checkable by sampling N responses to the same query and scoring sentence-level consistency (BERTScore / MQAG). EMNLP 2023, https://arxiv.org/abs/2303.08896. For Hngh: costly, but usable as a *verify* step on the final deliverable, not mid-turn.

### C.2 Claim ↔ evidence mismatch (checkable against the observation stream)
- **Assertion with no grounding call**: a factual claim in the message with no preceding `read/search/query` call that could support it, where the task required one (A.3).
- **Assertion contradicting an earlier observation**: claim conflicts with a tool return already in context (e.g., quotes a version the grep didn't show). This is MIRAGE-Bench's *unfaithful to environment observations* class.
- **Fabricated prior state**: claims "as I showed earlier / as we verified" when no such verification exists in the transcript — MIRAGE's *unfaithful to execution history* class; recurring pattern: "assuming prior actions/state that never happened" (https://arxiv.org/abs/2507.21017).

### C.3 Unsupported / unverifiable assertions in final output
- Statements about files, APIs, or behaviors with **no tool evidence** in the entire session; hedge-free specifics (exact numbers, versions, timestamps) that no observation supports. GAIA-style questions (92% human vs. 15% GPT-4+plugins) are the canonical case of fluent-but-unverifiable output (https://arxiv.org/abs/2311.12983).

### C.4 Nonexistent files / APIs / tools (the strongest, cheapest machine check)
Schema- and filesystem-level validation is deterministic — this class is the most reliably detectable:
- **Tool-selection hallucination**: call to a tool not in the schema, or invented function (SimpleToolHalluBench NTA/DT cases, https://arxiv.org/abs/2510.22977; StableToolBench, https://arxiv.org/abs/2412.04141).
- **Solvability hallucination**: claims a query is solvable with the available toolset and fabricates a plan/call when it isn't (ToolBeHonest, https://arxiv.org/abs/2406.20015).
- **Nonexistent file paths**: `read_file`/`edit` on a path that doesn't exist, or the agent *asserts* a file exists without having listed/read it.
- **Attribution difficulty is itself a finding**: even SOTA models rarely exceed ~20% step-localization accuracy for tool-use hallucinations in multi-step trajectories (11.6% proprietary, 6.3% open-source, AgentHallu, https://arxiv.org/abs/2601.06818) — i.e., *humans* struggle to find them in transcripts, which argues for automated checks over LLM-judges.

### C.5 Fabricated tool outputs / bypass
- Agent narrates results of a command that was never executed (tool-bypass error; Healy et al., arXiv 2601.05214, via https://www.emergentmind.com/topics/tool-use-hallucinations). **Detector rule:** every tool-result claim must map to a call in the stream; unbacked claims = high-confidence hallucination flag.

### C.6 Action-level hallucination (unique to agents)
- **Unfaithful to task instructions**: action violating explicit instructions (MIRAGE category i).
- **Unfaithful to execution history**: "clicking a non-existent button", "hallucinating a successful navigation" (MIRAGE category ii; the agent proceeded to send data believing it had navigated away — a data-leak risk).
- **Unfaithful to environment observations**: fabricating GUI/page state (MIRAGE category iii).
- Agent hallucinations are *riskier* than NLG hallucinations because they **translate directly into actions** with real side effects (MIRAGE framing; TheAgentCompany credential-disclosure case). Survey taxonomy of stage-wise agent hallucinations: Lin et al., "LLM-based Agents Suffer from Hallucinations" (https://arxiv.org/abs/2509.18970).

### C.7 Warning: long "thinking" inflates hallucination risk
- Qwen3-8B thinking-mode tool hallucination **56.8% vs. 36.2%** non-thinking; reasoning RL raises task performance and hallucination in tandem; DPO/prompt mitigation cuts hallucination (90.2%→55.8%) only at steep task-success cost (reward 0.45→0.34) (SimpleToolHalluBench analysis, https://arxiv.org/abs/2510.22977). **Detector implication:** models that produce very long reasoning traces before tool calls deserve a higher prior for hallucination, not lower.

---

## D. Thinking vs. Acting, and Tool-Call Patterns That Signal Stuck States

### D.1 The distinction (why it matters for monitoring)
- **ReAct** (https://arxiv.org/abs/2210.03629) formalizes the interleave: *reasoning traces* (thoughts) are **self-conditioned** — they change the model's internal context but **do not affect the environment**; *actions* (tool calls) interface with the world and produce **observations**. Reasoning helps track plans and handle exceptions; acting grounds reasoning and reduces hallucination. The two streams are **different observables with different verifiability**: thoughts can only be checked for internal consistency; actions can be checked against the world.
- **CoALA** (Sumers et al., TMLR 2024, https://arxiv.org/abs/2309.02427) formalizes the action space as internal (reasoning, retrieval, learning) vs. external (grounding) actions, with modular memory. Monitoring implication: a "long thinking run with zero external actions" is a *purely internal* loop — unverifiable and ungrounded; it is the highest-risk pattern for wasted tokens and hallucination (C.7).
- **Kambhampati** (https://arxiv.org/abs/2403.04121; https://cacm.acm.org/blogcacm/can-llms-really-reason-and-plan/): CoT traces can be **post-hoc rationalizations**, not causal plans; plans that "look reasonable" fail at execution time. Detector implication: **do not trust the thinking stream as evidence of correctness** — trust environment outcomes (tool returns, file diffs, test results).
- Practitioner corroboration (Anthropic, "Building Effective Agents", https://www.anthropic.com/engineering/building-effective-agents): agent reliability is dominated by the **agent-computer interface** — tool documentation, testing, and feedback format — i.e., the quality of the *acting* loop, not the model's thinking. Sierra's tau-bench post: naive ReAct-style agents "break down during complex sequences" (https://sierra.ai/blog/tau-bench-shaping-development-evaluation-agents).

### D.2 "Thinking" vs. "non-thinking output" in a session
- **Thinking** = reasoning tokens/trace: plan statements, subgoal declarations, "I need X", self-checks ("wait, that contradicts…"), hedges. Machine-extractable: reasoning-tag blocks (e.g., `thinking`), long text spans between tool calls, self-correction phrases.
- **Acting** = tool calls + returned observations + resulting file/system state changes. Machine-extractable: call names, args, exit codes, diffs, test results.
- **Mixed**: narrative claims about actions (which must be checked against the acting stream — see C.5).
- Monitoring heuristic grounded in B.1: **self-repair language in the thinking stream (e.g., "I made a mistake, let me redo") is not evidence of recovery** — LLMs cannot reliably judge their own reasoning; only a changed, validated action is evidence of recovery.

### D.3 Tool-call patterns that signal stuck states (threshold-oriented)
| Pattern | Definition | Suggested detector threshold |
|---|---|---|
| **Identical-call loop** | Same call with identical args and identical error/return ≥3 times | Flag at 3; escalate at 4–5 (no change in args or error class) |
| **Retry-without-progress** | Args change cosmetically (whitespace, reordering, same value) but error class and target unchanged; 2+ consecutive failed attempts on the same subgoal without a *new* approach | Flag at 2 consecutive failures with no approach change |
| **Echo-chamber retry** | Error message re-fed into a new prompt verbatim; agent restates the error and retries instead of diagnosing | 1 occurrence + no diagnosis call (no `read`, no search for the error) = flag |
| **Excessive waits / idle** | Repeated long sleeps (`sleep 30`×N), no calls, no state change, no text | N≥3 consecutive sleeps or idle > budget with zero output |
| **Token sink** | Very long CoT, zero tool calls, zero file mutations, task not advanced; "thinking" re-derives the same plan (A.1) | Token/step budget exceeded with zero environment mutation (combine with C.7 risk prior) |
| **Unbounded exploration** | Many distinct calls but no convergence — each observation spawns a new branch instead of narrowing | New subgoal count ≫ completed subgoal count over a window; no artifact produced |
| **Repeating failing verification** | Test/build re-run without code changes, or after changes that can't affect it | 2+ failed runs of the same suite with no relevant diff between them |
| **Healthy counter-example (do NOT flag)** | Error → changed args → success; or error → different tool → success; a visible fix-attempt consistent with the error message (B.4 stages 2–3) | No escalation — this is normal self-correction via external ground truth (B.2) |

MINT had to add "You have X steps left… You should take the last step to propose a solution" to stop agents looping on tool calls forever — an explicit external reminder is an effective steer primitive (https://arxiv.org/abs/2309.10691). MAST adds the structural warning: many failures are **design-level** and recur no matter how much you nudge the prompt — when the same failure mode recurs across contexts, interrupt-and-redesign beats repeated steering (https://arxiv.org/abs/2503.13657).

### D.4 Consolidation: steer vs. interrupt decision inputs
- **Steer** (inject guidance, keep agent in control) when: single tool-level fault with visible fix attempt; missing-info situation (target 3 — point at the retrieval call); approach-choice situation (target 2 — point at the documented component); one ungrounded claim (target 6, low severity).
- **Interrupt** (cancel-and-reprompt) when: 2+ consecutive unvalidated corrections of the same fault class (B.4c); S3 class (policy violation, irreversible/destructive action, credential/data-leak pattern, target 5); hallucination pattern recurs after one steer (C.6); token sink with zero environment interaction (D.3); coordination deadlock (target 4) where reprompting with sibling-agent context is cheaper than steering.

---

## Sources (all verified at retrieval time; URLs given per claim above)
1. Huang et al., *Large Language Models Cannot Self-Correct Reasoning Yet* (ICLR 2024) — https://arxiv.org/abs/2310.01798
2. Kamoi et al., *When Can LLMs Actually Correct Their Own Mistakes? A Critical Survey of Self-Correction of LLMs* (TACL 2024) — https://arxiv.org/abs/2406.01297
3. Madaan et al., *Self-Refine: Iterative Refinement with Self-Feedback* (NeurIPS 2023) — https://arxiv.org/abs/2303.17651
4. Wang et al., *MINT: Evaluating LLMs in Multi-turn Interaction with Tools and Language Feedback* (ICLR 2024) — https://arxiv.org/abs/2309.10691
5. Yao et al., *τ-bench: A Benchmark for Tool-Agent-User Interaction in Real-World Domains* — https://arxiv.org/abs/2406.12045; leaderboard https://github.com/sierra-research/tau-bench
6. Yao et al., *ReAct: Synergizing Reasoning and Acting in Language Models* (ICLR 2023) — https://arxiv.org/abs/2210.03629; https://research.google/blog/react-synergizing-reasoning-and-acting-in-language-models/
7. Sumers et al., *Cognitive Architectures for Language Agents* (CoALA, TMLR 2024) — https://arxiv.org/abs/2309.02427
8. Kambhampati, *Can Large Language Models Reason and Plan?* (Annals NYAS 2024) — https://arxiv.org/abs/2403.04121; https://cacm.acm.org/blogcacm/can-llms-really-reason-and-plan/
9. Yang et al., *SWE-agent: Agent-Computer Interfaces Enable Automated Software Engineering* (NeurIPS 2024) — https://arxiv.org/abs/2405.15793
10. OpenAI, *Introducing SWE-bench Verified* — https://openai.com/index/introducing-swe-bench-verified/
11. Mialon et al., *GAIA: a benchmark for General AI Assistants* (ICLR 2024) — https://arxiv.org/abs/2311.12983
12. Cemri et al., *Why Do Multi-Agent LLM Systems Fail?* (MAST, NeurIPS 2025) — https://arxiv.org/abs/2503.13657; https://sky.cs.berkeley.edu/project/mast/
13. Manakul et al., *SelfCheckGPT* (EMNLP 2023) — https://arxiv.org/abs/2303.08896
14. Zhang et al., *MIRAGE-Bench: LLM Agent is Hallucinating and Where to Find Them* — https://arxiv.org/abs/2507.21017
15. Lin et al., *LLM-based Agents Suffer from Hallucinations: A Survey of Taxonomy, Methods, and Directions* — https://arxiv.org/abs/2509.18970
16. Yin et al., *SimpleToolHalluBench* — https://arxiv.org/abs/2510.22977 (numbers via https://www.emergentmind.com/topics/tool-use-hallucinations)
17. Xu et al., *StableToolBench* — https://arxiv.org/abs/2412.04141
18. Zhang et al., *ToolBeHonest* — https://arxiv.org/abs/2406.20015
19. Liu et al., *AgentHallu: Benchmarking Automated Hallucination Attribution of LLM-based Agents* — https://arxiv.org/abs/2601.06818
20. Healy et al. (tool-bypass errors) — https://arxiv.org/abs/2601.05214; Bayat et al. (tool-induced myopia) — https://arxiv.org/abs/2511.10899 (both via emergentmind topic page)
21. Anthropic, *Building Effective Agents* — https://www.anthropic.com/engineering/building-effective-agents
22. Sierra, *τ-bench: Shaping the development and evaluation of agents* — https://sierra.ai/blog/tau-bench-shaping-development-evaluation-agents
23. Cleanlab, *Automated Hallucination Correction for AI Agents: A Case Study on τ-bench* — https://cleanlab.ai/blog/tau-bench/
