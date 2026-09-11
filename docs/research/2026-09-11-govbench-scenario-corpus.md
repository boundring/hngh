# What scenario corpus (benign, adversarial, partial-failure changes) exercises a governance benchmark honestly?

Status: crystallized 2026-09-11 from research line `govbench-scenario-corpus`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-govbench-scenario-corpus.md.

### Research Line: What Scenario Corpus (Benign, Adversarial, Partial-Failure Changes) Exercises a Governance Benchmark Honestly?

#### Current Lifecycle State: Contracting

**Objective:**
To identify and validate a scenario corpus that effectively exercises a governance benchmark in a continuous research process. The corpus should cover benign, adversarial, and partial-failure scenarios to ensure a comprehensive evaluation of the governance model.

**Concrete Recommendations:**

1. **Benign Scenario Validation:**
   - **Objective:** To ensure the governance benchmark accurately captures normal operational conditions.
   - **Approach:** Develop a set of benign scenarios that simulate typical system operations and validate the governance model's ability to handle these conditions without triggering false alarms or missing critical issues.
   - **Concrete Findings:**
     - **File Path:** `/home/bricker/Projects/etc/hngh/scenarios/benign_scenarios.txt`
     - **Description:** This file contains a list of benign scenarios, each with detailed descriptions and expected outcomes.
     - **Validation:** Use the `validate_benign_scenarios.py` script to run the scenarios through the governance benchmark and analyze the results.

2. **Adversarial Scenario Validation:**
   - **Objective:** To assess the governance benchmark's robustness against malicious or intentionally harmful actions.
   - **Approach:** Create a set of adversarial scenarios that simulate attacks or malicious actions and evaluate the governance model's ability to detect and respond to these threats.
   - **Concrete Findings:**
     - **File Path:** `/home/bricker/Projects/etc/hngh/scenarios/adversarial_scenarios.txt`
     - **Description:** This file contains a list of adversarial scenarios, each with detailed descriptions and expected outcomes.
     - **Validation:** Use the `validate_adversarial_scenarios.py` script to run the scenarios through the governance benchmark and analyze the results.

3. **Partial-Failure Scenario Validation:**
   - **Objective:** To evaluate the governance benchmark's ability to handle partial failures or degraded system states.
   - **Approach:** Develop a set of partial-failure scenarios that simulate degraded or partially failed system states and assess the governance model's ability to detect and mitigate these issues.
   - **Concrete Findings:**
     - **File Path:** `/home/bricker/Projects/etc/hngh/scenarios/partial_failure_scenarios.txt`
     - **Description:** This file contains a list of partial-failure scenarios, each with detailed descriptions and expected outcomes.
     - **Validation:** Use the `validate_partial_failure_scenarios.py` script to run the scenarios through the governance benchmark and analyze the results.

#### References

1. **Crowdsourced Failure Intake**
   - **File Path:** `/home/bricker/Projects/etc/hngh/concepts/crowdsourced-failure-intake.md`
   - **Description:** This document outlines the process of crowdsourcing failure data to improve governance models.

2. **Agent-Harness Governance Positioning**
   - **File Path:** `/home/bricker/Projects/etc/hngh/concepts/agent-harness-governance.md`
   - **Description:** This document provides an overview of the agent-harness governance framework and its positioning within the research.

3. **Governance Models**
   - **File Path:** `/home/bricker/Projects/etc/hngh/concepts/governance-models.md`
   - **Description:** This document details various governance models and their application in different scenarios.

4. **deadends.dev Structured Failure Knowledge**
   - **File Path:** `/home/bricker/Projects/etc/hngh/sources/deadends-dev-structured-failure-knowledge.md`
   - **Description:** This document provides structured failure knowledge, which is crucial for understanding and validating the governance benchmark.

5. **Outcome Demotion at Two Consecutive Failures**
   - **File Path:** `/home/bricker/Projects/etc

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
