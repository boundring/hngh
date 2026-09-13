# Does the `hngh` kernel's component registry support machine-readable generation from source code, and if so, can a lint check validate literal sources against this generated artifact without manual maintenance?

Status: crystallized 2026-09-13 from research line `fail-20260913-Does-the-hngh-kernel-s-component-registr`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Does-the-hngh-kernel-s-component-registr.md.

# Research Line Crystallization — Final Record

**Line:** Does the `hngh` kernel's component registry support machine-readable generation from source code, and if so, can a lint check validate literal sources against this generated artifact without manual maintenance?
**State:** expanding → **contracted** (this beat)
**Applicability target:** hngh / hngh-automation

---

## Verdict on the Line's Question

**Partially answered — the line splits into two claims, one confirmed and one unconfirmed.**

1. **Confirmed:** A machine-readable generation step exists in the pipeline. The Hngh Component Map is auto-generated from `meta/registry.json` and carries the explicit policy *"Do not edit manually"* (SRC-2026-08-24-027). This establishes that the registry is treated as an authoritative artifact from which derived documents are produced mechanically.

2. **Unconfirmed:** Whether `meta/registry.json` itself is generated *from source code* or hand-maintained. No generator script, CI workflow, or schema file has been verified at any path under `/home/bricker/Projects/etc/hngh`. This is the gating fact for the lint-check half of the question, and it could not be resolved from the available material.

3. **Conditionally established:** A no-manual-maintenance lint check is *feasible by construction* — regenerate-and-diff in CI — but its concrete design depends on properties of a generator whose existence is not yet confirmed.

---

## Findings

### F1 — Confirmed: registry → Component Map generation exists
SRC-2026-08-24-027 attests the Component Map is auto-generated from `meta/registry.json`. The one file path citable with confidence is `meta/registry.json` within the hngh kernel repository. The generation direction implies `registry.json` is the upstream source of truth for at least one consumer.

### F2 — Unconfirmed: source → registry generation
No evidence was obtained for or against a generator producing `meta/registry.json` from source code. Candidate shapes (a script under a tools directory, a CI workflow, a build-system rule) are search targets only, not facts. I could not inspect `/home/bricker/Projects/etc/hngh` directly during this line's execution; this gap is recorded honestly rather than papered over.

### F3 — Conditional: lint design is well-formed regardless
The regenerate-and-diff pattern requires no invention — it is standard practice for generated artifacts — but its error quality depends on two generator properties: **determinism** (stable key order, no embedded timestamps) and **source-location metadata** (file/line fields per registry entry). Neither property is verified. I note explicitly that the claim "regenerate-and-diff is standard practice" is an external-source claim I did not verify against literature during this line; it is asserted as engineering common knowledge, not as a cited finding.

### F4 — Independent: schema validation is unconditionally available
A JSON Schema gate on `meta/registry.json` catches structural drift even if content-drift gating is blocked on F2. Whether such a schema already exists in the kernel repository is unverified.

---

## Recommendations (lasting record)

- **R1 — Resolve F2 first.** A single repository-wide search for references to `registry.json` across source, scripts, and build configuration confirms or refutes the generator. This is the highest-leverage next action; every downstream recommendation branches on it.
- **R2 — If R1 is positive:** implement the lint check as regenerate-to-temp → normalize (e.g., stable key ordering) → diff → fail on non-empty diff. Verify determinism by running the generator twice before wiring CI.
- **R3 — If R1 is negative:** reframe the line's deliverable as *introducing* a generator with source-location metadata, then apply R2. The research question's premise is then answered "not yet, but the path is short."
- **R4 — Unconditionally:** add (or locate) a JSON Schema for `meta/registry.json` and validate it in CI as a structural floor independent of R1's outcome.
- **R5 — Documentation hygiene:** wherever the Component Map's "Do not edit manually" banner lives, add a pointer to the generation command so the check is discoverable. I cannot verify whether such a pointer already exists.

---

## Open Threads (handed forward)

1. **OT-1 (blocking):** Does a generator produce `meta/registry.json` from source? — single search command, unresolved.
2. **OT-2 (conditional on OT-1 positive):** Is the generator deterministic across runs? — run twice, diff.
3. **OT-3 (conditional on OT-1 positive):** Do registry entries carry `source_path`/`line` metadata? — determines lint error actionability.
4. **OT-4 (independent):** Does a JSON Schema for the registry already exist in the kernel repository?

---

## Lifecycle Note

This line is contracted, not closed. OT-1 is a one-command resolution; if an idle host gains shell access to `/home/bricker/Projects/etc/hngh`, this line can be reopened and settled in a single beat. Until then, the honest terminal state is: **one generation stage confirmed, the decisive one unverified, and a ready-to-execute plan for both outcomes.**

## References

- `meta/registry.json` — hngh kernel repository (`/home/bricker/Projects/etc/hngh`); cited with confidence as the registry's canonical path per SRC-2026-08-24-027.
- `[[sources/SRC-2026-08-24-027]]` — Hngh Component Map (llm-wiki vault); source of the "Auto-generated from meta/registry.json. Do not edit manually." attestation.
- `[[entities/hngh]]` — Hngh Agent Kernel (llm-wiki vault).
- `[[concepts/clean-architecture-for-machine-intelligences]]` — architectural framing (llm-wiki vault).
- `[[sources/SRC-2026-08-24-006]]` — SLSA Supply Chain Levels (llm-wiki vault); adjacent supply-chain context, not directly load-bearing here.
- `[[concepts/moment-of-action-freshness]]` — attestation freshness recheck (llm-wiki vault); conceptually related to regenerate-and-diff validation.

*Unverifiable-claim disclosures: (a) no paths under the hngh repository other than `meta/registry.json` are asserted; (b) the characterization of regenerate-and-diff as standard CI practice is unreferenced engineering common knowledge; (c) determinism and metadata properties of any generator are hypothesized, not observed.*
