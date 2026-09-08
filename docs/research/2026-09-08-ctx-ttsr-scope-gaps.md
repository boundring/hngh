# What session-discipline violations escape stream-rule scopes (thinking, subagents) and how should record-level screening close them?

Status: crystallized 2026-09-08 from research line `ctx-ttsr-scope-gaps`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-ctx-ttsr-scope-gaps.md.

### Final Structured Summary: Closing Session-Discipline Violations in `hngh` and `hngh-automation`

#### Findings

1. **Semantic Provenance of Thinking Blocks (The "Why" Audit)**
   - **Findings:**
     - Thinking/reasoning tokens should be treated as first-class provenance artifacts.
     - A "Record-Level Intent Verifier" can be developed to parse thinking blocks from the session log and compare them against the user’s original prompt using a lightweight LLM.
     - Discrepancies or hallucinations in the thinking process can be identified and flagged as potential violations.
   - **References:**
     - [[concepts/roguelike-discipline]]: Roguelike Discipline in Agent Execution
     - [[sources/SRC-2026-08-24-006]]: SLSA Supply Chain Levels for Software Artifacts

2. **Subagent Boundary Leakage Detection**
   - **Findings:**
     - A mechanism should be implemented to detect violations in subagent boundaries by verifying the actions taken by subagents against a sandbox manifest.
     - The sandbox manifest should list all resources and actions allowed for each subagent.
     - Any actions that violate the sandbox rules should be identified and logged.
   - **References:**
     - [[concepts/session-salvage]]: Session Salvage
     - [[sources/SRC-2026-08-24-025]]: Hngh Prior-Art Landscape Record (2026-08-24)

3. **Lesson Verification and Intent Alignment**
   - **Findings:**
     - Lessons learned from previous sessions should be verified to ensure they are correctly applied and do not lead to new violations.
     - A lightweight LLM can be used to verify the application of lessons.
     - Discrepancies should be flagged as potential violations.
   - **References:**
     - [[sources/SRC-2026-08-24-011]]: MisakaNet Trust Semantics: Evidence Levels and Lesson Verification

#### Recommendations

1. **Semantic Provenance of Thinking Blocks (The "Why" Audit)**
   - **Recommendations:**
     - Implement a parser to extract thinking blocks from the session log.
     - Store the thinking blocks in a structured format.
     - Use a lightweight LLM to generate a semantic diff between the thinking blocks and the user’s original prompt.
     - Flag any discrepancies as potential violations.
   - **Implementation Path:**
     - Extract Thinking Blocks: Implement a parser to extract thinking blocks from the session log.
     - Semantic Diffing: Use a lightweight LLM to generate a semantic diff.
     - Alignment Verification: Ensure thinking blocks align with the user’s intent.

2. **Subagent Boundary Leakage Detection**
   - **Recommendations:**
     - Define a sandbox manifest that lists all resources and actions allowed for each subagent.
     - Cross-reference the subagent’s actions against the sandbox manifest.
     - Trigger alerts for any violations detected.
   - **Implementation Path:**
     - Sandbox Manifest: Define and store the sandbox manifest.
     - Cross-Referencing: Cross-reference actions against the manifest.
     - Alerting: Trigger alerts for violations.

3. **Lesson Verification and Intent Alignment**
   - **Recommendations:**
     - Extract lessons learned from previous sessions and store them in a structured format.
     - Apply the lessons to the current session and compare actions.
     - Use a lightweight LLM to verify the application of lessons.
   - **Implementation Path:**
     - Lesson Extraction: Extract and store lessons.
     - Lesson Application: Apply lessons to the current session.
     - Verification: Use a lightweight LLM to verify application.

#### Open Threads

1. **Integration with Existing Systems**
   - How to integrate these mechanisms with existing systems and workflows.
  
