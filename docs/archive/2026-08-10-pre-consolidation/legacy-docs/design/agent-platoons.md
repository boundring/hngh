# Agent Platoons — Multi-Agent Squad Orchestration for hngh

**Status**: Draft v0.1 (2026-08-02) — design complete, implementation pending
**Milestone**: M9 (post-M8 model-management)
**Owner**: Sisyphus (opencode), coordinated with Hermes queue manager

---

## 1. Why Platoons?

Current primitives (M6–M8):
- `mc` / mission-control.lisp → fixed 4-pane tmux + `mc add` for ad-hoc panes
- `agent-call` → one-shot headless agent invocation
- ai-orchestrator → delegate/handoff for task graphs
- model-runtime → local model lifecycle (unsloth/llama.cpp/ollama)

Missing: **declarative, reproducible spin-up of attended multi-agent sessions** with wake prompts, role contracts, session journaling, and preflight gates. That is the platoon layer.

---

## 2. Squad Spec — Declarative Format

**File**: `hngh/squads/<name>.spec.sexp` (or JSON; S-exp preferred for Lisp-native parsing)

```lisp
(squad
  :name "duo-review"
  :version 1
  :description "Two-agent code review: opencode + hermes review AGENTS.md files"
  :layout :vertical        ; :vertical | :horizontal | :tiled | :custom
  :preflight
    ((require-mcp :all)     ; fail if any declared MCP unavailable
     (require-systemd :units ("unsloth-studio"))
     (require-model :endpoint "http://127.0.0.1:8888/v1" :model "gemma-4-12b")
     (quota-gate :max-remote-cents 50))
  :members
  ((:role "coordinator"
    :cli "opencode"
    :model "kimi-k3"
    :cwd "~/Projects/etc"
    :wake-template "coordinator-review-duo"
    :mcp-servers ("filesystem" "github"))
   (:role "reviewer"
    :cli "hermes"
    :model "kimi-k3"
    :cwd "~/Projects/etc"
    :wake-template "reviewer-agents-md"
    :mcp-servers ("filesystem" "github")))
  :journal
    ((:projected-path "hngh/journal/squads/{{squad}}-{{timestamp}}-projected.md")
     (:actual-path "hngh/journal/squads/{{squad}}-{{timestamp}}-actual.md")))
```

**Fields**:
- `preflight` — checklist; abort spin-up if any check fails (MCP health, systemd units, model endpoint, quota)
- `layout` — tmux pane arrangement; `:custom` reads `tmux-layout` string
- `members` — list of agent roles; each has:
  - `role` — identifier (coordinator/worker/reviewer/scout/custom)
  - `cli` — "opencode" | "hermes"
  - `model` — model string (free/local preferred; remote requires quota-gate)
  - `cwd` — working directory
  - `wake-template` — key into prompt template library
  - `mcp-servers` — list of MCP names this member needs
- `journal` — template paths for projected/actual journals

---

## 3. Role Layouts (Metaphors)

Platoons support four canonical role layouts. Each maps to a tmux arrangement + coordination pattern.

| Layout | Metaphor | Coordination | Best For |
|--------|----------|--------------|----------|
| **Squad** | Military fireteam | Coordinator → Workers; Reviewer validates; Scout gathers | Code review, feature implementation |
| **Hierarchy** | PM/Tech-Lead/Dev | Top-down task decomposition; status rolls up | Multi-step projects with clear owner |
| **Democratic** | Consensus circle | All peers; explicit proposals + votes + merge | Design forks, architecture decisions |
| **Organism** | Organs in a body | Specialized organs (heart=queue, brain=planning, liver=detox) | Long-running autonomous systems |

**Squad** (default): 2–6 agents. Coordinator owns queue; workers execute; reviewer gatekeeps; scout fetches.
**Hierarchy**: 1 lead + N workers. Lead decomposes → assigns via queue; workers report done/blocked.
**Democratic**: N peers. Proposals written to shared file/queue; quorum required for commit.
**Organism**: N specialized roles. Each has single responsibility; communicate via event bus.

Each layout has a default tmux pane recipe and a coordination protocol (queue-based, file-based, or event-bus-based).

---

## 4. Prompt Template Library

**Location**: `hngh/squads/templates/` (SEXP or markdown files)

### Core Templates (7)

