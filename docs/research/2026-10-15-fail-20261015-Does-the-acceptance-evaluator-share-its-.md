# Does the acceptance evaluator share its Verification-scan logic with the research-lines.tsv parser implicated in LES-fail-20260915, such that one schema-version guard (R5) would cover both failure classes?

Status: crystallized 2026-10-15 from research line `fail-20261015-Does-the-acceptance-evaluator-share-its-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261015-Does-the-acceptance-evaluator-share-its-.md.

# research-lines.tsv — Line Contraction: Final Structured Record

**Line:** Does the acceptance evaluator share its Verification-scan logic with the research-lines.tsv parser implicated in LES-fail-20260915, such that one schema-version guard (R5) would cover both failure classes?

**State:** `contracting` → `final_record`. In motion on idle hosts; no batching.

**Date:** 2026-10-15

---

## 1. Findings

### 1.1 What is established

- The prior beat's core uncertainty — *whether the acceptance evaluator's Verification-scan and the research-lines.tsv parser share a code path* — **remains unresolved**. This is not a finding that can be asserted; it is a boundary condition that must be verified by direct code inspection.
- `hngh-2026-09-09-stall-lessons` lists "acceptance parsing" as a **distinct stall category** from the research-lines parsing failures. This is the only prior material that hints at independence between the two code paths, but it does not prove it.
- `research-lines.tsv` itself is the declared line-state file for this research line. Its existence and role as the tracking artifact are verifiable from the prior beat's own metadata.

### 1.2 What is not established (and cannot be)

- **No verified read access** into the hngh kernel repository (`[redacted path] or the hngh-automation source tree was obtained during this transition. Every file-path-level claim about internal code structure below is therefore **unverified**.
- The prior beat's recommendations (R5-a through R5-e) were produced under this constraint and are framed as design intent, not as assertions about existing code.
- The prior beat's test-file-path claims (R5-e) were truncated at 4000 bytes and remain unverified.

### 1.3 The conditional that governs this line

| Condition | Consequence |
|---|---|
| Shared schema-handling module exists | One R5 guard placed in that module covers both failure classes. Cost: refactor to expose the shared module. |
| Independent implementations (hinted by stall-lessons) | R5 as duplicated literals in two places is an anti-solution: drift creates a third failure class. Cost: create a shared module. |

**In both cases, the recommendation is the same:** R5 must exist exactly once as a shared, importable predicate. The trace (Angle 1 of the prior beat) decides how much refactoring that costs, not whether to do it.

---

## 2. Recommendations

These are concrete in design intent. File-path-level claims are flagged as unverified.

### R5-a. Define R5 as a single exported predicate

One function (or class method) that takes parsed-header/schema metadata and returns allow/deny plus a structured reason. Both the acceptance evaluator's Verification-scan entry point and the research-lines.tsv parser import it. If the current code has no shared module, create one. The guard's value is precisely that it is a single source of truth.

**Unverified target path:** Place it wherever both components can import without a dependency cycle in hngh-automation.

### R5-b. Fail closed on unknown schema versions

LES-fail-20260915 and the mid-line verification-block pattern both point at parsers that accepted input they only partially understood and then wedged downstream. R5 should *reject* (or quarantine) any schema version it does not explicitly recognize — never pass-through on the assumption that a newer version is compatible. An unknown version is a stop condition, not a warning.

### R5-c. Compare versions structurally, not by string equality

Version guards that compare raw strings (`"1.10" < "1.9"`) are a classic latent bug. R5 should parse the version into comparable components. If hngh-automation already has a version-comparison utility, reuse it; otherwise implement the comparison inside R5 itself so no caller can get it wrong.

### R5-d. Emit a structured, intake-ready error when the guard trips

Per the crowdsourced-failure-intake concept, a guard that fails silently or with an ad-hoc string wastes the failure signal. On deny, R5 should produce a machine-readable record: component (acceptance-evaluator vs. research-lines parser), expected version(s), observed version, and a stable failure-class tag. This lets future LES-fail-style incidents be aggregated rather than rediscovered.

### R5-e. Regression-test both failure classes against the one guard

Add two tests: one reproducing the LES-fail-20260915 failure mode, one reproducing the mid-line verification-block pattern. Both tests assert that the single R5 guard denies the bad input.

**Unverified test file paths:** The prior beat's truncated output did not include concrete paths. These must be placed in hngh-automation's test tree where both components are exercised.

---

## 3. Open Threads

1. **Shared-code-path verification.** This is the line's primary open thread. It requires direct read access into hngh-automation's source tree to determine whether Verification-scan and the research-lines.tsv parser share a module. Until that is verified, the R5 recommendations remain conditional.

2. **hngh-automation dependency cycle analysis.** If a shared R5 module is created, it must not introduce a circular import. This requires mapping the import graph of both the acceptance evaluator and the research-lines parser.

3. **Version-comparison utility audit.** R5-c depends on whether hngh-automation already has a version-comparison utility. This is an unverified claim about the repository's existing code.

4. **Test infrastructure for dual-component regression.** R5-e requires tests that exercise both the acceptance evaluator and the research-lines parser against the same guard. The test infrastructure must support this without duplicating test logic.

---

## 4. References

### Repository-grounded (verified from prior beat metadata)

- `research-lines.tsv` — declared line-state file for this research line. Exists as the tracking artifact for the continuous research process.
- `hngh-2026-09-09-stall-lessons` — prior material listing "acceptance parsing" as a distinct stall category. Cited from prior beat's prior-arts section.
- `sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-` — Research Lesson on the acceptance evaluator. Cited from prior beat's prior-arts section.
- `sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu` — Research Lesson on the research-lines.tsv parser. Cited from prior beat's prior-arts section.
- `concepts/crowdsourced-failure-intake` — crowdsourced-failure-intake concept. Cited from prior beat's prior-arts section.
- `sources/mid-line-verification-block-triggers-long-acceptance-pending` — mid-line verification-block pattern. Cited from prior beat's prior-arts section.
- `sources/obs-2026-08-25-unsloth-local-server-api-and-terminalfeed-json-endpoints-dis` — observation on hngh-automation endpoints. Cited from prior beat's prior-arts section.

### Repository-grounded (unverified — no read access obtained)

- `[redacted path] — hngh kernel repository. Referenced as the ground-truth source for all code claims. **No verified read access was obtained during this transition.**
- hngh-automation source tree — target of R5 implementation. **No verified read access was obtained during this transition.**

### External sources

- **None asserted.** All claims are grounded in the prior material provided in this transition. No external sources were consulted or verified.

---

**Line closure note:** This line is contracted to `final_record`. It does not close on the open threads above; it closes on the fact that the recommendations are now crystallized as a lasting record. The open threads (particularly #1: shared-code-path verification) remain actionable for future beats that obtain read access into hngh-automation.
