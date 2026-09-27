# procedurally routed oh-my-pi sessions on billion-context-customized local models -- what supervision loop lets sessions compose and launch sessions safely?

Status: crystallized 2026-09-27 from research line `arc-20260926-omp-session-meta-cycle`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260926-omp-session-meta-cycle.md.

# Research Line — Final Contracted Record

**Line:** procedurally routed oh-my-pi sessions on billion-context-customized local models — what supervision loop lets sessions compose and launch sessions safely?
**Final state:** contracted (crystallized). This document is the line's lasting record.

**Verification status (carried forward, unchanged):** This line was produced without live read access to the repository trees. The only filesystem paths asserted below are those supplied directly in the prompts: `research-lines.tsv` (line state) and `[redacted path] (the hngh kernel repository). All vault notes are cited as read-only prior-art pointers by title. Every claim that depends on a file I could not confirm is flagged as such rather than asserted. External factual claims that could not be verified are marked **[unverified]**.

---

## Findings

**F1. The supervision loop's correct primitive is pre-launch gating, not post-hoc auditing.**
A session that can compose and launch other sessions cannot be made safe by inspecting what it did; safety requires a chokepoint that runs *before* any launch. Grounded in `[[sources/obs-2026-08-24-omp-context-via-billion-context-proxy-hngh-attestation-desig]]`, which frames attestation as a design primitive for the hngh billion-context proxy pattern — the parent retains supervisory authority while delegating execution.

**F2. Composability must be bounded by distillation capacity, not storage capacity.**
Billion-context models are tractable only through distillation (`[[concepts/context-distillation]]`, `[[concepts/billion-context-tuning]]`). Therefore a composition of sessions is valid only if the *combined distilled context* of parent and children fits the model's operational envelope. "Compose nothing that cannot be distilled" is the invariant.

**F3. Authorization and launch validity are separable concerns, and the line converged on splitting them.**
"Who may launch" (authorization rules) belongs to governance (`[[concepts/governance-models]]`); "what may be launched" (launch spec schema) belongs to the enforcement gate. Conflating them produces policy that is neither auditable nor enforceable.

**F4. The hngh kernel is the natural home for normative policy; the automation layer holds enforcement machinery.**
The hngh kernel repository at `[redacted path] is the appropriate location for the normative policy definitions (it is the kernel). The procedural router in the automation layer enforces them. **[unconfirmed]** The specific module/filename of the router and the existing spec/config layout in either repository were never verified against the live tree.

---

## Recommendations (final form)

**R1. Attestation as a launch gate.** Every session launch passes a single chokepoint function in the router, which verifies a signed claim set: context budget, routing policy, permitted child-launch depth. Failed verification ⇒ refused launch. If multiple spawn paths exist today, consolidating them is prerequisite work. **[unconfirmed]** whether such consolidation is needed — the spawn-path inventory was never read.

**R2. Distillation budget as a composability invariant.** Each session descriptor carries a `distilled_context_digest` plus an explicit budget field; the R1 gate sums budgets across the proposed composition tree and rejects overflow. The threshold **must** come from real capacity figures for the deployed local model (prior beat referenced `unsloth:unsloth/Ornith-1.0-9B-GGUF`) — from the model card or local benchmarks. **[unverified]** Do not hardcode a guessed envelope.

**R3. Two-part policy layer.** Authorization rule set (governance-defined, kernel-hosted) distinct from launch spec schema (gate-enforced, automation-hosted). The prior beat mapped `[[concepts/governance-models]]` onto exactly this separation.

---

## Open Threads (handed off, not resolved)

1. **Tree-mapping pass.** Map R1–R3 onto real files: locate the spawn/router module(s) in the automation layer and the spec/config layout in `[redacted path] This is the single highest-value follow-up; every recommendation above is currently anchored to intent, not to code.
2. **Operational-envelope measurement.** Obtain actual capacity figures for the deployed model before wiring the R2 budget check.
3. **Claim-signing mechanism.** R1 presumes "signed" claims; the line never resolved what signs them (kernel key, per-session key, or hash-chain attestation). Design needed.
4. **Evidence lifecycle integration.** `[[sources/ainglish-org-evidence-lifecycle]]` was cited as prior art for evidence-first lifecycles but was never integrated into the supervision-loop design; whether attestations should flow through that lifecycle remains open.
5. **Governance metrics.** `[[sources/SRC-2026-08-24-033]]` (CHAOSS metrics models) was listed as prior art but not exercised; if the authorization rule set needs measurable review responsiveness, that source is the untapped starting point.

---

## References

Filesystem paths asserted (supplied in prompts; not independently re-verified):
- `research-lines.tsv` — research line state file
- `[redacted path] — hngh kernel repository

Vault prior art (read-only pointers, llm-wiki vault):
- `[[concepts/billion-context-tuning]]` (created 2026-08-24)
- `[[concepts/context-distillation]]` (created 2026-08-18)
- `[[concepts/governance-models]]` (created 2026-08-24)
- `[[sources/obs-2026-08-24-omp-context-via-billion-context-proxy-hngh-attestation-desig]]` (created 2026-08-24)
- `[[sources/SRC-2026-08-24-033]]` — CHAOSS Metrics Models (listed; not exercised)
- `[[sources/ainglish-org-evidence-lifecycle]]` — evidence-first proposal lifecycle (listed; not integrated)

Model reference (unverified against a model card):
- `unsloth:unsloth/Ornith-1.0-9B-GGUF` — deployed local model referenced in the prior beat

**Line closed: contracted.** Open threads 1–5 are the seed material should this line be re-opened; thread 1 (tree-mapping) is the required first action.