| Template | Role | Source Idioms |
|----------|------|---------------|
| `coordinator-base` | Coordinator | most-capable: "single-agent first", "task graph not chat", "wake-up protocol" |
| `worker-base` | Worker | most-capable: "separate reasoning from workflow", ponytail: "laziest senior dev" |
| `reviewer-base` | Reviewer | most-capable: "verification separate role", avoid-ai-writing rules |
| `scout-base` | Scout | khoj: "research mode iterative loop", most-capable: "capability acquisition ladder" |
| `coordinator-review-duo` | Coordinator (2-agent review) | Specialized: "you + reviewer review AGENTS.md across projects" |
| `reviewer-agents-md` | Reviewer (2-agent review) | Specialized: "you review AGENTS.md with coordinator" |
| `generic-wake` | Any | Shared: OptMem wake, shared-memory contract, house style, model policy |

### Template Structure

```markdown
---
role: coordinator
extends: coordinator-base
slots:
  squad: "{{squad}}"
  mission: "{{mission}}"
  siblings: "{{siblings}}"  ; list of other members with role/cli/model
  shared-memory: "{{shared-memory-contract}}"
  model-policy: "{{model-policy}}"
  house-style: "{{house-style}}"
---

# Your Role: {{role}} in Squad {{squad}}

## Mission
{{mission}}

## Siblings (your platoon)
{{siblings}}

## Coordination Contract
{{shared-memory-contract}}
- Run `~/.optmem/memo wake` at start
- Sign notes with your agent name: `[ts] agent-name: ...`
- Files = payloads; memo = signposts (<280B)

## Model Policy
{{model-policy}}
- Daily driver: unsloth/gemma-4-12b @ :8888 (219904 ctx)
- Remote API < $1/day; prefer local for loops
- K3/GitHub Copilot: sparing, design forks only

## House Style
{{house-style}}
- Leonard lean, Orwell care, tiny Pratchett, more Adams
- No flattery, no status updates, no AI slop

## Ponytail Guardrails (always active)
- Solve ONLY the stated task; do not refactor, do not add features
- If API/command not shown in prompt or pasted source → write "unknown"
- Best change = smallest change that passes tests
- Reply with artifact only; no preamble, no summary, no sign-off
- Follow stated output format literally; exact counts, exact headings

## Your First Actions (Wake-Up Protocol)
1. `~/.optmem/memo wake` — load shared context
2. Read AGENTS.md in cwd
3. Ask ONLY minimal clarifying questions (max 2)
4. Emit your work queue: now / next / blocked / improve / recurring
5. Start immediately on `now`
```

**Inheritance**: Templates extend a base (`extends:`), filling role-specific slots. The launcher renders the full prompt by walking the inheritance chain.

---

## 5. Journaling — Projected vs Actual

Every squad session produces **two journals**:

### Projected Journal (written at spin-up)
- Squad name, timestamp, members (role/cli/model/cwd)
- Mission statement
- Preflight results (all gates + any warnings)
- Budget estimate (local vs remote, token budget per member)
- Expected deliverables (files, artifacts, decisions)
- Timeline estimate (start → checkpoints → done)
- Risk flags (quota pressure, model instability, MCP flakiness)

### Actual Journal (appended during/after)
- Per-member timeline: wake → actions → artifacts → handoffs → done/blocked
- Token/cost accounting (actual, from llm-budget / model-runtime)
- Artifacts produced (paths, summaries)
- Decisions made (with rationale)
- Deviations from projected (why, impact)
- Lessons for next session (append to `docs/project/lessons.md`)

**Convention**: Both journals live at `hngh/journal/squads/{{squad}}-{{YYYYMMDD}}-{{seq}}-{projected,actual}.md`. Projected is immutable after spin-up; actual is append-only.

---

## 6. Preflight Gates

Spin-up aborts if ANY gate fails:

| Gate | Check | Implementation |
|------|-------|----------------|
| **MCP** | Each declared MCP server responds to `initialize` | `mcp-list` + health ping |
| **Systemd** | Required units active (`systemctl --user is-active`) | `systemctl --user is-active unsloth-studio llmtrim` |
| **Model** | Endpoint `/v1/models` returns expected model | `curl -sf http://127.0.0.1:8888/v1/models \| grep gemma-4-12b` |
| **Quota** | llm-budget remaining > gate threshold | `llm-budget --check-cents 50` |
| **Disk** | `~/.hngh` + journal dirs have > 500MB free | `df -h ~/.hngh` |

