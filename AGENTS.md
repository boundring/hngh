# hngh — agent notes (all agent CLIs working in this repo)

## Coordination contract (machine-wide)

- Shared memory: `~/.optmem/memo` — run `wake` at session start, `note "..."` for durable
  facts, `recall <regex>` to search. Top-level sessions only; subagents must NEVER run memo.
- Sign memo notes with your agent name. Memo = signposts/status (<280 bytes); files = payloads
  (write-then-rename for atomicity). Never use memo for task claiming — no claim/ack semantics.
- Summon a sibling agent headlessly: `agent-call hermes|opencode "prompt" [model]`
  (auto-logs to shared memory). Default opencode model follows the mandate
  chain (deepseek-v4-flash-0731 primary; see docs/project/decisions.md D-040).
- Never print secret VALUES from `~/.hermes/.env`, `auth.json`, `*.pem`, `*.key`.
  By-NAME scripted access only (grep/sed/python, no value echo).

## Local-model & quota policy

Primary driver: `deepseek/deepseek-v4-flash-0731` via OpenRouter after local
procedural routes. The only automatic remote fallback candidate is direct
DeepSeek Flash; then local routes. Luna is operator-named only until current
price/budget evidence is recorded. Do not automatically select GLM, MiMo,
K2, Terra, Sol, Anthropic, Gemini, MiniMax, or an unknown-price route.

- **Kimi quota** is K3-only. K3 uses a Kimi-family provider, one compact,
  no-tools authority packet, and the quota gate. Never spend the Kimi quota on
  K2/K2.7 or any other model; never call K3 through another provider.
- **GLM 5.2** is the preferred bounded architecture teacher, ahead of K3 for
  design advice. **Terra** is a high-stakes reserve review. **MiMo** and
  external **K2.6/K2.7** are
  cost-/token-limited fixed-packet experiments. Each needs a named task,
  bounded packet, actual-route attribution, and measured outcome.
- **GPT-5.6 Sol** and all **Anthropic** routes are disabled for Hngh.
  **Luna** is an opt-in coding seat (`squad-up luna-coder`) that needs current
  price/budget evidence; it is never a default squad seat.
- **Agents are disposable; Hngh persists.** Retire a session after a completed
  phase, a verified blocker, or a no-evidence state once its factual handoff is
  valid. Start a fresh cheap successor if work remains. Continuation or
  resurrection needs a named non-reconstructible value, bounded purpose, and
  recorded cost reason; preserving chat context is never enough.
- **Fresh sessions are cheap by design.** When a bounded task stops producing
  evidence, prepare a procedural factual handoff and retire the session with
  its reason. A successor gets the packet, not a transcript or inherited claim;
  it starts on the next named verification.
- **Token cost is bilateral.** Bound both prompt input and generated output:
  pass compact factual packets with source references, not transcript replay;
  use a short message class rather than status narrative; do not repeat
  background another recipient already has. A higher-tier call declares both
  input and output caps before dispatch.
- Local models execute procedural, fixture-backed, and queued work. The case
  base, adoption map, tests, and review gates preserve higher-tier structure;
  a lower-cost seat never receives authority merely from a model name.

## Repo notes

- Push mirrors: `origin` carries both github and codeberg push URLs — `git push origin` syncs both. Never push to a single mirror; if one fails, sync it before continuing.

Common Lisp (SBCL) agent-orchestration system. Build: `make build`. Test: `make test`.
Docs: `docs/` — roadmap at `docs/project/roadmap.md` (M1.x active). Runtime state: `~/.hngh/`.
Plugin sources: `src/plugins/`. Do not commit without the owner's explicit go-ahead.

## Current state (2026-08-08)

- **Tests**: `make test` green — 956/956 fast @ 9d5f23b (L2/L3 Tier-0 situation detectors + L3 scorer + semantic judge + persistent case-base/review loop built; W5 prompt matrix committed: generate-prompt, 36-skeleton library, bone fillers, flesh pass, D-040 synced model selection, prompt cache)
- **M7 daemon**: committed (28d92ad). Wire protocol + daemon core + client CLI + systemd units
- **Lanes merged**: lane-a3 → main (H-A2 eligibility, H-A3 pause/resume, H-B1 maintenance, H-U1 systemd fixes)
- **Security**: `*read-eval* nil` at wire-protocol.lisp:135
- **Night queue**: 58 tasks processed (artifacts in ~/.hngh-night/artifacts/)
- **Hngh Hermes profile:** `hngh` is mandatory for all Hngh Hermes launchers;
  it starts at 33.8 KB before dynamic MCP schemas, uses state files rather
  than generic memory/session recall, and permits only terminal, file, skills,
  context control, Hngh MCP, and MisakaNet. `hngh-minimal` is the local-only
  sub-class, not an alternative default.
