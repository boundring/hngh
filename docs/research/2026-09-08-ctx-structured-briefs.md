# Which structured brief fields measurably cut reorientation tokens after a session death, and which fields are noise?

Status: crystallized 2026-09-08 from research line `ctx-structured-briefs`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-structured-briefs.md.

### Final Summary: Structured Brief Fields and Reorientation Tokens

#### Findings

1. **Negative Knowledge as a High-Yield Brief Field**:
   - **Field**: `dead_ends` (structured as (attempt, observed outcome, reason it failed) tuples)
   - **Rationale**: This field forecloses entire exploration subtrees, thereby reducing the number of reorientation tokens required.
   - **Verification**: Based on the titles of prior-art notes and their stated scope. Further verification is needed to confirm the contents of the notes.

2. **Environment-Specific "Known Traps" Field**:
   - **Field**: Per-environment "known traps" field
   - **Rationale**: Environment-specific failure patterns are cheap to record, repeatedly costly if not recorded, and orthogonal to task state.
   - **Verification**: Based on the title of the prior-art note and its stated scope. Further verification is needed to confirm the contents of the note.

3. **Anchor-Bearing Fields**:
   - **Fields**: File paths, command names, commit hashes, test names
   - **Rationale**: These fields require fewer tokens to verify compared to unanchored prose.
   - **Verification**: Based on a structural argument and a prediction. Further verification is needed to confirm the contents of the notes and the behavior of the `hngh` kernel.

4. **Candidate Noise Fields**:
   - **Fields**: Motivational framing, restated task description, roadmap/future-work sections, persona/style notes
   - **Rationale**: These fields are consumed once, redundant with live prompts, irrelevant to the next verified action, and have no plausible mechanism for reducing reorientation.
   - **Verification**: Hypotheses need empirical testing to confirm their status as noise.

#### Recommendations

1. **Construct Briefs with Known Field Subsets**:
   - Create briefs with varying subsets of fields to systematically test their impact on reorientation tokens.
   - **Verification**: Check if the `hngh` kernel has a harness for checkpoint/restore of task state. This is a critical step and should be verified in `/home/bricker/Projects/etc/hngh`.

2. **Kill the Session and Measure Tokens-to-First-Verified-Action**:
   - Simulate a session death and hand the brief to a fresh agent on an identical task state.
   - Record the number of tokens required for the agent to perform the first verified action.
   - **Verification**: Further verification is needed to confirm the contents of the prior-art notes and the behavior of the `hngh` kernel.

#### Open Threads

1. **Verification of Prior-Art Notes**:
   - Confirm the contents of the prior-art notes and the existence of the `hngh` kernel features.
   - **Verification**: Further investigation is required to confirm these claims.

2. **Empirical Testing of Noise Fields**:
   - Conduct empirical testing to confirm the status of the candidate noise fields.
   - **Verification**: Further testing is needed to validate the hypotheses.

#### References

1. [[concepts/session-salvage]] - Session Salvage *(created: 2026-08-24)*
2. [[sources/grep-tab-escape-matches-nothing]] - GNU grep treats \t as a stray escape; use awk -F'\t'
3. [[sources/deadends-dev-failure-knowledge]] - deadends.dev - structured failure knowledge (dead ends)

**Unverified Claims**: The contents of the prior-art notes and the existence of the `hngh` kernel features are not verified. Further investigation is required to confirm these claims.

---

This structured summary provides a comprehensive record of the research findings, recommendations, and open threads for the research line on structured brief fields and reorientation tokens.
