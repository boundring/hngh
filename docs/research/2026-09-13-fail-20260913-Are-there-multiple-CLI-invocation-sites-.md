# Are there multiple CLI invocation sites in `lib/automation.py`, and do all of them conform to the corrected contract defined in the kernel's fix commit?

Status: crystallized 2026-09-13 from research line `fail-20260913-Are-there-multiple-CLI-invocation-sites-`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260913-Are-there-multiple-CLI-invocation-sites-.md.

### Final Structured Summary

**Research Line:** Are there multiple CLI invocation sites in `lib/automation.py`, and do all of them conform to the corrected contract defined in the kernel's fix commit?

**Lifecycle State:** Contracting

---

### Findings

1. **F1 — The Audit Question is Well-Posed but Currently Unexecuted.**
   - The line presupposes the existence of CLI invocation sites in `lib/automation.py` and the existence of a "fix commit" in the kernel repository. However, a comprehensive enumeration of CLI invocation sites within `lib/automation.py` has not been executed. Therefore, the multiplicity of invocation sites is currently unknown and is the first deliverable of this research line.

2. **F2 — The "Corrected Contract" Must Be Reconstructed from the Fix Commit, Not Assumed.**
   - The "corrected contract" is defined by a fix commit in the kernel repository. The exact details of this commit (such as its hash, date, and diff contents) are not known without further investigation. The verification method for the contract is to enumerate delegated call sites, extract the actual argument/exit-code/stdout semantics at each, and compare them against the contract as fixed.

3. **F3 — Attribution of the Fix Commit Is Exposed to a Known Failure Mode.**
   - The fix commit's attribution is subject to a known failure mode where local-time git date display can make commits appear missing or mis-ordered. To avoid this, any temporal reasoning about "before/after the fix" must be based on UTC-normalized `git log` (`--date=iso-utc` or explicit `TZ=UTC`).

4. **F4 — Prior Observations Imply the Harness Around `lib/automation.py` Was Recently Built and Verified.**
   - Observations indicate that an overnight automation harness was built, verified, and enabled as of 2026-08-25. This suggests that the `lib/automation.py` module was recently updated and verified, which may provide context for the current state of the CLI invocation sites.

---

### Recommendations

1. **Execute the Enumeration of CLI Invocation Sites.**
   - Conduct a thorough search for CLI invocation sites within `lib/automation.py` using tools like `grep` for `subprocess`, `os.system`, `Popen`, shell-out wrappers, or argument-string construction.

2. **Reconstruct the Corrected Contract from the Fix Commit.**
   - Access the kernel repository and identify the fix commit. Extract the exact details of the contract as defined in this commit.

3. **Normalize Git Date Display for Temporal Reasoning.**
   - Ensure that all temporal reasoning about commit ordering is based on UTC-normalized `git log` to avoid mis-attributions.

4. **Verify the Automation Harness.**
   - Ensure that the automation harness around `lib/automation.py` is up-to-date and correctly reflects the current state of the CLI invocation sites.

---

### Open Threads

1. **Multiplicity of CLI Invocation Sites.**
   - Determine the exact number and locations of CLI invocation sites within `lib/automation.py`.

2. **Details of the Corrected Contract.**
   - Identify the specific details of the corrected contract as defined in the fix commit.

3. **Temporal Reasoning.**
   - Ensure that all temporal reasoning is based on UTC-normalized `git log` to avoid mis-attributions.

---

### References

1. [[concepts/delegated-contract-verification]]  delegated-contract-verification *(created: 2026-08-24)*
2. [[sources/SRC-2026-08-24-020]]  Hngh Run Contract *(created: unknown)*
3. [[entities/hngh]]  Hngh Agent Kernel *(created: unknown)*
4. [[sources/obs-2026-08-25-hngh-automation-overnight-harness-built-verified-enabled]]  Observation: 
5. [[sources/obs-20

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
