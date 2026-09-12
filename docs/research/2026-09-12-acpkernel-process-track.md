# What does a solo author's issue-RFC + self-merge + release-PR cadence (acp-kernel #166/#167/#168, release PRs #240/#243/#246) teach hngh's public design visibility and backlog-disposition practice?

Status: crystallized 2026-09-12 from research line `acpkernel-process-track`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-acpkernel-process-track.md.

### Final Structured Summary

#### Research Line: What does a Solo Author's Issue-RFC + Self-Merge + Release-PR Cadence (acp-kernel #166/#167/#168, release PRs #240/#243/#246) Teach Hngh's Public Design Visibility and Backlog-Disposition Practice?

**Current Lifecycle State:** Contracting

---

#### Findings

1. **Issue-RFC First**: The solo author's process begins with writing down design intent publicly before committing code. This makes the self-merge legible and transparent, with the RFC serving as the durable design record.
2. **Self-Merge**: Acceptable for a solo author due to the preceding RFC. Self-merge without an RFC would destroy the rationale trail, but an RFC followed by self-merge merely skips redundant review.
3. **Release PRs as Aggregation Points**: Release PRs re-expose merged work at a coarser grain, providing visibility at release cadence rather than commit cadence. This allows for a summary of changes and rationale without requiring detailed per-issue tracking.

#### Recommendations

1. **R1 — Require an RFC Link on Every Self-Merge**: Implement a merge-time check in hngh-automation that requires every self-merge to reference an issue-RFC. This converts a social norm into a mechanical gate, ensuring that the rationale trail is maintained.
2. **R2 — Keep Release PRs as the Public Design Surface**: Batch merged work into release PRs that aggregate the underlying RFC links. Followers of hngh should be able to reconstruct the design history from release PRs alone.
3. **R3 — Disposition the Backlog at Merge Time, Not Retrospectively**: Every self-merge should mark its originating backlog item as accepted, deferred, or rejected with a one-line reason. This directly addresses the risk of backlog drift.
4. **R4 — Record the Full Chain in the Evidence Ledger**: Each release should have a complete authority trail: backlog item → RFC → merge → release PR. This ensures that the trail is maintained and there are no gaps.

#### Open Threads

1. **Verification of PR Metadata**: The specific PR metadata (e.g., comments, backlog contributions) needs further verification to ensure the accuracy of the claims.
2. **Implementation of Recommendations**: The implementation of the above recommendations in hngh-automation and the evidence ledger requires detailed planning and execution.
3. **Impact on Multi-Author Projects**: The recommendations are framed for a solo author but may need adjustments for multi-author projects.

---

#### References

1. [[concepts/evidence-ledger]]: Authority and Evidence Ledgers
2. [[sources/obs-2026-08-19-authored-vs-studied-project-distinction]]: Observation: Authored vs Studied Project Distinction
3. [[sources/SRC

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