- **Cost routing**: canonical fallback chain active (deepseek-v4-flash-0731 →
  deepseek-v4-flash → gpt-5.6-luna → mimo-v2.5 → minimax-m3 → gemini-3.5-flash
  → hy3-preview → glm-5.2 → nemotron-3-ultra:free → Qwythos-9B → gemma-4-12b);
  D-040, no Copilot reliance
- **Role split**: hermes=queue manager, opencode=Sisyphus=M7+platoon code, other opencode=code/docs
- **Doc convention (D1)**: durable records carry `green @ <sha>`, never bare counts
- **Changelog**: every user-visible or architecture-relevant change gets a dated, categorized entry in `CHANGELOG.md` (Keep a Changelog format) as part of the commit — same discipline as the journal + work-sessions records.
- **Test-count lint**: `make lint-counts` — procedural, no LLM. Scans current-state refs in AGENTS.md + roadmap.md
- **hngh-up plugin**: exists with design doc at `docs/design/hngh-up.md` (goal-driven squad spin-up, procedural questionnaire, strategy system, autonomous continuation, social sharing)
- **M9 squad autonomy**: W1-2 done (C1, C2, C3, C5). W3 in progress (C7 PM-first-prompt generator done; C4 + C10 design-only). Wave 2-4 plugins (file-watcher, squad-dispatch, beans, squad-resources) staged 03282f3, wired into main.lisp lifecycle. **W5 prompt matrix built** (docs/design/prompt-matrix.md, per-role chains synced to D-040 in M9.5): generate-prompt, 36 skeletons, bone fillers, flesh pass, model selection, prompt cache — @ b3c5274. **L2/L3 situation-detection + scoring + judge + case-base built** (docs/design/situation-scoring.md §8 steps 1–5): observation model + 8 Tier-0 detectors (situation-detectors.lisp) + L3 scorer/recovery-tracker/gate-lowering → A3 (situation-scoring.lisp) + semantic judge (situation-judge.lisp, pluggable backend/budget/calibration) + persistent case-base/review pass (situation-casebase.lisp, accuracy-improving gate) — 837/837 fast @ 6e6ddcb. **`make lint-parens`** paren gate wired into test-suite. **`make lint-deps`** Wave B dependency guardrails wired into test-suite (plugin `:use` isolation, core→plugin call ban, circular-dep check, prod-never-tests). Design at `docs/design/squad-autonomy.md`. Plan at `.hermes/plans/2026-08-03_squad-automation-bootstrapping.md`
- **squad-up**: `~/.local/bin/squad-up` — 6-seat cascading Konsole launcher. Config: `~/.hngh-night/squad-seats.conf`


## Per-model attribution (required)

Every artifact and session record names its producer: agent + model + harness
(+ cost when nonzero). Examples: "wave-5 spec — hngh task #2 via
unsloth/gemma-4-12b-it-qat-GGUF, $0"; "fix — opencode (kimi-k3, attended)";
"M2 patch — opencode (kimi-k3) reviewing hngh task #4 draft (gemma-4-12b)".
Applies to: session files, work-sessions.md, JOURNAL.md entries, commit
messages (body or trailers), memo notes, README status lines.

## MCP infrastructure (2026-08-05)

- MisakaNet MCP (`misakanet_search`): failure-lesson lookup before re-debugging
  (SQLite/git lockups, DCO, pip). Server: ~/.local/share/misakanet; update via
  `git pull`. Lessons are community-contributed — review commands before running.
- nothumansearch MCP (`search_agents`/`verify_mcp`): agentic-readiness index for
  API/service discovery; pairs with depscope (supply-chain checks).
- All auto-start in Hermes and OpenCode (global opencode config).
- Design note (2026-08-05) proposed cogmem + misakanet as candidates to replace
  OptMem for PM communication. **cogmem was dropped 2026-08-07** (Anthropic-key
  dependency conflicts with cost-conservation policy); only misakanet remains a
  candidate. See journal/20260805-model-mandate.md for context.
