# Day Tasks — 2026-08-01 (queued, decomposed for cheap/local workers)

Routing policy (manager→dept→worker): each task tagged [TIER].
- LOCAL = $0 unsloth gemma-4-12b / Qwythos-9B. Queued, guard-railed, retry+backoff, human/dept review.
- CHEAP = luna / deepseek-v4-flash / glm-5.2 (bulk remote, sub-cent).
- MID = terra / glm-5.2 (design, comprehension).
- HIGH = kimi-k3 / claude (design forks, novel debugging only).

Guardrails for LOCAL: cap prompt ≤ ~350 tokens, one small task per call, text-out to
~/.hngh-night/artifacts/ (never repo-out), schema-validate, dept-head (glm/luna) re-review,
exponential backoff on stall, human promotes the good.

## Queue A — Research (ground in fetched source; orchestrator fetches, local summarizes)
1. [LOCAL] MisakaNet (Ikalus1988) — git-backed micro-lesson library for agents to share/search
   verified debugging lessons. Fetch README, summarize integration surface for hngh knowledge base.
2. [LOCAL] ponytail-improved (0xwilliamortiz) — "laziest senior dev" minimal-code prompting.
   Fetch README, extract 3 reusable prompt idioms for our worker tier.
3. [CHEAP] hermes-bus (mlinquan) — Unix-socket message bus/session/heartbeat. Compare to our M7
   wire-protocol ADR (length-prefixed SEXP over UDS). Note overlap/divergence.
4. [CHEAP] agentburn (Socialpranker) — local cost profiler for Claude/OpenClaw/Hermes. Evaluate
   vs our llm-budget lifetime-differencing. Worth adopting for per-agent attribution?
5. [CHEAP] openworker (andrewyng) — crib notes for hngh orchestration design. (repo fetch failed
   this session — retry; may be renamed/private.)
6. [CHEAP] terminalfeed.io/for-devs + nothumansearch.ai — scout what they offer agents (feeds/search).
7. [MID] oh-my-openagent agent-model-matching.md version history — track maintainer model drift
   so our config stays aligned. (This session already applied the 2026-07 correction.)

## Queue B — hngh build (M1 in progress, 12/15 deliverables)
8. [MID] M7 wire-protocol: review overnight ADR (artifacts/01) against hermes-bus findings (#3),
   decide SEXP-vs-bus, write final ADR to docs/.
9. [MID] M8 model-routing: fold this session's tier table (luna/terra/sol/glm/kimi/local) into
   the M8 routing seed (artifacts/08 was thin — expand with real prices + maintainer constraints).
10. [CHEAP] svc-dash PyPI release prep (README/changelog/version bump check).
11. [LOCAL] regenerate weak overnight artifacts: 05-window-cmds (broken elisp), 09-eval-sentry (thin).

## Queue C — Monetization / meta
12. [MID] Hngh Patreon/tip-cup plan: tiers, benefits, automation of scheduled planning/design/update
    posts. Draft a one-page monetization brief (donation cup first, Patreon if automation proves out).
13. [CHEAP] OptMem usage audit — confirm it earns its place across hermes+opencode; document the
    wake/note/recall + agent-call contract in one place.

## Blocked / needs-restart
- Hermes session restart to activate terra main + 120s stall-killer (this session still kimi-k3).
- After restart: run Queue A 1-6 as the first live test of the local/cheap routing.
