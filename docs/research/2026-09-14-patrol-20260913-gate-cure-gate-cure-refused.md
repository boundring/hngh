# patrol: surface gate-cure filed gate-cure-refused on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-14 from research line `patrol-20260913-gate-cure-gate-cure-refused`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260913-gate-cure-gate-cure-refused.md.

### Final Structured Summary for Research Line: Patrol: Surface Gate-Cure Filed Gate-Cure-Refused on Two Consecutive Runs

#### Findings

1. **Overly Restrictive Guardrails:**
   - The `gate-cure` process is failing due to overly restrictive guardrails that are preventing legitimate fixes.
   - Specific guardrails in `~/Projects/etc/hngh/.gitattributes`, `~/Projects/etc/hngh/.github/workflows/`, and `~/Projects/etc/hngh/config/guardrails.yaml` are identified as overly broad.

2. **Specific Constraints Blocking the Cure:**
   - The `gate-cure` process is failing because of specific constraints that are blocking the cure.
   - Logs from `~/Projects/etc/hngh/logs/gate-cure/` and `~/Projects/etc/hngh/logs/guardrails/` indicate that the `surface` guardrail is the primary constraint.

3. **Robustness and Compliance Issues:**
   - The `gate-cure` agent is not robust enough to handle guardrail constraints, leading to frequent failures.
   - The agent needs to be refactored to ensure it adheres to the guardrails and avoids attempting to modify protected files.

#### Recommendations

1. **Audit the Guardrail Configuration for Over-Broad Protection:**
   - Review and refine the guardrails in `~/Projects/etc/hngh/.gitattributes`, `~/Projects/etc/hngh/.github/workflows/`, and `~/Projects/etc/hngh/config/guardrails.yaml` to ensure they are not overly restrictive.
   - Implement a pre-check mechanism in the `gate-cure` agent to validate proposed changes against the guardrails.

2. **Identify the Specific Constraints Blocking the Cure:**
   - Analyze the logs from `~/Projects/etc/hngh/logs/gate-cure/` and `~/Projects/etc/hngh/logs/guardrails/` to pinpoint the specific rule or constraint that is blocking the cure.
   - Refactor the `gate-cure` agent to handle these constraints more robustly.

3. **Ensure Robustness and Compliance of the Automated Cure Process:**
   - Refactor the `gate-cure` agent to ensure it adheres to the guardrails and avoids attempting to modify protected files.
   - Implement a pre-check mechanism in the `gate-cure` agent to validate the proposed changes against the guardrails before applying them.

#### Open Threads

1. **Further Refinement of Guardrails:**
   - Continue to refine the guardrails to ensure they are not overly restrictive while still providing necessary protection.
   - Collaborate with upstream repositories to address any issues identified in the guardrails.

2. **Enhanced Logging and Diagnostics:**
   - Improve logging and diagnostic tools to provide more detailed insights into the `gate-cure` process and guardrail interactions.
   - Develop a more comprehensive logging framework to capture and analyze logs from both the `gate-cure` process and the guardrails.

3. **Community and Upstream Collaboration:**
   - Engage with the community and upstream repositories to address any broader issues related to the guardrails and the `gate-cure` process.
   - Share findings and collaborate on solutions to ensure a more robust and compliant automated cure process.

### References

1. **Audit the Guardrail Configuration for Over-Broad Protection:**
   - `.gitattributes` in `~/Projects/etc/hngh/.gitattributes`
   - Pre-commit hooks in `~/Projects/etc/hngh/.git/hooks/pre-commit`
   - Custom validation scripts in `~/Projects/etc/hngh/.github/workflows/` and `~/Projects/etc/h

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
