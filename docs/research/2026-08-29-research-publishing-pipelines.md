# research publishing pipelines: reports, papers, books from crystallized lines

Status: crystallized 2026-08-29 from research line `research-publishing-pipelines`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-research-publishing-pipelines.md.

# Crystallized Line: Research Publishing Pipelines

**Line:** Research publishing pipelines: reports, papers, books from crystallized lines

**Lifecycle State:** Contracted (Final Summary)

**Target Context:** `hngh/hngh-automation`

**Date:** 2026-08-29

## Executive Summary
This line has transitioned from an open research question into a defined implementation specification. The core insight is that publishing is not a creative writing task but a **conversion system**. Crystallized research lines are publishable only when they are converted into structured units (Claim–Evidence–Boundary–Consequence) and routed to the optimal format (report, paper, or book) based on audience and intent. The goal is no longer "write more outputs" but to build a pipeline that ensures every artifact is audience-appropriate, evidence-verified, and format-gated.

## Findings

1.  **Publishing as Conversion, Not Creation:**
    *   The bottleneck in publishing is not the generation of text but the lack of structured conversion logic from raw research insights to publishable artifacts.
    *   A "crystallized line" (a stable, verified research insight) must be decomposed into four mandatory components before it can be published:
        *   **Claim:** The specific, testable assertion.
        *   **Evidence:** The data or logical proof supporting the claim.
        *   **Boundary:** The conditions under which the claim holds (and where it does not).
        *   **Consequence:** The practical implication or next step for the reader.

2.  **Format is a Routing Decision, Not a Style Choice:**
    *   Reports, papers, and books are not interchangeable outputs. They serve different audiences and purposes.
    *   **Reports:** For internal stakeholders/clients; focus on actionable consequences and boundaries.
    *   **Papers:** For academic/technical peers; focus on evidence rigor and claim novelty.
    *   **Books:** For broad professional audiences; focus on narrative synthesis of multiple crystallized lines.
    *   The pipeline must route a crystallized line to the format where its C-E-B-C unit is strongest, not just where it fits easiest.

3.  **Metadata as Gatekeeper:**
    *   Without explicit metadata (audience, intent, evidence strength, boundary clarity), artifacts cannot be quality-controlled.
    *   A "publication card" must exist for every artifact before drafting begins. This card contains the C-E-B-C unit and routing decision.

4.  **Automation Feasibility:**
    *   The pipeline is amenable to automation (`hngh/hngh-automation`) because the steps are discrete:
        1.  Ingest crystallized line.
        2.  Extract/validate C-E-B-C unit.
        3.  Generate publication card (metadata).
        4.  Route to format template.
        5.  Draft artifact.
        6.  Verify evidence against boundaries.

## Recommendations

1.  **Implement the Publication Card Schema:**
    *   Define a strict JSON/YAML schema for the "publication card" that includes fields for Claim, Evidence (linked to source data), Boundary (explicit negations/limits), Consequence, Target Audience, and Recommended Format.
    *   No artifact enters the drafting phase without a completed publication card.

2.  **Build Format-Specific Templates:**
    *   Create distinct templates for reports, papers, and books that enforce the C-E-B-C structure.
    *   *Report Template:* Lead with Consequence, support with Claim/Evidence, clarify Boundaries in a "Limitations" section.
    *   *Paper Template:* Lead with Claim, detail Evidence, discuss Boundaries in Discussion.
    *   *Book Chapter Template:* Synthesize multiple C-E-B-C units into a narrative arc.

3.  **Automate Evidence Verification:**
    *   Integrate checks that validate the "Evidence" field against source data or prior crystallized lines.
    *   Flag artifacts where the Boundary is not explicitly stated (a common failure mode in auto-generated text).

4.  **Establish a "Routing Engine":**
    *   Develop logic to recommend format based on metadata:
        *   High novelty + high evidence rigor → Paper.
        *   High actionability + moderate evidence → Report.
        *   Multiple related lines + narrative potential → Book.

## Open Threads

1.  **Quality Metrics for "Crystallization":**
    *   How do we objectively measure when a research line is "crystallized" enough to enter the publishing pipeline? Current definition is subjective; need quantitative thresholds (e.g., number of supporting data points, consistency across trials).

2.  **Audience Modeling:**
    *   The routing engine assumes clear audience definitions. How do we model and tag audiences dynamically? This may require a separate line on "Audience Profiling for Technical Publishing."

3.  **Feedback Loop Integration:**
    *   How does post-publication feedback (citations, client adoption, reader comments) feed back into the crystallization of new lines? The current pipeline is unidirectional (Research → Publish). A bidirectional loop is needed for continuous improvement.

4.  **Book-Level Synthesis Logic:**
    *   While report and paper generation are modular, book creation requires narrative synthesis across multiple lines. This is a more complex algorithmic challenge and may require a separate sub-line on "Narrative Structuring from Modular Insights."

## Final State
This line is now **contracted** into an implementation spec for `hngh/hngh-automation`. The next step is not further research, but engineering the pipeline components described in the recommendations. The open threads are identified as future research lines or sub-tasks within the automation project.
