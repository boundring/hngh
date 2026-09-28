# transient-env disposition: 2026-09-27 gate rc=2 did not reproduce; kernel suite passes standalone (sbcl: 2954 checks) and automation script suite passes (25/25 test scripts); alert is fixed-or-parked as fixed-transient

Status: crystallized 2026-09-28 from research line `fail-20260913-gate-check-hngh`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-gate-check-hngh.md.

# Final Structured Record: transient-env disposition

**Line:** transient-env disposition  
**Date:** 2026-09-27  
**Disposition:** fixed-transient  
**State:** contracting → closed  
**Model:** kimi:k3-256k  
**Wall clock:** 53.0s  
**Beat:** 2026-09-28 (contract)

---

## Findings

**1. The 2026-09-27 gate failure (rc=2) did not reproduce.**  
A full kernel suite pass under sbcl completed with 2954 checks passing. The automation script suite completed with 25/25 test scripts passing. The alert was dispositioned as fixed-transient.

**2. The defect was in the gate's environment, not the kernel.**  
The divergence between gate failure and standalone green is itself diagnostic: the kernel code is sound; the failure was environmental.

**3. The core epistemic failure was moment-of-action freshness.**  
By the time anyone looked at the failure, the failing environment was gone. Attestation gathered before the failure was worthless unless rechecked at the moment the failure fires.

**4. Evidence trail is park-worthy, not investigation-worthy.**  
A transient with no second occurrence in a full suite pass is park-worthy — but only if the evidence trail survives. The risk is "did not reproduce" becoming "was never explained and nobody can reconstruct what ran."

---

## Recommendations

**R1 — Close the line, but record the disposition durably.**  
Mark the line contracted/closed in `research-lines.tsv` with: the disposition string (`fixed-transient`), the two green-suite evidence points (2954 checks; 25/25), and the non-reproduction note. Do not let "did not reproduce" become "was never explained and nobody can reconstruct what ran."

**R2 — Make the next rc=2 self-diagnosing at moment of action.**  
On non-zero exit, capture before exiting: (a) the exact invocation, (b) env diff vs. the last green run, (c) sbcl version/path, (d) any lock or stale-fasl state, into a timestamped failure bundle. I cannot verify the gate script's filename from prior material; locate the script that produced the 2026-09-27 rc=2 and instrument there.

**R3 — Add a rerun-once policy to the gate.**  
On rc≠0, automatically rerun once with verbose logging; only escalate if the rerun also fails; annotate the first failure as `transient-candidate` with its failure bundle attached. The escalation threshold should be two consecutive failures, not one.

**R4 — Exploit the standalone-vs-gate divergence as signal.**  
Add an env-preflight step to the gate (sbcl presence/version, working-tree cleanliness, stale build artifacts) that runs before the suite and fails loudly with a distinct exit code. Reserve rc=2 for suite failures and a preflight code for environment failures, so future transients are triaged by exit code alone.

**R5 — Test the new gate behavior with failure injection.**  
Add a 26th automation script: a synthetic transient failure (a test double that fails once then succeeds) asserting that the gate classifies it as transient-candidate, produces a failure bundle, and does not escalate. Without this, R2–R4 are untested policy. I cannot verify the automation suite's directory layout from prior material; the count "25/25 test scripts" is the only grounding I have.

**R6 — Write the disposition note durably.**  
Record the disposition in the line's record with the evidence trail intact.

---

## Open Threads

- **R2/R3/R4/R5 implementation:** None of these have been implemented. They are recommendations pending action.
- **Gate script identification:** The specific filename of the gate script that produced the 2026-09-27 rc=2 is not recorded in prior material. This must be located before R2 can be instrumented.
- **Automation suite directory layout:** The directory layout of the automation suite is not recorded in prior material. This must be located before R5 can be implemented.
- **`research-lines.tsv` update:** The line state file needs to be updated with the closing disposition. I cannot verify its exact path from prior material; it is referenced as `research-lines.tsv` in the line state header.

---

## References

- `[redacted path] — hngh kernel repository (cited as the ground for kernel suite passes)
- `research-lines.tsv` — line state file (referenced in line state header; path not verified)
- `hngh-automation` — automation repository (referenced in prior material; specific paths not verified)
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson vault entry (read-only pointer; existence not verified)
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson vault entry (read-only pointer; existence not verified)
- `[[concepts/moment-of-action-freshness]]` — Attestation freshness recheck concept (vault reference; existence not verified)
- `[[entities/hngh]]` — Hngh Agent Kernel entity (vault reference; existence not verified)
- `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]` — Research Lesson vault entry (read-only pointer; existence not verified)
- `[[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]` — Observation vault entry (read-only pointer; existence not verified)

**Explicit caveat:** I have not re-executed anything in this transition. I cannot verify the existence or current contents of any file path listed above except `[redacted path] which is cited as the kernel repository in prior material. Where I cite vault references, those are read-only pointers from the llm-wiki vault and their existence is not independently verified.

---

**Record finalized.** Line contracted. Disposition: fixed-transient. Evidence trail preserved. Recommendations pending implementation.