Gates are declarative in the squad spec. The launcher runs them sequentially; first failure prints context and exits non-zero.

---

## 7. Benchmark Integration (M8 Tie-In)

M8 model-management plugin will provide:
- `model-runtime:benchmark` — run standardized prompt suite against available models
- Routing table: task-type → preferred model (local-first)
- Cost/latency/quality matrix per model

Platoons integrate via:
- **Squad spec**: `:benchmark-profile :code-review` → selects models from M8 routing table
- **Preflight**: verifies benchmarked models are currently available
- **Journal**: records which model each member actually used + benchmark version
- **Retro**: after N sessions, platoon data feeds M8 routing table refinement

Benchmark harness (separate, M8-owned) runs nightly on local models; platoons consume its output.

---

## 8. External Integration Notes (from Research)

### ponytail-improved (0xwilliamortiz/ponytail-improved)
- **Idioms folded into templates**: Decision ladder (reuse repo → stdlib → platform → one-liner → minimal code)
- **Guardrails**: 5 prompt fragments embedded in every wake template (see Section 4)
- **Install**: Not a package; a prompt discipline. Documented in AGENTS.md + templates.

### MisakaNet (Ikalus1988/MisakaNet)
- **What it is**: Git-backed micro-lesson library (249 redacted failure→recovery entries), Python stdlib CLI + optional MCP
- **Integration**: Separate lesson store from OptMem. OptMem = signposts (temporal, <280B); MisakaNet = curated, shareable, searchable lessons
- **Proposed store**: `~/.misakanet/lessons/` (git repo, shared by opencode+hermes)
- **Hook points** (if README commands confirmed):
  - Pre-debug: `misakanet search "error pattern"`
  - Post-fix: `misakanet record --from-diff --lesson "fix summary"`
- **Verdict**: High idea value; adopt as second knowledge tier alongside OptMem. Stage install task for Hermes queue.

### agentburn (Socialpranker/agentburn)
- **What it is**: Local read-only cost profiler (Claude/OpenClaw/Hermes); per-source burn bars, overnight bill, recommendations
- **Gap vs llm-budget**: llm-budget = OpenRouter lifetime diff + exit-code gating + cron windows + local-exempt; agentburn = multi-agent attribution + overnight isolation + loop/retry detection
- **Crib into llm-budget**: Per-source burn bars, overnight summary, recommendation engine
- **Verdict**: Don't run agentburn as separate tool; fold its observability patterns into hngh's llm-budget + model-runtime cost tracking.

### eagle-eye (willingning-coder/eagle-eye)
- **What it is**: 5-layer skill retrieval for Hermes (hard triggers → FTS5 → synonyms → dense embedding → RRF fusion)
- **Install**: `git clone → python scripts/generate_config.py → edit _HARD_TRIGGERS/synonyms → bash scripts/install.sh → hermes gateway restart`
- **Deps**: `jieba` (required), `sentence-transformers` + `numpy` (optional, L4 fallback)
- **Hermes-only** — no opencode support claimed
- **Integration**: If adopted, index hngh's own skills first (mission-control, model-runtime, ai-orchestrator, sentry, emacs-daemon). Stage eval task (already queued as task 51).

### khoj-ai/khoj
- **What it is**: Self-hostable "second brain" — chat over docs/web, multi-client (web/Obsidian/Emacs/WhatsApp), agents + automations + research mode + MCP
- **Worth cribbing**: Bi-encoder + cross-encoder retrieval stack; agent registry (persona/model/tools); research loop (iterative, parallel tools, streaming, cancel); automations (cron-triggered queries); MCP bridge
- **Verdict**: High idea value, medium integration value. Crib patterns, not the app.

### most-capable-agent-system-prompt (fainir/most-capable-agent-system-prompt)
- **Best 7 portable patterns** (folded into templates + coordination protocol):
  1. Single-agent first; add agents only when justified
  2. Separate reasoning (agents) from workflows (routing/retries/checkpoints)
  3. Task graph, not chat log — state in goals/tasks/artifacts/approvals
  4. Verification is a separate role
  5. File-first state + artifact trail — every phase leaves files/checkpoints
  6. Typed contracts + schemas for tasks/tools/artifacts/decisions/evals
  7. Wake-up protocol — inspect workspace, minimal questions, emit queues, start immediately

