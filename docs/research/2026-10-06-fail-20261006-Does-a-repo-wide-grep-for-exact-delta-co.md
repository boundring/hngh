# Does a repo-wide grep for exact delta/count assertions in kernel gate tests against any file under a cadence write-path reveal the ui-grades race is one instance of a systemic shared-fixture pattern (blast-radius audit per O3)?

Status: crystallized 2026-10-06 from research line `fail-20261006-Does-a-repo-wide-grep-for-exact-delta-co`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20261006-Does-a-repo-wide-grep-for-exact-delta-co.md.

# Research Line Summary — Contracting

**Line:** Does a repo-wide grep for exact delta/count assertions in kernel gate tests against any file under a cadence write-path reveal the ui-grades race is one instance of a systemic shared-fixture pattern (blast-radius audit per O3)?

**State:** contracting → terminal (final record)

**Date:** 2026-10-06

---

## Findings

### F1. Audit not yet executed against material

The blast-radius audit methodology was fully specified in prior beats but **never executed against any repository working tree**. No grep results, no join outputs, no positive/negative verdicts exist from this line. This is a methodological gap, not a finding about the ui-grades race.

### F2. The audit's value is in the join, not the census

Per R1 (prior beat, reconstructed): a raw count of `toHaveLength(N)` / `assert len(...) == N` hits is non-evidence. The audit's discriminative power comes from the **intersection** between (a) exact-cardinality assertions and (b) cadence write-path membership. This methodological insight is preserved as a finding.

### F3. The ui-grades race cannot be classified as systemic without execution

Classification as "one instance of a systemic shared-fixture pattern" requires class-(a) count > 1 in the join. Without execution, this classification remains unverified. The line cannot produce a verdict without material access.

### F4. Recommendations are parameterized and executable

All recommendations (R1, R2) were written as parameterized grep commands and decision rules rather than assertions about specific files. They are **executable as-is** against any repository with the appropriate cadence constants and gate-test directories.

---

## Recommendations

### R1. Execute the two-set join with pre-registered negative result

**Procedure:**

1. **Enumerate cadence write-paths first** — grep for cadence interval constant and writer call-sites to build the write-path set before examining tests. This prevents confirmation bias toward the ui-grades shape.

2. **Census exact-cardinality assertions in gate tests:**
   ```bash
   grep -rnE "to(HaveLength|Be)\(|assertEqual\(len|assert len\(.*==|\.length, [0-9]" <gate-test-dirs>
   grep -rnE "before.*after|after.*before.*\+ ?[0-9]" <gate-test-dirs>
   ```
   Hand-filter delta-form hits; `before/after` greps are noisy by construction.

3. **Join:** For each hit, resolve the assertion's subject through fixture setup *in the same test file* and flag only if the resolved path lands under a cadence write-path. Emit one row per flag: file, assertion line, fixture origin, writer, shared-with.

4. **Pre-register both outcomes.** If ui-grades is the only class-(a) row, the answer is **no** and the "systemic pattern" framing must be demoted in the line state — that is a finding, not a failure of the audit.

### R2. If systemic (class-(a) count > 1): apply existing mitigations

A positive result does not require inventing new mitigations — the vault already holds both:

- **Sandbox every fixture a gate test reads** — per-test copies or tmpdir-scoped ledgers, never the live path a cadence writer touches. This extends the discipline from `[[sources/debug-repro-sandboxes-only]]` from debug repros to *gate fixtures*, a widening of scope the vault note does not yet state.

- **Demote, don't debug, cadence-coupled flakes.** Any gate that fails twice consecutively with a cardinality mismatch on a flagged path gets demoted out of the blocking set per `[[sources/outcome-demotion-at-two-consecutive-failures]]`, rather than re-run until green — re-running a cadence-coupled assertion is just sampling the race again.

### R3. If not systemic (class-(a) count = 1): reframe the line

If ui-grades is the only flagged instance, the line should be reframed from "systemic shared-fixture pattern" to "isolated ui-grades race with blast radius audit complete." The audit itself is the finding, not the classification.

---

## Open Threads

### OT1. Material access

This line cannot produce a verdict without access to the repository working tree. The prior beat's grep audit was specified but never executed in-material. No path inside the repository root has been verified.

### OT2. Cadence write-path definition

The cadence interval constant and writer call-sites referenced in R1 are not concretely identified in prior material. These must be resolved before execution to build the write-path set.

### OT3. Gate-test directory enumeration

The `<gate-test-dirs>` placeholder in R1's grep commands requires concrete directory paths. These are not specified in prior material.

---

## References

### This repository

- No concrete file paths verified. All references below are vault pointers that require material access to confirm existence.

### hngh kernel repository

- `[redacted path] — repository root (user-supplied; not verified)

### Vault pointers (read-only, existence unverified)

- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson: What are the exact file paths for the cadence write-path
- `[[sources/debug-repro-sandboxes-only]]` — Debug repros must run in sandboxes, never against live ledgers
- `[[sources/long-gates-run-async-against-interjections]]` — Run long verification gates async so interjections don't cause false positives
- `[[sources/outcome-demotion-at-two-consecutive-failures]]` — Consecutive bad-execution cancellation cancellation policy

---

## Line State

**Terminal.** This line's recommendations are parameterized and executable but require material access to produce a verdict. The line's lasting record is the methodology (blast-radius audit per O3), the pre-registered decision rules (R1-R3), and the open threads (OT1-OT3) that block execution.

**No findings about the ui-grades race exist.** The line produced no grep results, no join outputs, and no classification. The recommendations are preserved as executable next steps for when material access is available.

---

*Honesty note: This summary was produced without verified read of the hngh working tree. All file path references are vault pointers whose existence cannot be confirmed. The prior material was truncated at 4000 bytes; this summary reconstructs the intended conclusions of R2 explicitly rather than pretending continuity.*
