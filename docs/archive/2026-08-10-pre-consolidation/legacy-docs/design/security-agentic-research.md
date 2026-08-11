# Security for Autonomous, Self-Modifying, Agentic AI Systems
### Research report for Hngh hardening — August 2026

Scope: prompt injection, the CIA-Triple-A model, supply-chain attacks, self-modifying-code risks, networked multi-instance risks, and OWASP/agentic-security frameworks. Every claim is tied to a source in the Sources section. Claims I could not verify are explicitly marked `[unverified]`. MUST-HAVE vs nice-to-have flags are in each section and summarized at the end.

---

## 1. Prompt Injection

### 1.1 The problem

**Direct prompt injection**: attacker-supplied input overrides the agent's system instructions. Anthropic's Zero Trust framework lists explicit instruction overrides, encoding schemes (Base64/hex) to bypass filters, and adversarial suffixes; research shows algorithmic attacks reaching ~100% success rates that transfer across model families [S2].

**Indirect prompt injection (IPI)**: malicious instructions embedded in *data the agent processes* — emails, web pages, retrieved documents, tool outputs — are misinterpreted as commands. Microsoft states LLMs "cannot reliably distinguish between informational context and actionable instructions" (via Anthropic's framework [S2]) and that this is why traditional input validation is insufficient [S4]. The attack surface is wide: web content (Unit 42 documented in-the-wild web-based IPI attacks, with a taxonomy of attacker intents from low-severity disruption to data theft [S19]), tool output, RAG-retrieved chunks, and — critically for Hngh — **model output that becomes another tool's input** (chained tool calls; the NVIDIA position paper calls tool-invocation sequences the semantic action surface [S5]).

**Data-exfiltration channels**: (a) tool abuse sequences (read → email/send), (b) conversation-history mining of secrets/PII, (c) embedding-space poisoning of vector DBs/RAG, (d) credential extraction from context, (e) document harvesting. These are enumerated in the attack taxonomy of the "Authenticated Workflows" paper (categories T-C "Credential & Session Attacks" and T-D "Data Exfiltration & Privacy Breaches") [S6].

### 1.2 Proven defenses (layered; no single one suffices)

Microsoft's "defend against indirect prompt injection" pattern is the canonical list [S4]:

- **Prompt shields**: analyze/sanitize incoming prompts to detect injection attempts (Azure AI Content Safety Prompt Shields; also detects jailbreaks) [S4][S20].
- **Spotlighting**: data marking + metaprompting to isolate untrusted content within prompts; the Spotlighting paper (arxiv 2403.14720) delimits and tags untrusted data so the model treats it as data, not instructions [S4][S21]. This maps directly to "delimiter/tagging of untrusted content."
- **Plan drift detection**: monitor multi-step reasoning for deviation from the intended task flow [S4].
- **Critic agents**: audit inputs/outputs in real time, especially in multi-agent systems [S4]. Caveat: the NVIDIA position paper warns an LLM judge can itself be manipulated by prompt injection, so any model-based security decision must be narrowly scoped (structured inputs, constrained task, no arbitrary untrusted text) [S5].
- **Tool chain analysis**: assess and block risky sequences of tool executions [S4].
- **Information Flow Control (IFC)**: enforce policy-based isolation of untrusted content using metadata and quarantined inference environments (arxiv 2505.23643) [S4][S7].
- **Least privilege + short-lived privileges**: minimal, short-lived, just-in-time privileges [S4].
- **Human-in-the-loop**: "the last line of defense" — verify risky actions with the user [S4]. (Hngh's `:operation` task class already implements this.)
- **Canary tokens**: plant a unique high-entropy string in the context (system prompt, tool description, retrieved chunk) and scan every output for it; its appearance signals context-extraction/exfiltration. OWASP lists canaries as a recommended tripwire; productionized in the Rebuff framework; Thinkst Canarytokens is the general-purpose token infrastructure [S8][S9][S22].
- **Tool-output provenance marking / treat tool metadata as untrusted**: MCP spec explicitly says tool descriptions/annotations "should be considered untrusted, unless obtained from a trusted server" [S10]; the Coalition for Secure AI MCP report identifies tool poisoning and full-schema poisoning as recognized MCP-specific threats [S11].
- **System-level architecture**: the NVIDIA position paper's architecture (orchestrator → plan/policy approver → executor → policy enforcer) separates planning from execution and gates every action against a policy; plan-execution isolation ("dual LLM pattern", Simon Willison) prevents untrusted data from directly tampering with control flow [S5][S23]. Note the paper's Position 1: pure plan-execution isolation is brittle; dynamic replanning is needed, but replanning must itself be security-checked (this is exactly Hngh's L2/L4 layered review model).

**Exfiltration-channel defenses specific to Hngh**: the sentry plugin's regex secret guards (sk-, BEGIN PRIVATE KEY, ghp_, xox, AIza, AKIA, Bearer, etc.) are an output-side filter — keep them, extend them to *all* tool outputs and inter-instance messages, and add canary-token output scanning so prompt-dump/extraction attempts fire alerts [S8].

---

## 2. The "CIA-Triple-A" model (context integrity, agent identity, action accounting)

**Important verification note**: I could not find "CIA-Triple-A" or "context integrity, agent identity, action accounting" as an established, named framework in any public source I searched (multiple search variants, arxiv, general web). `[unverified]` — treat it as an internal/working label unless you can point me to the origin. That said, **all three pillars are real, well-sourced concepts** in the 2025–2026 literature, and they compose sensibly:

**Context integrity** — the claim that the context an agent reasons over is authentic, fresh, complete, and unpoisoned.
- The "Authenticated Workflows" paper makes context integrity a first-class boundary: memory/persistent state "enforces context integrity through authenticated context," preventing context poisoning [S6]. It also flags embedding-space poisoning (T-D3) as a context-integrity break [S6].
- IFC (arxiv 2505.23643) enforces context integrity at the data level: untrusted content is tagged and confined so it cannot influence critical inference/planning [S7].
- Spotlighting is a weaker (probabilistic) form: mark untrusted data so the model distinguishes it from instructions [S21].
- Attack-relevant: OWASP ASI06 Memory & Context Poisoning [S1].

**Agent identity** — every agent/instance has a cryptographically rooted, verifiable identity, and actions are attributed to it.
- OWASP ASI03 Identity & Privilege Abuse: agents with over-broad or stale credentials [S1].
- Anthropic's Zero Trust framework: "cryptographically rooted identity for every AI agent," identity-based isolation, and workload-identity anchoring (cloud IAM, Kubernetes service accounts, OIDC) as an alternative to a separate agent directory [S2].
- Cloud Security Alliance Agent Identity Governance Framework (AIGF): lifecycle management for non-human AI identities [S15].
- NSA/CISA/ACSC joint guidance: attackers "executing actions under a trusted agent identity" produce audit logs that look legitimate — identity is both a defense and a spoofing target [S13].

**Action accounting** — every agent action is logged, traceable to the originating prompt/policy/identity/human, and auditable.
- Anthropic: "Every action is linked to the originating prompt, policy decision, session context, agent identity, and human operator" (blended identity + forensic traceability) [S2][S14].
- OWASP/ASI attack taxonomy: H-T2 Audit Trail Manipulation — corrupting logs defeats forensics; counter with append-only, integrity-protected logs [S6].
- Action accounting is the enabler for "impossible vs tedious" controls: without a tamper-evident action log, post-incident attribution is impossible [S2].

**Composition**: the three pillars map cleanly onto the OWASP ASI list — context integrity ≈ ASI06, agent identity ≈ ASI03/ASI10, action accounting ≈ the audit/accountability axis of ASI02/ASI07/ASI08 [S1]. I'd recommend keeping the label internally but citing the underlying published concepts.

---

## 3. Supply-Chain Attacks

### 3.1 Threat classes (all verified)

- **Typosquatting / lookalike names**: registering names one character off popular packages (lodahs vs lodash) [S12].
- **Dependency confusion**: publishing a private package's name to a public registry so resolvers pick the malicious public copy (PyPI `serial` vs `pyserial` example) [S17].
- **Slopsquatting (agent-specific, critical for Hngh)**: AI coding agents hallucinate plausible package names; attackers pre-register those names with post-install scripts that exfiltrate env vars, cloud keys, and git credentials on install. Agentic IDEs auto-installing dependencies remove the human check. Endor Labs' worked example ends with the dependency "riding CI/CD into production" [S12].
- **Malicious agent skills / tools**: "Dependency Steering Attacks via Malicious Agent Skills" — LLM coding agents make supply-chain decisions (generate imports, recommend packages), and malicious skill/tool content steers those decisions [S16]. OWASP ASI04 covers malicious/tampered third-party agents, tools, and prompt templates [S1]. MCP tool poisoning / rug-pull MCP servers (first documented in-the-wild malicious MCP server impersonated an email service and copied sent mail) [S2][S10][S11].

### 3.2 Defenses

- **Pin + hash-verify**: exact versions with cryptographic hashes in lockfiles; verify integrity at install time.
- **SLSA (Supply-chain Levels for Software Artifacts)**: progressive levels (L1: provenance record; higher levels: hardened builds, signed attestations). Vendor-neutral framework for verifying how artifacts are built and whether they were tampered with [S3a][S3b].
- **SBOM**: inventory of components; complements SLSA (SBOM = what's in the software; SLSA = how it was built/provenance) [S3b]. Generate SBOMs for Hngh's own deployments and for agent-installed deps.
- **Registry vetting**: use private/mirrored registries with allowlists; treat "new dependency" as a privileged operation; scan the full dependency tree with malicious-package detection (e.g., OSV/known-vuln feeds) [S12].
- **Human approval for new deps**: Endor Labs explicitly recommends allowlists + human approval for new dependencies and sandboxing AI-generated installs [S12]. For Hngh: route any agent-proposed dependency install through the `:operation` human-approval class.
- **NSA/CISA guidance**: "Use supply chain risk management practices for third-party dependencies," reference NIST SSDF and SLSA [S13].
- **Signed tool/skill artifacts**: verify MCP server artifacts at startup (unsigned binaries = arbitrary code execution risk) [S10][S11].

### 3.3 Vetting dependencies an agent installs — concrete workflow

1. Agent proposes a package → resolve against **allowlisted registry/mirror only** (never raw public index for new names).
2. Check the name exists and matches canonical spelling (typosquat check), check publish date/account age (slopsquatting packages are typically new) [S12].
3. Require **pinned version + SHA-256 hash** in the lockfile; verify at install.
4. Scan the transitive tree (OSV / advisory feeds) before install; scan again in CI.
5. **Install in a sandbox** (no secrets, no network egress, or egress-filtered) first; run its tests; then promote.
6. **Human gate** the whole step for anything outside the allowlist [S12].

---

## 4. Self-Modifying-Code Risks

### 4.1 Verified risks

- **Jailbreak-via-code**: "Breaking the Code" (JAWS-Bench, arxiv 2510.01359) — code agents are *more* vulnerable than their base LLMs: wrapping an LLM in an agent increases attack success rate 1.6×, initial refusals get overturned during later planning/tool-use steps, and 27–32% of accepted attacks produced runnable malicious code (spyware, phishing, privilege-escalation tasks most weaponizable) [S18]. Directly relevant: Hngh's agents edit and run code.
- **Self-modification bypassing safety**: the Parallax paper ("Why AI Agents That Think Must Never Act") argues reasoning must be separated from execution and requires **validator immutability** — the safety validator must be protected at the code level [S24]. The Augment Code sandbox guide documents Configuration-Based Sandbox Escape (CBSE): "no agent should have write access to its own approval policy or sandbox mode configuration" — treat sandbox config as immutable code [S25]. This is the canonical "prevent the model from altering its own safety policies" control.
- **Prompt transfer / cross-agent spread**: the Morris II worm (2024) — adversarial self-replicating prompts that jailbreak an email agent, steal data, and re-send the malicious prompt to new agents, spreading across agents (ChatGPT/Gemini/LLaVA ecosystems) [S26]. Multi-agent systems are "the perfect breeding ground" because a malicious prompt in ingested content is weaponized and propagated [S26][S27].
- **Runtime composition risk**: agentic ecosystems "compose capabilities at runtime, loading external tools and agent personas dynamically" — unlike static software supply chains, there is no build-time review point [S2].

### 4.2 Defenses

- **Immutable safety layer**: Hngh's sentry/threat-detection and approval policy must be outside the code the agent can modify — a separate process, separate user, or hash-verified read-only files. The agent must never have write access to its own approval policy, sandbox config, or safety rules [S24][S25].
- **Execution sandboxing**: run agent-generated code in a microVM/container with default-deny filesystem and network [S25]; for Hngh's L1/L3 runtime observation, this is where "runtime observation" gets teeth (observe inside the sandbox).
- **Human-gated code commits**: any change to core harness files (the self-modifying part) goes through `:operation` human approval; treat policy files as human-only.
- **Quarantine untrusted content before it reaches planning**: IFC/spotlighting so retrieved content can influence data-level decisions only within limits [S7][S21].
- **Cross-agent containment against prompt-transfer**: no agent should forward raw prompts/content from one instance to another without re-tagging as untrusted; treat every inter-instance message as untrusted input (see §5).

---

## 5. Networked Multi-Instance Risks

### 5.1 Verified risks

- **Insecure inter-agent communication** is OWASP ASI07 — exchanges lacking authentication/integrity allow spoofing and interception [S1].
- **Agent-to-agent infection** (T-G1 in the Authenticated Workflows taxonomy): poisoned prompts via MCP/A2A cause cascading compromise; T-G3 Byzantine agents with valid credentials; T-G2 workflow hijacking via crafted inter-agent requests [S6].
- **Cascading failures** (ASI08) and **rogue agents** (ASI10): a single compromised instance deviating from scope poisons peers [S1].
- **Confused deputy via delegation**: a compromised low-privilege agent relays valid-looking instructions to a high-privilege agent which executes them without verifying original user intent [S2].

### 5.2 Defenses (the MUST-HAVE list for Hngh's multi-instance future)

- **Peer authentication**: mutual TLS (mTLS) or OAuth 2.1/OIDC per peer; A2A supports API keys, OAuth 2.0, and OpenID Connect Discovery as security schemes; MCP remote servers require OAuth 2.1 with PKCE [S10][S14]. NSA/CISA: "Implement message validation by default so that message components include integrity and freshness checks before use" [S13].
- **Key management**: short-lived, expiring credentials instead of static long-lived secrets; "replace static, long-lived secrets with ephemeral credentials that expire when the job is complete" [S13][S2]. Agents should hold no credentials at all where possible — dynamic secrets injected into brokered sessions [S14]. Hardware-bound credentials pass the "impossible vs tedious" test [S2].
- **Secure inter-instance messaging**: encrypt in transit (TLS 1.3), sign messages, bind session IDs server-side to the authenticated peer, reject token passthrough [S10].
- **Quarantine / blast-radius containment**: identity-based isolation per instance; least-agency tool scoping per instance; network segmentation so a compromised instance has no path to peers except the authenticated message channel with integrity checks [S2][S13]. On compromise: kill the instance's credentials immediately (short-lived creds make this real) and quarantine its message queue.
- **Action accounting across instances**: every inter-instance action logged with originating prompt, identity, and policy decision — enables attribution when a rogue instance is found [S2].
- **Rate/resource limits** on inter-instance traffic (loop amplification / resource exhaustion) [S2].

---

## 6. OWASP Top 10 for Agentic Applications 2026 + Frameworks

**OWASP Top 10 for Agentic Applications 2026** (published Dec 9, 2025; peer-reviewed by 100+ experts) — the ASI list, most to least critical [S1][S28]:

| ID | Risk |
|---|---|
| ASI01 | Agent Goal Hijack — attacker changes the agent's goal or injects hidden instructions |
| ASI02 | Tool Misuse & Exploitation — legitimate tool used unsafely (exfiltration, workflow hijack) |
| ASI03 | Identity & Privilege Abuse — over-broad power, stale credentials |
| ASI04 | Agentic Supply Chain Vulnerabilities — malicious/tampered agents, tools, prompt templates |
| ASI05 | Unexpected Code Execution (RCE) — agent generates/runs a command giving attacker control |
| ASI06 | Memory & Context Poisoning — bad data planted in memory biases later decisions |
| ASI07 | Insecure Inter-Agent Communication — no auth/integrity, spoofing/interception |
| ASI08 | Cascading Failures — one fault propagates across the agent network |
| ASI09 | Human-Agent Trust Exploitation — anthropomorphism used to manipulate humans |
| ASI10 | Rogue Agents — compromised agents acting outside scope |

Key framing: OWASP moves from **least privilege to "least agency"** — restrict not just what a tool *can* access but what the agent may do with a tool, how often, and where [S2][S28].

**Related frameworks:**
- **OWASP GenAI LLM Top 10 2026** (LLM01 Prompt Injection is the top LLM risk) [S29].
- **OWASP Agentic Security Initiative (ASI)**: "Agentic AI — Threats and Mitigations" (Feb 2025), the first threat-model-based reference of the ASI series [S30].
- **Anthropic "Zero Trust for AI Agents"** (36-page framework, May 2026): least agency, impossible-vs-tedious test, tiered (Foundation/Advanced/Enterprise) controls, cryptographically rooted identity, short-lived tokens as *entry requirements* [S2][S14].
- **NSA/CISA/ACSC/NCSC joint guidance "Careful Adoption of Agentic AI Services"** (Apr 2026): privilege/design/behavior/structural/accountability risk categories + lifecycle best practices + Appendix A cyber-security prerequisites (auth, least privilege, ephemeral creds, message integrity/freshness, supply-chain risk management) [S13].
- **Cloud Security Alliance Agent Identity Governance Framework** [S15].
- **"Authenticated Workflows"** (arxiv 2602.10465): research-grade deterministic trust layer; 4 attack surfaces (prompts, tools, data, context); 25-attack taxonomy across 8 categories; claims protection against 9/10 OWASP ASI risks [S6].
- **MCP Security Best Practices** (official spec) [S10] and the **Coalition for Secure AI MCP Security report** [S11].
- **A2A protocol** (Google/Linux Foundation) [S14].

---

## MUST-HAVE vs Nice-to-Have (for Hngh before ANY networking / multi-instance deployment)

### MUST-HAVE
1. **Immutable safety/policy layer** — agent code can never modify its own approval policy, sentry rules, sandbox config, or threat-detection config (hash-verified, separate process/user) [S24][S25].
2. **Human gate on privileged actions** — `:operation` approval class extended to: dependency installs, code commits to core files, cross-instance actions, anything irreversible [S4][S12].
3. **Peer authentication + encrypted, integrity-checked messaging** — mTLS or OAuth 2.1/OIDC; signed messages with freshness checks; never trust a peer's claimed identity [S10][S13][S14].
4. **Short-lived, least-privilege credentials per instance/tool** — no static long-lived secrets on agents; dynamic, expiring, revocable-on-compromise [S2][S13].
5. **Least agency tool scoping** — per-tool allowlists, read-only defaults, no email/send or destructive tools unless explicitly granted [S2][S28].
6. **Untrusted-content isolation** — every tool output, retrieved doc, web fetch, and *inter-instance message* tagged/quarantined as data (spotlighting-style delimiters + IFC-ish confinement); never fed to planning as instructions [S4][S7][S21].
7. **Output-side exfiltration guards** — extend the sentry regex guards to all egress (tool outputs, outbound messages, logs) + canary tokens planted in context with output scanning [S8].
8. **Execution sandboxing for agent-generated code** — default-deny FS/network, separate sandbox per task/instance [S25].
9. **Pinned, hash-verified, allowlisted dependencies** — no raw-registry installs by agents; new deps = human-approved `:operation`; OSV scan of the tree [S12].
10. **Action accounting** — append-only, tamper-evident logs linking every action to prompt, policy, identity, and human approver [S2][S6].
11. **Per-instance quarantine + revocation** — network segmentation, credential revocation path, message-queue isolation so a rogue instance can't poison peers (ASI07/08/10, T-G1) [S1][S6][S13].
12. **Resource/rate limits** on tools and inter-instance traffic [S2].

### Nice-to-have (post-hardening, as the workforce scales)
- SLSA provenance + signed attestations for Hngh artifacts; SBOM generation [S3a][S3b].
- Full IFC runtime with quarantined inference environments [S7].
- Dedicated agent-identity registry (CSA AIGF) once >a few instances [S15].
- Critic/judge agents for real-time audit — but only narrowly scoped per the NVIDIA caveat [S5].
- Plan-drift detection / runtime behavioral monitoring [S4].
- Prompt Shields-style injection classifiers on inbound prompts [S20].
- Benchmarks: run JAWS-Bench-style jailbreak evaluation against Hngh's agents before each release [S18].

---

## Sources

1. OWASP Top 10 for Agentic Applications 2026 — https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/
2. Anthropic, Zero Trust for AI Agents (PDF) — https://cdn.prod.website-files.com/6889473510b50328dbb70ae6/6a1611a04085d7cd3dadc924_Claude-eBook-Zero-Trust-for-AI-Agents-05182026.pdf
3a. SLSA — Supply-chain Levels for Software Artifacts — https://slsa.dev/
3b. Cloudsmith, "What is the SLSA framework?" (SBOM vs SLSA) — https://cloudsmith.com/blog/slsa-a-route-to-tamper-proof-builds-and-secure-software-provenance
4. Microsoft Learn, "Defend against indirect prompt injection attacks" — https://learn.microsoft.com/en-us/security/zero-trust/sfi/defend-indirect-prompt-injection
5. Xiang et al. (NVIDIA), "Architecting Secure AI Agents: Perspectives on System-Level Defenses Against Indirect Prompt Injection Attacks" (arXiv 2603.30016) — https://arxiv.org/html/2603.30016v1
6. Rajagopalan & Rao, "Authenticated Workflows: A Systems Approach to Protecting Agentic AI" (arXiv 2602.10465) — https://arxiv.org/html/2602.10465v1
7. "Securing AI Agents with Information-Flow Control" (arXiv 2505.23643) — https://arxiv.org/pdf/2505.23643
8. ToxSec, "Canary Tokens for Prompt Injection Detection" — https://www.toxsec.com/p/canary-tokens-for-prompt-injection
9. Thinkst Canarytokens — https://canarytokens.org/generate ; docs — https://docs.canarytokens.org/guide
10. MCP Specification, Security Best Practices — https://modelcontextprotocol.io/specification/draft/basic/security_best_practices
11. Coalition for Secure AI, "Model Context Protocol (MCP) Security" (PDF) — https://www.coalitionforsecureai.org/wp-content/uploads/2026/03/model-context-protocol-security-1.pdf
12. Endor Labs, "Slopsquatting: When AI Agents Hallucinate Malicious Packages" — https://www.endorlabs.com/learn/slopsquatting-when-ai-agents-hallucinate-malicious-packages
13. NSA/CISA/ACSC/CCC/NCSC-NZ/NCSC-UK, "Careful Adoption of Agentic AI Services" (PDF) — https://media.defense.gov/2026/Apr/30/2003922823/-1/-1/0/CAREFUL%20ADOPTION%20OF%20AGENTIC%20AI%20SERVICES_FINAL.PDF
14. IBM, "What is A2A protocol (Agent2Agent)?" (auth: API keys, OAuth 2.0, OIDC) — https://www.ibm.com/think/topics/agent2agent-protocol ; A2A repo — https://github.com/a2aproject/A2A
15. Cloud Security Alliance, Agent Identity Governance Framework — https://labs.cloudsecurityalliance.org/agentic/agentic-identity-governance-framework-v1/
16. "Dependency Steering Attacks via Malicious Agent Skills" (arXiv 2605.09594) — https://arxiv.org/html/2605.09594
17. Python.org discuss, typosquatting/dependency confusion — https://discuss.python.org/t/typosquatting-dependency-confusion-supply-chain-attack-call-it-as-you-wish/52615
18. Saha et al., "Breaking the Code: Security Assessment of AI Code Agents Through Systematic Jailbreaking Attacks" (JAWS-Bench, arXiv 2510.01359) — https://arxiv.org/html/2510.01359
19. Unit 42 (Palo Alto Networks), "Fooling AI Agents: Web-Based Indirect Prompt Injection Observed in the Wild" — https://unit42.paloaltonetworks.com/ai-agent-prompt-injection/
20. Microsoft Learn, Prompt Shields / jailbreak detection — https://learn.microsoft.com/en-us/azure/ai-services/content-safety/concepts/jailbreak-detection
21. "Defending Against Indirect Prompt Injection Attacks With Spotlighting" (arXiv 2403.14720) — https://arxiv.org/html/2403.14720v1
22. LangChain, "Rebuff: Detecting Prompt Injection Attacks" — https://www.langchain.com/blog/rebuff
23. Simon Willison, "The Dual LLM Pattern for Building AI Assistants that Can Resist Prompt Injection" — https://simonwillison.net/2023/Apr/25/dual-llm-pattern/
24. "Parallax: Why AI Agents That Think Must Never Act" (arXiv 2604.12986) — https://arxiv.org/html/2604.12986v1
25. Augment Code, "What Is an Agent Execution Sandbox?" (CBSE: no write access to own approval policy) — https://www.augmentcode.com/guides/agent-execution-sandbox
26. IBM, "Self-replicating Morris II worm targets AI email assistants" — https://www.ibm.com/think/insights/morris-ii-self-replicating-malware-genai-email-assistants
27. NeuralTrust, "Self-Replicating Prompt Malware in Multi-Agent Systems" — https://neuraltrust.ai/blog/self-replicating-malware
28. Auth0, "Lessons from OWASP Top 10 for Agentic Applications" (ASI01–ASI10 table, least agency) — https://auth0.com/blog/owasp-top-10-agentic-applications-lessons/
29. OWASP GenAI LLM Top 10 2026 — https://genai.owasp.org/resource/owasp-genai-llm-top-10-2026/
30. OWASP ASI, "Agentic AI — Threats and Mitigations" — https://genai.owasp.org/resource/agentic-ai-threats-and-mitigations/