### avoid-ai-writing (conorbronsdon/avoid-ai-writing)
- **Format**: Single `SKILL.md` skill pack; works for Claude Code, Hermes, OpenClaw, Cursor
- **Install**:
  - Hermes: `curl -o ~/.hermes/skills/writing/avoid-ai-writing/SKILL.md <raw-url>`
  - opencode: symlink same SKILL.md into shared skill dir + AGENTS.md reference
- **Core rules** (10): Remove sycophancy, cut hype, prefer direct facts, plain verbs, reduce filler, strip template conclusions, avoid synonym cycling, specific claims over fluff, strip AI fingerprints, varied short prose
- **Fit**: Aligned with house style; risk of overcorrection on technical docs (bullet lists, changelogs)

---

## 9. Implementation Plan (v0 → M9)

### v0 (Shell Script — Today)
**Location**: `~/.local/bin/squad` (alongside `mc`, `agent-call`)
- Parse squad spec (SEXP via `sbcl --script` or JSON via `jq`)
- Run preflight gates (sequential, fail-fast)
- Create tmux session: `tmux new-session -d -s "squad-<name>"`
- For each member: `tmux split-window` + launch CLI (interactive) + `tmux send-keys` rendered wake prompt
- Write projected journal (template expansion)
- Attach or print attach command

**Dependencies**: tmux, sbcl (for spec parse), jq (fallback), curl (model health)

### v1 (hngh Plugin — M9)
**Location**: `src/plugins/agent-platoons.lisp`
- Full Lisp parser for spec
- Integrates with hngh queue/scheduler for background squad runs
- Journal writes via state-store (transactional)
- Preflight uses model-runtime + package-manager + secrets-manager
- Exposes `(platoon:up "spec-name")` and `(platoon:status)` to REPL/daemon

### M9 Exit Criteria
- `squad up` spins any valid spec → attended tmux session with all members awake
- Projected journal written atomically; actual journal appendable
- Preflight gates all functional (MCP, systemd, model, quota, disk)
- Dogfood: `duo-review` spec recreates today's opencode+hermes session
- Templates cover coordinator/worker/reviewer/scout + specialized variants
- Benchmark integration: spec can reference M8 routing table

---

## 10. Dogfood Target — Today's Duo Review

**Spec**: `hngh/squads/duo-review.spec` (see Section 2)
- 2 members: opencode(local gemma-4-12b, coordinator) + hermes(local gemma-4-12b, reviewer)
- Mission: "Review all AGENTS.md files in ~/Projects/etc and subdirs; report discrepancies; propose unified conventions"
- Wake templates: `coordinator-review-duo`, `reviewer-agents-md`
- Preflight: unsloth-studio active, gemma-4-12b healthy, quota > 50¢
- Journals: `hngh/journal/squads/duo-review-20260802-1-{projected,actual}.md`

This is the **first squad**. It reproduces the exact session you and Hermes are in right now — but declaratively, reproducibly, with journals.

---

## 11. Open Questions

1. **Spec format**: SEXP (Lisp-native) vs JSON (tool-agnostic)? SEXP preferred — hngh is CL-first; `sbcl --script` parses fast.
2. **Multi-machine squads**: tmux is single-machine. Remote members need SSH + tmux on target, or hngh daemon RPC (M7). Defer to M10.
3. **Session resumption**: Journals + task graph enable resume. Spec needs `:resume-from` pointing to actual journal. Design in v1.
4. **Prompt template versioning**: Templates evolve. Spec should pin template version or hash. Add `:template-version` to member spec.

---

## 12. References

- hngh design: `docs/design/hngh-design-spec.md`, `docs/design/components.md`
- Mission control: `docs/design/mission-control.md`, `src/plugins/mission-control.lisp`, `~/.local/bin/mc`
- Model routing: `docs/design/model-routing.md`, `docs/guides/local-model-benchmarks.md`
- Night queue artifacts: `~/.hngh-night/artifacts/` (11-14, 21, 47-51)
- Dogfood program: `sysconfig_mgmt/.omc/plans/hngh-gbd-dogfood-program.md`
- Coordination contract: `AGENTS.md` (this repo), `~/.optmem/memo` (shared memory)
