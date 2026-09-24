# Does the slug/line-ID minting code that produced `patrol-20260923-rotation-due-rotation-due` share a key-composition code path with the outcome dedupe-key derivation, making the doubled token a reproduction of the suspected bug?

Status: crystallized 2026-09-24 from research line `fail-20260924-Does-the-slug-line-ID-minting-code-that-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260924-Does-the-slug-line-ID-minting-code-that-.md.

# Research Line Final Summary

**Line ID:** `patrol-20260923-rotation-due-rotation-due`  
**Research Question:** Does the slug/line-ID minting code share a key-composition code path with the outcome dedupe-key derivation, making the doubled token a reproduction of the suspected bug?  
**Lifecycle State:** **contracting** → **finalized**  
**Date:** 2026-09-23  
**Model:** unsloth:unsloth/Ornith-1.0-9B-GGUF  

---

## Findings

### Observed Phenomenon
The patrol line ID `patrol-20260923-rotation-due-rotation-due` contains a duplicated token pattern: `rotation-due` appears twice in sequence. This duplication is the subject of investigation.

### Hypothesis Under Investigation
The duplication may originate from a shared code path between:
1. **Slug/line-ID minting logic** — the function that produces patrol identifiers
2. **Outcome dedupe-key derivation** — the function that generates deduplication keys from patrol outcomes

If both functions invoke the same token-composition routine, the duplication could be inherited rather than introduced independently.

### Code Path Analysis Status
**Unverified.** This repository requires direct filesystem access to the hngh kernel repository at `[redacted path] to:
- Locate the slug minting function
- Locate the dedupe-key derivation function
- Trace shared code paths between them
- Verify token normalization logic
- Confirm consecutive rotation state handling

**No concrete file paths can be cited** without direct access to the repository structure.

---

## Recommendations

### Recommendation 1: Trace the Slug Minting Entry Point
**Action:** Search the hngh repository for the function that mints patrol line IDs. Look for any function that takes a rotation-status token and embeds it into a patrol identifier. Verify whether that function is invoked once or twice in the minting path.

**Expected Outcome:** If the function is invoked twice, the duplication is introduced at minting time. If invoked once, the duplication may originate elsewhere.

### Recommendation 2: Trace the Dedupe-Key Derivation Entry Point
**Action:** Search the hngh repository for the dedupe-key derivation function. Check whether it calls the same token-composition function identified in Recommendation 1.

**Expected Outcome:** If shared, the dedupe-key inherits the duplication. If separate, the duplication is isolated to slug minting.

### Recommendation 3: Check for Token Normalization in Dedupe-Key Logic
**Action:** Examine whether the dedupe-key derivation includes any normalization step (deduplication, canonicalization, token collapsing).

**Expected Outcome:** If no normalization exists, the dedupe-key faithfully reproduces whatever token composition the slug minting produces.

### Recommendation 4: Instrument the Minting Path with Token Counting
**Action:** Add a diagnostic check that counts the number of distinct tokens in a minted slug before and after dedupe-key derivation.

**Expected Outcome:** This provides empirical evidence for or against the shared-code-path hypothesis.

### Recommendation 5: Check for Consecutive Rotation State Handling
**Action:** Search for logic that handles patrol rotation state transitions. Verify whether consecutive "rotation-due" states are treated as a single event or two separate events.

**Expected Outcome:** If consecutive states trigger duplicate token inclusion, this explains the duplication independently of shared code paths.

---

## Open Threads

1. **Filesystem Access Required:** All recommendations depend on direct access to the hngh repository at `[redacted path] Without this access, concrete code paths cannot be verified.

2. **Prior Art Reference:** The prior art on outcome demotion at two consecutive failures (`[[sources/outcome-demotion-at-two-consecutive-failures]]`) provides context but does not directly address the slug minting code path.

3. **Verification Gap:** The hypothesis that the duplication is a "reproduction of the suspected bug" remains unverified until the code paths are traced.

---

## Honest Limitations

I cannot verify specific file paths in the hngh repository without direct filesystem access. The recommendations above are grounded in the observed duplication pattern and the research question, but concrete file references must be verified against the actual repository structure.

**External sources cannot be verified** for this claim. The research is confined to the hngh repository and the observed slug pattern.

---

## References

- **Prior art:** `[[sources/outcome-demotion-at-two-consecutive-failures]]` — Consecutive bad-execution cancellation context
- **Repository:** `[redacted path] — hngh kernel repository (file paths to be verified)
- **Observed slug:** `patrol-20260923-rotation-due-rotation-due` — The duplicated token pattern under investigation

---

**Line Status:** Finalized. Awaiting filesystem access to hngh repository for concrete code path verification.
