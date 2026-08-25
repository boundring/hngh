# Market scope for Hngh — 2026-08-25 zoom-out pass

Read-only recon (4 searches + 8 primary fetches; see the scout
transcript for full citations). Framing, not commitments: opportunity
signals that can shape queue candidates.

## Signals

1. **Agent-marketplace governance is the unguarded gap.** Marketplaces
   now sell autonomous agents (Agentforce ~$125–550/user/mo; Gartner:
   40% of enterprise apps embed task agents by end-2026, >40% of
   agentic projects cancel within 2 years — concentrated where scoped
   permissions, named ownership, and audit trails were skipped).
   Deloitte: ~1 in 5 enterprises has a mature agent-governance model.
   A registry + authorization + audit lane for autonomous agents is
   empty.
2. **LLM serving is commodity; do not build the GPU layer.** Serverless
   costs scale per token; self-hosting is compliance-driven; SGLang
   for JSON/tool-call. Thin control-plane (run cost caps/budgets) is
   the Hngh-shaped part.
3. **Governance/audit tooling is the strongest signal — on a legal
   timetable.** EU AI Act Art 12/19/26 (automatic logging, retention,
   6-month minimum; high-risk from 2-Dec-2027) and liability cases
   (Amazon v. Perplexity: a user instruction is NOT legally recognized
   authorization) make a tamper-evident, identity-bound authorization +
   execution record the defensible posture. AgentBouncer = open-core
   governance incumbent (policy engine, registry, hash-chain audit,
   EU evidence; free alpha → paid enterprise).
4. **OSS monetization fits a side-effect-free kernel.** OSS dominates
   dev, SaaS dominates production ("you pay for visibility, not
   infrastructure"); free tier → LangSmith ~$39/mo, Braintree ~$249/mo,
   Galileo from $5k/mo. Closest analog by shape: n8n (open core +
   self-host kit + paid cloud + docs-first, 162k stars).
5. **Observability is crowded; do not rebuild it.** OTel per-span
   traces, evals, guardrails, cost tracking are commoditized — sit
   UNDER them: observability shows what happened, Hngh's ledger claims
   what was AUTHORIZED and what mutations were policy-gated.

## Chase vs skip

- **CHASE (high):** regulated-operator governance over the ledger
  (run-cert + ledger + mutation-check) as EU-AI-Act-oriented agent
  authorization + action audit; freemium-hosted compliance dashboard /
  report export; a published ledger/cert format as an open standard.
- **MODERATE:** run cost-budget accounting.
- **SKIP:** LLM serving (GPU capEx, per-token commodity); generic
  observability/evals (crowded, price-decaying); marketplace
  reselling.

## Sources

Primary: agentbouncr.com · concordium.com · flexsin.com/agent-marketplace ·
cloud.google.com/blog (agent marketplace) · handbook.modular.com ·
blog.n8n.io · github.com/dyronrh/awesome-agentops · EUR-Lex 2024/1689 ·
arxiv abs/2411.05231. Unreachable: nalgeon/opensource-money (404),
primary examples substituted. This is one operator-cited snapshot, not
legal advice.