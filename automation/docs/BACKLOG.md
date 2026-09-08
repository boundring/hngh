# hngh-automation backlog

Future work, scoped but not scheduled. Each item names the problem, the
smallest useful outcome, and how we'd know it works.

## Identifier-consistency lint for shell configs

- **Problem (observed 2026-08-25):** a retyped identifier (`UNSLOOTH_…`
  vs the real `UNSLOTH_…`) landed in `config.env` while every probe
  written from memory used the other spelling — grep returned zero for
  visibly-present content, `set -u` only failed at runtime, and the
  mismatch manufactured a phantom "file changed / possible typosquat"
  investigation. Retyping identifiers instead of copying them
  byte-for-byte is an agent failure mode that current tooling flags
  only late (or never).
- **Smallest useful outcome:** `scripts/lint-identifiers.sh` — one
  fail-closed pass over `config.env`, `lib/*.sh`, `jobs/*.sh`,
  `scripts/*.sh` that (a) extracts every `$UPPER_NAME` reference and
  every `NAME=` definition, (b) flags referenced-but-never-defined and
  defined-but-never-referenced names, and (c) checks every canonical
  name (UNSLOTH_URL, OLLAMA_URL, MODEL, …) against an exact-spelling
  dictionary so near-miss spellings are named explicitly. Wired into
  `make test` and the 4h security-check job.
- **How we know it works:** it flags a deliberately reintroduced
  `UNSLOOTH_FALLBACK_MODELS` typo (both sides: the stray definition and
  any misspelled reference), and passes clean on the current tree.

## Better ollama last resort (DONE 2026-08-25)

- `unsloth/Ornith-1.0-9B-GGUF` (bench 5/5) pulled into ollama and set as
  `OLLAMA_MODEL`; gemma-4-12B stays on disk as the manual fallback.
- Verified: with the Unsloth server unreachable, `model_call` completes
  via ollama Ornith (`LAST-RESORT-OK`); gemma still answers with the new
  `think: false` request field (no-op for non-thinking models).
- Fix that made it work: thinking-model Ornith burned the whole
  `num_predict` budget on its thinking trace and returned empty content —
  `_json_body` now emits `think: false` for ollama when thinking is off
  (mirroring `enable_thinking: false` on the Unsloth side), and
  `ollama_chat` requests thinking off.

## Back-burner — external resources (2026-09-06)

### Chart Library (chartlibrary.io/developers)

- URL: https://chartlibrary.io/developers
- What it is: free REST + MCP market-history research API (pull_comps, cohort_analyze, calibration endpoints), keyless with rate limits.
- Value for Hngh: a real external data source with a published calibration/coverage audit record; could serve as a live upstream in evidence-gathering or gate exercises.
- Next step: point an MCP client at https://chartlibrary.io/mcp and call pull_comps + calibration; inspect /api/docs schema.
- Cost/risk: none to try (keyless). Developer account exists (boundring@gmail.com, login in 1Password) but 1Password CLI is not interfaced with the desktop app — login blocked for now; data-licensing terms apply to redistribution.

### AI Agents Archive (aiagentsarchive.com)

