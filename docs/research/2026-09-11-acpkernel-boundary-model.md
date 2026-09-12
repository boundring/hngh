# ACP kernel decoupling prior art: what does acp-kernel's boundary model (one injected port, state-in/state-out, DESIGN.md s5) teach hngh's port enforcement?

Status: crystallized 2026-09-11 from research line `acpkernel-boundary-model`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-acpkernel-boundary-model.md.

### Final Structured Summary: ACP Kernel Decoupling Prior Art

**Research Line: ACP Kernel Decoupling Prior Art**

**Current Lifecycle State:** Contracting

**Objective:** To distill the prior art from the ACP kernel's boundary model (one injected port, state-in/state-out, DESIGN.md s5) and apply it to Hngh's port enforcement.

---

### Findings

1. **Single Port Injection Model:**
   - **Finding:** The ACP kernel's boundary model uses a single injected port, which simplifies the enforcement of security policies and reduces the attack surface.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/ACP/DESIGN.md` (Section 5)

2. **State-In/State-Out Model:**
   - **Finding:** The state-in/state-out model ensures that only valid states are allowed in and out of the system, maintaining the integrity of the system and preventing unauthorized or malicious state transitions.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/ACP/DESIGN.md` (Section 5)

3. **Boundary Model Analysis:**
   - **Finding:** The ACP kernel's boundary model provides a robust framework for managing the flow of data and ensuring that the system remains secure.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/ACP/DESIGN.md` (Section 5)

4. **Security Policy Enforcement:**
   - **Finding:** Security policies should be designed to align with the single port injection and state-in/state-out models to ensure that the system remains secure.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/ACP/DESIGN.md` (Section 5)

5. **Testing and Validation:**
   - **Finding:** Comprehensive testing and validation processes are crucial to ensure that Hngh's port enforcement is robust and effective.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/Tests/` (Various test cases and scripts)

---

### Recommendations for Hngh/Hngh-Automation

1. **Single Port Injection Model:**
   - **Recommendation:** Adopt a single port injection model for Hngh's port enforcement to maintain clear boundaries and simplify security measures.
   - **Rationale:** The ACP kernel's boundary model uses a single injected port, which simplifies the enforcement of security policies and reduces the attack surface.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/ACP/DESIGN.md` (Section 5)

2. **State-In/State-Out Model:**
   - **Recommendation:** Implement a state-in/state-out model for Hngh's port enforcement to ensure that only valid states are allowed in and out of the system.
   - **Rationale:** This model helps in maintaining the integrity of the system by ensuring that only valid states are processed, which can prevent unauthorized or malicious state transitions.
   - **Repository Reference:** `/home/bricker/Projects/etc/hngh/ACP/DESIGN.md` (Section 5)

3. **Boundary Model Analysis:**
   - **Recommendation:** Conduct a detailed analysis of the ACP kernel's boundary model

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
