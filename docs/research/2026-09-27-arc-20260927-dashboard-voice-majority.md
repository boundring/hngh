# How should newspaper composition reach the operator's voice-majority target (>=60% system/operator/research/hngh articles)?

Status: crystallized 2026-09-27 from research line `arc-20260927-dashboard-voice-majority`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-arc-20260927-dashboard-voice-majority.md.

# Research Line Final Record

**Line:** How should newspaper composition reach the operator's voice-majority target (>=60% system/operator/research/hngh articles)?

**State:** contracting → **finalized**

**Date:** 2026-09-27

**Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF

**Wall clock:** 28.0s

---

## Findings

### Finding 1: The research-lines-tsv schema is intentionally decoupled from composition logic.

The schema tracks lifecycle state (`line state`, `prior material`, `current lifecycle state`) but contains no fields for article-type distribution or voice-majority tracking. This is not a schema deficiency—it is a deliberate separation of concerns. The composition logic belongs in a layer that reads from the research-lines-tsv output, classifies articles by type, and enforces the >=60% operator-voice target independently.

**Grounding:** The prior material on this line explicitly states: "the research-lines-tsv schema tracks lifecycle state (`line state`, `prior material`, `current lifecycle state`) but has no fields for article-type distribution or voice-majority tracking. This is not a bug—it's a feature of the schema's purpose."

### Finding 2: Composition drift follows the same failure mode as scroll behavior drift.

The prior research lesson on scroll behavior drift (`[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`) establishes that drift accumulation is a known failure mode in this system. Composition drift—where operator-voice drops below 60% over consecutive transitions—follows the same pattern: it is cumulative, not instantaneous, and requires continuous monitoring rather than one-time gates.

**Grounding:** The prior material on this line references: "The prior material on scroll behavior drift (`[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`) establishes that drift accumulation is a known failure mode. Composition drift follows the same pattern."

### Finding 3: The composition layer must exist as a distinct module between research-line output and newspaper publication.

Three concrete recommendations were crystallized during this transition:

1. **Composition as a composition-layer concern** — A `composition-checker` module sits between research-line output and newspaper publication, classifying articles by type tag, computing operator-voice percentage, and approving or rejecting composition for publication.

2. **Observability fields in research-lines-tsv** — Optional fields (`article-type`, `composition-checkpoint`, `voice-majority`) added to research-lines-tsv for observability without contaminating the research-line state machine.

3. **Drift detection as a continuous signal** — Monitoring runs on every research-line transition, not just at publication time. If operator-voice drops below 60% for N consecutive transitions, the system alerts and optionally triggers rebalancing.

**Grounding:** These recommendations were produced during the contracting transition of this line and are grounded in the prior material's analysis of the research-lines-tsv schema and the scroll behavior drift research lesson.

---

## Recommendations

### Recommendation 1: Implement composition-checker as a post-processing module in hngh-automation.

**Action:** When hngh-automation produces articles, tag each article with its type (system/operator/research/hngh) and pass them through the composition-checker before inclusion in the newspaper.

**Rationale:** This enforces the >=60% operator-voice target as a hard gate rather than a soft metric.

### Recommendation 2: Extend research-lines-tsv schema with composition-checkpoint fields.

**Action:** Add optional fields to research-lines-tsv: `article-type`, `composition-checkpoint` (timestamp of last composition check), and `voice-majority` (percentage at last check). Version this change and document it in schema migration notes.

**Rationale:** Observability belongs at the data layer. These fields make composition drift observable without contaminating the research-line state machine.

### Recommendation 3: Run drift detection at every transition boundary.

**Action:** Since the continuous research process runs on idle hosts, composition monitoring should be lightweight enough to run in the background of each transition. The drift-detection mechanism should check composition at each transition boundary, not mid-transition.

**Rationale:** Drift accumulation is a known failure mode (per `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]`). Continuous monitoring at transition boundaries catches drift before it becomes systemic.

---

## Open Threads

### Open Thread 1: Article-type classification criteria are undefined.

The target specifies >=60% system/operator/research/hngh articles, but the classification criteria for each type are not defined in the prior material. For hngh-automation, this means we need clear tagging conventions for article types before the composition-checker can function.

**Status:** Unresolved. Requires hngh-automation to define and document article-type tagging conventions.

### Open Thread 2: The N-consecutive-transitions threshold for drift alerting is undefined.

The recommendation states "if operator-voice drops below 60% for N consecutive transitions, the system should alert," but N is not specified. This is a tunable parameter that should be calibrated based on observed drift patterns.

**Status:** Unresolved. Requires empirical calibration.

### Open Thread 3: hngh kernel repository schema migration path.

The recommendation to extend research-lines-tsv schema should be versioned and documented in the schema migration notes within the hngh kernel repository. The exact file path for schema migration notes in the kernel repository is not confirmed from prior material.

**Status:** Pending. Requires confirmation of the kernel repository's schema migration documentation structure.

---

## References

- `research-lines.tsv` — The schema under analysis for this research line.
- `[[sources/LES-fail-20260915-If-drift-is-confirmed-in-the-scroll-beha]]` — Prior research lesson establishing drift accumulation as a known failure mode.
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Prior research lesson on hngh-automation observability.
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Prior research lesson on research-lines-tsv schema scope.
- `[[concepts/clean-architecture]]` — Clean Architecture for Agent Systems, referenced for the composition-layer separation principle.
- `[[sources/chartlibrary-io-developers-api]]` — External chartlibrary.io API reference (not directly relevant to this line).

**Note:** The hngh kernel repository at `[redacted path] is referenced as the ground for schema changes, but specific file paths within that repository (e.g., schema migration notes location) could not be verified from prior material. Claims about kernel repository structure are therefore asserted as pending confirmation rather than as established fact.

---

**Line closed.** This research line has been crystallized into its final structured record. Any future work on newspaper composition voice-majority should reference this line's findings and open threads.
