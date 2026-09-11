# What prior art exists for procedural voting on changes (sign-offs, LGTM counts, quorum rules) and how is it scored?

Status: crystallized 2026-09-11 from research line `govbench-voting-prior-art`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-voting-prior-art.md.

## Final Structured Summary: Procedural Voting on Changes in hngh/hngh-automation

### Findings

1. **Signed-off-by Chain as Minimal Procedural Vote**
   - **Recommendation:** Adopt the `Signed-off-by` trailer convention as the minimal procedural vote. Each sign-off is a binary attestation: "I have reviewed this and take responsibility."
   - **Scoring Implication:** Under this model, scoring is binary per reviewer (signed / not signed). The only "count" that matters is whether the required set of identities appears in the trailer block.
   - **Reference:** `/home/bricker/Projects/etc/hngh/Documentation/process/submitting-patches.rst` (Linux kernel's Contributor's Guide)

2. **Formalize LGTM as a Structured Metadata Field**
   - **Recommendation:** Introduce a structured metadata field to capture LGTM or ack signals. This can be achieved by parsing review-thread LGTM counts into a score using a script.
   - **Verification Item:** Confirm the existence of a script that parses LGTM counts into a score.
   - **Reference:** `/home/bricker/Projects/etc/hngh/scripts/` or `.github/workflows/`

3. **Define Explicit Quorum Rules**
   - **Recommendation:** Define explicit quorum rules in the repository governance documents. These rules should specify the minimum number of distinct sign-offs required before a change can be merged.
   - **Scoring Implication:** The quorum check should be a gate, not a score modifier. Changes without the required sign-offs should be invalid.
   - **Reference:** `/home/bricker/Projects/etc/hngh/GOVERNANCE.md`, `/home/bricker/Projects/etc/hngh/CONTRIBUTING.md`, or `/home/bricker/Projects/etc/hngh/Documentation/process/`

4. **Implement Weighted Sign-off or Review-Depth Score**
   - **Recommendation:** Consider implementing a weighted sign-off model or a review-depth score model. These models can provide a more nuanced scoring mechanism based on the seniority and time-to-review of the reviewers.
   - **Scoring Implication:**
     - **Weighted sign-off:** Each reviewer's sign-off carries a weight (e.g., maintainer = 1.0, contributor = 0.5). The sum of these weights must exceed a threshold.
     - **Review-depth score:** The score is derived from the diffstat size × reviewer seniority × time-to-review.
   - **References:**
     - `SRC-2026-08-24-025` (Hngh Prior-Art Landscape Record)
     - `[[syntheses/hngh-prior-art-landscape-2026-08]]` (Hngh Prior-Art Landscape 2026-08)
     - `[[syntheses/hngh-procedural-tooling-design-2026-08]]` (Hngh Procedural Tooling Design 2026-08)
     - `[[sources/voice-rules-as-binding-constraint-not-aesthetic-preference]]` (Voice Rules as Binding Constraint, Not Aesthetic Preference)

### Recommendations

1. **Adopt the `Signed-off-by` Trailer Convention**
   - Implement the `Signed-off-by` trailer as the minimal procedural vote. Ensure that each sign-off is a binary attestation.
   - Update the repository's governance documents to reflect this practice.

2. **Introduce a Structured Metadata Field for LGTM Signals**
   - Develop a script to parse LGTM counts into a structured metadata field.
   - Integrate this script into the repository's workflow to enable quorum checks.

3. **Define Explicit Quorum Rules**
   - Establish explicit quorum rules in the repository's governance documents.
   - Ensure that changes require the minimum number of distinct sign-offs before being merged.

4. **Implement Weighted Sign-off or Review-Depth Score**
   - Consider implementing a weighted sign-off model or a review-depth score model.
   - Document the scoring criteria and thresholds in the repository's governance documents.

### Open Threads

1. **Script Verification**
   - Verify the existence of a script that parses LGTM counts

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