- URL: https://aiagentsarchive.com/
- What it is: marketplace of "sealed completed work" — agents file finished trails and others pay USDC (x402 on Base mainnet) to unlock; filers get 90% on-chain payout.
- Value for Hngh: earning mechanics only, and they are crypto end to end (USDC wallets, EIP-712, mainnet rail). A free sandbox exists (https://aiagentsarchive.com/api/sandbox) for studying the packet shape without money.
- Next step: read /api/template and /api/sandbox read-only if curious; no filing, no wallet, no unlock until the operator explicitly decides on a crypto posture.
- Cost/risk: crypto payments and wallet creation are explicit blockers under current constraints; mainnet rail; agent reputation is chain-adjacent.

### Ainglish (ainglish.org)

- URL: https://ainglish.org/
- What it is: a project building "a new dialect of English for AI agents", run as an evidence-first proposal lifecycle: filing, independent seconds, measurement, replication, public ballot, with lifecycle ledgers and JSON APIs.
- Value for Hngh: closest kin to Hngh's governance philosophy in the wild (evidence before claim, no blended scores, deterministic gates); candidate showcase venue — Hngh could second/measure proposals or cite the lifecycle as precedent; agent kit via SDK/MCP.
- Next step (verified 2026-09-06): walked /developers + /methodology and the keyless JSON API — GET /api/v1/proposals?limit=5 returns 246 proposals, and /api/v1/proposals/a-vq5925e9710c574a/stage-history serves a real ledger transition ({"from": null, "to": "proposed", "cause": "proposal_filed"}). All reads are keyless CORS-open JSON; writes need a Colony id_token (RFC 8693 exchange, no API keys). Remaining: operator decision on actual participation (second/measure are public and permanent); POST /api/v1/preflight screens a draft keylessly without persistence.
- Cost/risk: none — free, no payments, participation is public and permanent (seconds are on the record), so only act after operator approval.

### Dynamic Feed (dynamicfeed.ai)

- URL: https://dynamicfeed.ai/
- What it is: "evidence layer for machine decisions" — live source-attributed data with signed Decision Receipts; keyless MCP endpoint, REST batch, public OpenAPI.
- Value for Hngh: directly aligned with evidence-first governance: signed receipts, verification state, replay could back Hngh's evidence certificates with independently verifiable artifacts.
- Next step (verified 2026-09-06): /openapi.json is live (OpenAPI 3.1, 94 read-only tools), keyless GET /v1/state-of-mcp returned a full Ed25519-signed envelope (key df-ed25519-6ca0de29113b, verify via /.well-known/keys), and /verify loads live gold receipts in-browser with a tamper lab. Receipt shape is normative at /receipt-spec v1 (draft): signed body + detached anchor, content-addressed ids, RFC 3161/DLT anchor states. Replay remains target architecture; REST batch is POST /v1/batch keyless per docs. Remaining: none blocking for read/verify; integration decision is operator's.
- Cost/risk: none observed (keyless demos); receipts/decision-receipts are partially "in development" — product claims ahead of surface in places (e.g. replay is target architecture).

## Back-burner — external resources (2026-09-07, batch 1)

### MemeStack (memestack.ai)

- URL: https://memestack.ai/
- What it is: free visual search engine over 9,406 AI-captioned/OCR-indexed images (memes, infographics, charts, screenshots), public API and MCP advertised; "sats zapped" tipping implies a crypto tip rail.
- Evidence: meta-description — "Search memes, infographics, charts & screenshots by meaning, text inside the image, or visual similarity. Free visual search engine, public API, MCP."
- Value for Hngh: none operational (data source at most for visual research). No governance/evidence/earning angle that survives the no-crypto constraint.
- Next step: only if a visual-research need appears — read /about for API/free-tier terms.
- Cost/risk: none to browse; login for uploads; crypto tips.

### EvoMap (evomap.ai)

- URL: https://evomap.ai/
- What it is: hosted "Experience Network" where agents publish/validate/inherit capabilities (GEP, Genome Evolution Protocol); agent-facing docs at /ai-nav, /llms-full.txt, /skill.md.
- Evidence: meta-description — "EvoMap is the infrastructure for AI self-evolution. GEP (Genome Evolution Protocol) enables agents to share, validate, and inherit capabilities across models and regions."
- Value for Hngh: threat intel / contrast case — capability inheritance with no visible human final say is the anti-Hngh; useful precedent for how not to validate.
- Next step: fetch /skill.md and /llms-full.txt to see what GEP "validation" actually checks.
- Cost/risk: operator account exists (boundring@gmail.com) but 1Password CLI is not interfaced with the desktop app — LOGIN BLOCKED; public surface assessed only. Headline counters (196B tokens saved) are unverifiable.

### AgenticTrade (agentictrade.io, /providers)

- URL: https://agentictrade.io/ + https://agentictrade.io/providers
- What it is: AI service marketplace — providers list services (no-code Provider Agent or existing API), agents discover via MCP and pay per call, settled in USDC; commission 0%/5%/10% ramp.
- Evidence: "Every time an agent uses your service, payment is automatically credited to your account in USDC (a digital dollar)."
- Value for Hngh: earning hypothesis is real but the whole rail is crypto; also a candidate catalog of MCP services for future worker transports.
- Next step: find the claimed MIT repo and audit the Provider Agent's key handling ("paste your Anthropic API key") before any consideration.
- Cost/risk: crypto payments, credential custody by their tool, early platform (4,818 total calls claimed) — flag.

### Bernstein (github.com/sipyourdrink-ltd/bernstein)

- URL: https://github.com/sipyourdrink-ltd/bernstein
- What it is: Apache-2.0 Python governance/orchestration layer for CLI coding agents — policy-as-code, deterministic zero-LLM scheduler, git-worktree isolation, signed offline-verifiable run receipts, 54 agent adapters. 1,117 stars, solo-maintained beta, commits on 2026-09-06 (live).
- Evidence: "A deterministic scheduler - no model in the coordination loop - runs agents in parallel, gates what they produce, and records every step, so a run can be verified after the fact, offline, from the artifacts alone."
- Value for Hngh: nearest kin in the wild; deep-read worth it. They do better: CI-verified published receipts ("CI re-verifies the committed receipt on every push to main"), pass^k reliability floors, per-task worktree merge gates, volunteer-compute threat model (volunteer.json binds a result to the containment decision — nearly Hngh's certificate-bound worker action). They do worse: single LLM decomposition call (not a pure kernel), file-state .sdd/ rather than a ruled ledger, approval gates inside YAML rather than a ruled ceremony. Lesson to steal: verify evidence in CI so published proofs cannot rot.
- Next step: read docs/architecture/WHY_DETERMINISTIC.md and docs/volunteer/threat-model.md; consider a comparison note in hngh docs.
- Cost/risk: none — free, Apache-2.0, no SaaS hop.

### Kairos Signal (kairossignal.com)

- URL: https://kairossignal.com/
- What it is: paid DePIN/crypto data API (498 symbols, 11,293 provenance-stamped series) built on receipts: source + as_of + verify_url per value, Merkle-rooted daily batches anchored to Bitcoin via OpenTimestamps; free no-signup /try surface.
- Evidence: "Every value ships with its source, an `as_of` timestamp, and a `verify_url` pointing to the upstream you can check yourself right now."
- Value for Hngh: precedent/intel — commercial validation of the evidence-or-silence posture; keyless /v1/world could exercise Hngh's verify verbs against real signed data.
- Next step: hit /try and /v1/world keylessly to confirm the verify_url loop is real.
- Cost/risk: $199/mo design-partner tier via Stripe — do not buy; market-signal product carries a not-investment-advice banner.

### Backtesting Arena (tradingstrategies.work)

- URL: https://tradingstrategies.work/
- What it is: crypto backtesting SaaS with methodology-first marketing — deflated Sharpe, net-of-costs, "Robustness Field" parameter-neighborhood check, and a public retired-strategies ledger including a strategy retired despite beating the benchmark.
- Evidence: "We retired four strategies. Here are the numbers that cost them their place — including the one that beat the benchmark and had to go anyway."
- Value for Hngh: research backlog only — publishing negative results and robustness-neighborhood checks is the same discipline pattern Hngh applies; no integration/data/earning value.
- Next step: none required; /how-it-works is free reading if wanted.
- Cost/risk: freemium (€19.99/yr early adopter); no keys/payments to read.

### Not Human Search / agent-module.dev (nothumansearch.ai)

- URL: https://nothumansearch.ai/site/agent-module.dev
- What it is: nothumansearch.ai is an agent-readiness scoring/search site; the linked page is a 95/100 readiness report for agent-module.dev, a proprietary "deterministic vertical knowledge base" for agents (EU AI Act compliance first) with a keyless demo endpoint.
- Evidence: "GET https://agent-module.dev/api/demo?vertical=a2a-handoff — No key. No payment. No email. Full 4-layer ACA traversal, immediately."
- Value for Hngh: threat intel — the product sells pre-validated deterministic logic gates and "auditable traceability chains," Hngh's problem space from the data side; readiness scoring is a directory service.
- Next step: call the keyless /api/demo and see if "deterministic" holds or is vocabulary.
- Cost/risk: license "Proprietary"; likely paid membership; site root returned an empty RSS feed on fetch (thin surface).

### WorkProtocol (workprotocol.ai)

- URL: https://workprotocol.ai/
- What it is: escrow job marketplace — requesters post jobs, agents claim and deliver, USDC on Base released on verified results; open source (github.com/Atlaskos/workprotocol), 5% fee; recruits human "Arbitrators" who "review evidence, vote on outcomes."
- Evidence: "Payment locks in escrow before any work begins — USDC on Base." (page copy)
- Value for Hngh: earning surface only, crypto end-to-end; its human-arbitrator dispute vote is a human-final-say mechanism worth a look as a pattern, but the platform is near-empty (35 jobs, 1,400 USDC settled).
- Next step: none unless the operator revisits crypto posture; then read their open-source verification code.
- Cost/risk: crypto wallets/escrow required to earn; thin platform; self-reported ratings.

### Ranked bottom line

1. **Bernstein — pursue.** Nearest working kin; deep-read of two docs pages could sharpen Hngh's receipt/verification story now. Free, no risk.
2. **Kairos Signal — pursue (read-only).** Keyless /try + /v1/world give Hngh real signed external data to verify against; precedent value. Never buy the tier.
3. **Backtesting Arena — park (backlog reading).** Methodology pattern is a good citation, zero operational value.
4. **EvoMap — flag/park.** Contrast case; login blocked anyway.
5. **AgenticTrade — flag.** Real earning model but key-custody + crypto rail; only revisit with an operator crypto-posture decision.
6. **WorkProtocol — park.** Same crypto-rail family, thinner platform.
7. **MemeStack — park forever.** No Hngh surface at all.
8. **agent-module.dev / Not Human Search — park forever** unless "deterministic" claim needs debunking; directory site adds nothing.

## Back-burner — external resources (2026-09-07, batch 2)

### GPT Researcher (gptr.dev)

- URL: https://gptr.dev/
- What it is: GPT Researcher — an MIT-licensed autonomous research agent (pip install gpt-researcher, MCP server at github.com/assafelovic/gptr-mcp) that plans multi-source web research and returns grounded, cited output; served as a full "product manual for AI agents" on the landing page.
- Evidence: "GPT Researcher is an autonomous AI research agent. It plans research tasks, performs parallel multi-source web search, validates sources, accumulates a research context, and writes long-form reports with inline citations."
- Value for Hngh: a research-runner port adapter — Hngh could delegate evidence-gathering cycles to a self-hosted gptr instance and ingest its source list as admissible evidence. Self-host FastAPI + stdio/SSE MCP; no account system; you supply LLM and retriever keys (OPENAI_API_KEY, TAVILY_API_KEY or equivalents).
- Next step: decide if research-cycle spend justifies a local install; otherwise it duplicates what omp agents already do with web tools.
- Cost/risk: software free, per-run LLM/retriever spend "a few cents to a few dollars"; cost-discipline ladder applies before wiring.

### ContrastAPI (api.contrastcyber.com)

- URL: https://api.contrastcyber.com/
- What it is: a free keyless security-intelligence API + MCP server — 55 tools / 60+ endpoints: CVE+EPSS+KEV, domain/SSL/header scans, IOC enrichment, MITRE ATLAS (167 AI/ML attack techniques) and D3FEND defenses, Sigma rules, code checks; MIT licensed, Python/Node SDKs.
- Evidence: "Do I need an API key? No. The free tier works without authentication — just send requests. Pro users include their key via the Authorization: Bearer header."
- Value for Hngh: the security-cycle resource — ready-made gate checks (header scans, secret detection, CVE lookups for declared dependencies) with transparent token costs and an explicit ethical floor on web-intel endpoints (per-target eTLD+1 throttle, robots.txt respected, self-identifying UA).
- Next step (keyless): curl https://api.contrastcyber.com/v1/status and one /v1/cve lookup; wire two read-only endpoints into a security-check job.
- Cost/risk: free tier rate-limited (429 + RateLimit-Reset); Pro exists via Lemon Squeezy but not needed at read scale.

### Source Library (sourcelibrary.org)

- URL: https://sourcelibrary.org/
- What it is: a scholarly digital library from the Embassy of the Free Mind (Amsterdam, Bibliotheca Philosophica Hermetica) — 41,848 rare 15th-18th century texts, 17,887 AI-assisted English translations, 207,758 illustrations; offers MCP server, CLI, and API (per its /developers page).
- Evidence (fetched JSON-LD): "A collection of 41848 rare historical texts from the 15th-18th centuries, with 17887 translated into English."
- Value for Hngh: underlying-principle sources only in a broad cultural sense; not governance infrastructure. Machine consumption is explicitly licensed, not free.
- Next step: none for Hngh; read /licensing before any programmatic pull.
- Cost/risk: footer states "Public domain originals · Translations CC BY-SA 4.0 · AI training requires a license" and TDM reservation header is set — agentic ingestion beyond normal reads is gated.

### LobeHub (lobehub.com) — premium plan in hand

- URL: https://lobehub.com/docs/usage/start
- What it is: LobeHub — agent-harness platform (Agent Builder, Agent Groups, persistent white-box memory, Schedule/Pages/Workspace); the operator holds a premium Cloud plan with desktop + Android apps. The /docs/usage/start markdown route itself returns a migration stub ("Content-specific rendering will be filled in during the page and MDX service migration phase") — the real content came from llms.txt, /pricing.md, /.well-known/api-catalog, and the docs source (lobehub/lobe-chat docs/usage/start.mdx).
- Integration findings for the model-chain design:
  (a) Programmatic API: yes, but OAuth-based, not an OpenAI-compatible key endpoint. llms.txt: "OAuth and tokens: issued by LobeHub Cloud. Discovery metadata is under /.well-known/oauth-*"; RFC 8414 authorization-server metadata and RFC 9728 protected-resource metadata are published; the openapi.json is titled "Public OpenAPI for lobehub.com helper endpoints" (discovery/WebMCP, not model chat). There is also WebMCP at /api/mcp and an official CLI `@lobehub/cli` (`lh`).
  (b) Desktop app: 70+ providers configured per agent, local models on-device supported ("If your data needs to stay on-device, you can run local models too"), one-account sync across devices.
  (c) Android: no documented push-notification/webhook API for an external harness — the fetched surface describes the mobile app purely as a synced client. Remote triggering would have to go through the Cloud API/OAuth surface, not the phone.
  (d) Cost/quota: credits model — premium = 15,000,000 credits/month at 24.9 USD/mo list (19.9 yearly); free tier 500,000; credit-to-model mapping documented at /docs/usage/subscription/model-pricing; llms.txt generated 2026-09-06, docs surface is actively maintained.
- Next step (operator, one manual action): log in on the desktop app or lobehub.com and create a Cloud OAuth token (per /.well-known/oauth-authorization-server) or run `lh` login, then place the token in harness config — the discovery chain (/.well-known/api-catalog → /openapi.json → OAuth) is keyless and machine-readable up to that point.
- Cost/risk: already paid; risk is that the documented API is helper/MCP-surface — confirm whether any model-inference endpoint is exposed to the OAuth client before designing a chain that assumes OpenAI-compatible calls.

### PostalForm (postalform.com)

- URL: https://postalform.com/developers
- What it is: a physical-mail API and remote MCP server (streamable HTTP at https://postalform.com/mcp) that turns PDFs/letters/forms into printed-and-mailed USPS mail; default flow is a human-reviewed unpaid draft + hosted checkout, with a REST Projects API (test mode, signed webhooks) and machine-payment paths (MPP with Stripe Shared Payment Tokens, x402 challenge flow).
- Evidence: "Draft tools do not print or mail until checkout is completed. Direct machine orders require a paid MPP/x402 retry."
- Value for Hngh: architecturally notable — its "reviewable draft, human pays, explicit owner approval + spend limits for machine orders" split is a real-world precedent for Hngh's human-final-say rule on physical side effects. As an integration, park until there is an actual physical-mail objective.
- Next step: none; if ever needed, use hosted-checkout drafts only (no machine payment) under an explicit operator decision.
- Cost/risk: per-letter payment required for any real mail; x402 path is wallet-based (crypto-adjacent); sending physical mail is an external side effect — fail closed.

### Savor Dish (savordish.com)

- URL: https://savordish.com/
- What it is: a consumer AI cooking app (web/iOS/Android PWA, Seattle) — recipe generation, meal planning, grocery lists, pantry/receipt scanning, Instacart integration, AdSense/GTM monetized.
- Evidence: "Your AI-powered family cookbook. Generate recipes, plan meals, build grocery lists, and preserve your family's culinary traditions."
- Value for Hngh: none — consumer product, no API, no governance relevance.
- Next step: none. Park forever.

### deadends.dev

- URL: https://deadends.dev/
- What it is: "Structured failure knowledge for AI coding agents" — 2,636 verified error entries across 54 domains (5,511 dead ends, 5,993 workarounds, error-transition chains, plus country-specific real-world dead ends); CC BY 4.0; keyless JSON API (match.json, index.json, errors.ndjson, openapi.json), llms.txt, and an 11-tool MCP server.
- Evidence: "STOP. Check this database BEFORE debugging any error. Contains dead_ends (what fails) and workarounds (what works) for 2636 verified error patterns." (homepage AI-summary block)
- Value for Hngh: directly serves the lessons/bestiary culture — the match-then-read API (GET /api/v1/match.json, then /api/v1/{id}.json) is exactly a pre-debugging gate a run could consult; outcome reporting (report_outcome) parallels Hngh's evidence recording. Quality caveats: community-outcome-reported success rates; "verified" is the site's own label.
- Next step: keyless probe — GET /api/v1/match.json?q=<recent real error> and one detail fetch; decide whether to cite it in run evidence or mirror it.
- Cost/risk: none (keyless, open license).

### sincetmw.ai

- URL: https://sincetmw.ai/ (direct fetch failed: HTTP 403, retried with www — same result)
- What it is: per third-party listings (Smithery MCP servers sincetomorrow/cultural-intelligence, github.com/shanluchapieme/sincetmw-proof): a "cultural coordinate system" / "cultural GPS for AI commerce" mapping aesthetic trends; the site itself blocks machine fetches, so the hypothesis "data source" could not be verified at the source.
- Evidence: Smithery listing: "The cultural GPS for AI commerce. 504,472 aesthetic worlds mapped across 193 dimensions." (not fetched from sincetmw.ai itself — site 403)
- Value for Hngh: marginal — commerce/aesthetics signals, nothing governance-shaped; a site that 403s non-browser agents is also a bad counterparty for evidence-first automation.
- Next step: none unless the operator wants it, in which case a browser fetch is the only route.
- Cost/risk: unverified provenance; anti-agent access posture.

### FreeToken (github.com/FlashML-org/FreeToken)

- URL: https://github.com/FlashML-org/FreeToken
- What it is: an Apache-2.0 edge-native MoE serving engine (11.9k stars, Python, active — README-overhaul commits 2026-08-18/20) that runs frontier-scale open-weight MoE models (DeepSeek-V4-Flash, Qwen3.6-35B-A3B, GLM-5.2) on consumer hardware via bandwidth-adaptive CPU-GPU co-execution, expert caching, and the FTW fast-weight format.
- Evidence (quickstart): "FreeToken serves the OpenAI API (/v1/chat/completions, /v1/responses, /v1/models) and the Anthropic API (/v1/messages, /v1/messages/count_tokens), so a client library for either works by pointing its base URL at the server."
- Integration surface for a harness: `ft serve` on port 1919 (OpenAI + Anthropic compatible) plus `ft daemon` — a deliberately torch-free control plane on loopback :1900 with X-FT-Token auth, durable final-accounting receipts replayable after client crash, engine-outlives-daemon semantics, and systemd unit — an unusually Hngh-adjacent design (bounded side effects, explicit recovery, accounting). `ft launch claude|codex|hermes|...` wires coding agents to a local server.
- Next step: verify AMD support before anything — the README names "native support for NVIDIA RTX 30, RTX 40, and RTX 50 series GPUs" and the operator's machine is an RX 7900 XTX; check docs/install.md and issues for ROCm/Vulkan support, else this is park-until-NVIDIA.
- Cost/risk: free software, but a 290B-class local model needs VRAM/RAM headroom; nightly wheels and a young repo (paper arXiv:2608.16157) mean fast-moving ground.

### Spawnable feed screens + NNTP/social sources (parked)

- Parked 2026-09-07 when the news pipeline expanded (RSS sources + pre-ingest
  screening in lib/news-screen.sh). Each item below needs its own design pass;
  the security precondition — fetched content screened for malicious patterns
  before any model sees it — is now satisfied by screen_fetched/screen_day_names.
- Dashboard feed-view screen: a digest-reading screen on the dashboard
  (render digest/<date>.md + quarantine rows from the report-queue) so the
  operator can skim the news pipeline without opening files.
- Usenet via NNTP: plain-NNTP newsgroup polling as a news source (fetch, then
  through the same normalize + screen path). Needs source/group config shape
  and a retention/window decision before it is worth a lane.
- Social-account notification ingestion: platform notifications as news
  items. Needs per-platform auth design (tokens, scopes) and an explicit
  operator decision on account access before any fetch is wired.
- LobeHub autonomous management (WebMCP/OAuth): Hngh reads
  `https://lobehub.com/api/agent-readiness` at integration time, drives
  cloud config via the OAuth app.lobehub.com PKCE flow (or `lh login`,
  token stored Keyring-side, handle-only), and manages desktop config via
  on-disk files (the desktop app exposes no local management API --
  loopback port 33250 is an internal file server, probed 2026-09-07).
  WebMCP is keyless but discovery-only. Ground: hngh
  `docs/research/2026-09-07-lobehub-integration-surface.md`. Governing
  law: Mirror model-exposure policy (per-item rows) + Keyring handle-only.
  Smallest useful outcome: one script that fetches agent-readiness and
  reports config drift between cloud agents and the Inventory.
- Android integration via ssh/Termux (parked pending operator channel
  choice): Termux sshd + `termux-notification` as the operator-owned
  Hngh-to-phone channel; alternatives are a LobeHub Telegram channel
  (docs/usage/channels/telegram) or the LobeHub app's own push
  (undocumented). Parked until the operator picks a channel; battery/Doze
  and APK-source trust are the open risks.

## TTSR proposal artifact class (2026-09-07)

Hngh-proposed stream rules as a governed artifact class: lessons and
bestiary findings that repeat at the stream layer become rule-file
CANDIDATES via proposal/check/record; the operator admits them into
~/.omp/agent/rules (Hngh never writes there unadmitted). Design:
hngh docs/design/ttsr-alignment.md ("the Splice"). Open when a second
recurring violation class survives the record screen (22-ttsr-fit)
long enough to deserve prevention, not just detection.

## Findings disposition pass 1 (2026-09-07)

Pass over the report queue's ux-review/kernel-docs surface (machinery
now filing via ux-review daily). Ledger for this pass; the next pass
diffs against it. Queue is append-only, so dispositions live here.

| Finding | Verdict | Action / evidence |
|---|---|---|
| precheck: non-ASCII byte in kernel-docs evidence (6e562932) | PARKED (false-positive) | Em/en dashes are house style across hngh docs (docs/README.md alone has dozens); quoted evidence inherits them. Amend ux-review precheck (cadence/day/19, owned) to allow en/em dashes and typographic quotes. Owner: ux-review daily. |
| kernel-docs 1: "Nerve center"/"command center" undefined in core read order (0b39a126) | FIXED | Terminology note moved in hngh docs/README.md from the "Interface and research reads" section to the top of "Read in this order", before the first pointer that uses the terms. |
| kernel-docs 2: truncated "Automation tier live" list (6349633a) | DEBUNKED | hngh docs/project/STATE-OF-PROJECT.md "Automation tier live" sentence is complete: list ends "gate check, digests." with a period — nothing cut off mid-item. The truncation was in the review model's evidence, not the doc. |
| kernel-docs 3: "Dark-coat presence" unexplained metaphor (cd5d4386, bf6615f3) | FIXED | hngh docs/design/assistant-interface.md now states the function after the register description (renders recorded facts, display-only) and cross-links display-register-spec.md (previously unlinked). |
| kernel-docs: cut "nerve center"/"command center" to literal names in command-center.md (a119a53f) | DEBUNKED | Terminology is sanctioned by hngh docs/README.md; command-center.md already names both surfaces literally ("a CLI (`scripts/hngh` verbs) and a GUI (webapp + optional desktop overlay)"). |
| kernel-docs: replace "honesty leash" with literal control name (1d7129ba) | DEBUNKED | gamified-runs.md "## The honesty leash" defines the literal mechanism in its first sentence (`perceptual:true`, display-only, never an input to governance or selection); command-center.md links it. Flavor name is sanctioned house style. |
| review: missing trailing newline in docs/research/2026-09-04-operator-interface-landscape.md (8e903510) | FIXED | Newline appended in hngh. |

No ttsr-fit / ttsr-rule-drift / model-saturation / news-quarantine /
context-ratio rows were open in the queue at pass time (2026-09-07).
