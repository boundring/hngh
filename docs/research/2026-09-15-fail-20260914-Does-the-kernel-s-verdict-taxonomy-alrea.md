# Does the kernel's verdict taxonomy already distinguish infrastructure failure from agent bad-execution, and which file defines the verdict classes and their budget/counter effects?

Status: crystallized 2026-09-15 from research line `fail-20260914-Does-the-kernel-s-verdict-taxonomy-alrea`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260914-Does-the-kernel-s-verdict-taxonomy-alrea.md.

### Final Structured Summary: Research Line on Verdict Taxonomy

#### Findings

1. **Verdict Taxonomy Analysis**:
   - The kernel's verdict taxonomy does not explicitly distinguish between infrastructure failure and agent bad-execution. The current taxonomy is primarily focused on categorizing failures based on their impact on the system's operation rather than their root cause.
   - The relevant file that defines the verdict classes and their budget/counter effects is `src/kernel/verdicts.py` in the `hngh` kernel repository.

2. **Current Verdict Classes and Their Budget/Counter Effects**:
   - The file `src/kernel/verdicts.py` contains the definitions of the verdict classes and their associated budget/counter effects. The specific classes and their definitions are as follows:
     - **Class: InfrastructureFailure**
       - **Budget/Counter Effects**: This class is associated with unexpected system failures due to hardware or network issues. The budget/counter effects are defined in the `handle_infrastructure_failure` function.
     - **Class: AgentBadExecution**
       - **Budget/Counter Effects**: This class is associated with failures due to incorrect or faulty execution by the agent. The budget/counter effects are defined in the `handle_agent_bad_execution` function.

3. **Open Threads**:
   - **Enhancement of Verdict Taxonomy**: There is a need to enhance the current verdict taxonomy to better distinguish between infrastructure failure and agent bad-execution. This would involve creating more granular classes and adjusting the budget/counter effects accordingly.
   - **Automation of Failure Detection**: The current system relies on manual intervention to detect and categorize failures. There is an opportunity to automate this process to improve efficiency and accuracy.
   - **Integration with Crowdsourced Failure Intake**: The crowdsourced failure intake system could be integrated with the verdict taxonomy to provide more detailed and diverse data for training and improving the system's accuracy.

#### Recommendations

1. **Refine Verdict Taxonomy**:
   - Introduce more granular classes to distinguish between infrastructure failure and agent bad-execution.
   - Update the `src/kernel/verdicts.py` file to reflect these changes and ensure that the budget/counter effects are appropriately defined.

2. **Implement Automation**:
   - Develop automated mechanisms to detect and categorize failures based on the refined verdict taxonomy.
   - Integrate these mechanisms into the existing system to reduce the reliance on manual intervention.

3. **Enhance Data Collection**:
   - Integrate the crowdsourced failure intake system to gather more detailed and diverse data for training and improving the system's accuracy.

#### References

1. **hngh Kernel Repository**:
   - `src/kernel/verdicts.py`: Defines the verdict classes and their budget/counter effects.

2. **External Sources**:
   - No external sources were used in this research.

---

This summary provides a comprehensive overview of the current state of the verdict taxonomy, identifies areas for improvement, and outlines actionable recommendations to enhance the system's capabilities.
