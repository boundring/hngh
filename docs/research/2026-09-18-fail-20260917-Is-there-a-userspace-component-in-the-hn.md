# Is there a userspace component in the hngh repository, separate from the kernel OMP bridge, that implements a policy engine with a runtime plugin registration API for non-standard predicate URIs?

Status: crystallized 2026-09-18 from research line `fail-20260917-Is-there-a-userspace-component-in-the-hn`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260917-Is-there-a-userspace-component-in-the-hn.md.

# Research Line Contraction Record

**Line:** Is there a userspace component in the hngh repository, separate from the kernel OMP bridge, that implements a policy engine with a runtime plugin registration API for non-standard predicate URIs?

**State transition:** contracting → contracted (distilled)

**Evidence status at contraction:** unresolved. File-level confirmation remains pending. The line is closed as a record, not as a verified claim.

---

## Findings

The line decomposes into three independently verifiable sub-claims. None reached confirmation at the file level during the contracting phase; all remain in the unverified state.

1. **Userspace component exists, architecturally separate from the kernel OMP bridge.**  
   The kernel repository at `[redacted path] contains the OMP bridge as an in-kernel enforcement path. Whether a parallel userspace component exists is unconfirmed. Directory enumeration against the repository tree has not been executed in this process, and no subdirectory name (e.g., `userspace/`, `policy/`, `bridge-client/`, `predicate/`) has been verified to host policy logic.

2. **That component implements a policy engine.**  
   A policy engine, by definition, evaluates predicates against agent state or actions rather than merely forwarding them. The prior art references an "Hngh Component Map" and a Cedar-based property testing source, but neither has been read to file-level granularity. The AgentSpec prior art describes a *design pattern* for customizable runtime enforcement in LLM agents; it does not establish that hngh instantiates one.

3. **The policy engine exposes a runtime plugin registration API for non-standard predicate URIs.**  
   If sub-claims 1 and 2 hold, a registration entry point (e.g., `plugin_register`, `register_predicate`, `uri_handler_register`, or equivalent dynamic-loading idioms) would be expected. No such symbol has been confirmed. A miss in search does not refute the claim, but a hit would confirm both sub-claims 1 and 3 simultaneously.

**Verification boundary:** I cannot execute live filesystem queries against `[redacted path] or read vault sources directly. All architectural claims about the OMP bridge's userspace counterpart, plugin registration surface, and predicate URI dispatch require verification against the live tree and the Hngh Component Map. Where external sources are needed, I state explicitly that they cannot be verified without live access.

---

## Recommendations

These are the minimal, ordered actions that would move the line from unresolved to confirmed or refuted. They are preserved as the line's lasting operational record.

**R1 — Cross-reference the Hngh Component Map against the live repository tree.**  
Enumerate top-level directories in `[redacted path] and match each name against the component map's listed components. Prioritize directories whose names suggest userspace policy evaluation. Verify that any path cited by the component map actually exists before treating it as evidence. This is the single highest-leverage step for closing the line.

**R2 — Search for plugin registration symbols in userspace binaries.**  
In the hngh repository and any sibling automation repository, grep for:
- `plugin_register`, `register_predicate`, `predicate_plugin`, `uri_handler_register`
- `non_standard_uri`, `custom_predicate`, `ext_predicate`
- Dynamic-loading patterns (`dlopen`/`dlsym`/`module_load` in C/C++/Rust, or equivalent idioms)  
A hit in a userspace binary (not the kernel module) would confirm sub-claims 1 and 3. A miss narrows the search space but does not refute the line.

**R3 — Isolate the test harness topology based on architectural placement.**  
If a userspace policy engine is confirmed, `hngh-automation`'s test harness must target it directly (unit tests against the plugin API, integration tests against predicate URI dispatch) rather than only exercising the kernel bridge. If no userspace component exists, the automation topology should be scoped to in-kernel OMP bridge coverage. The test graph changes depending on where policy logic resides.

---

## Open Threads

- **Architectural boundary:** The exact boundary between kernel OMP bridge enforcement and potential userspace policy evaluation remains unbounded. Until the component map is cross-referenced against the live tree, the line cannot be closed definitively.
- **Plugin registration surface:** The naming convention, entry point, and dispatch mechanism for non-standard predicate URIs are unknown. Symbol search in userspace binaries is the only remaining verification path.
- **External prior art relationship:** The AgentSpec design pattern and Cedar property-testing source inform the hypothesis but do not establish instantiation. Their relationship to hngh's actual implementation requires direct reading of the vault sources, which I cannot perform.
- **Automation impact:** The test topology for `hngh-automation` is currently speculative. It will resolve only after R1 and R2 are executed.

---

## References

- `[[sources/SRC-2026-08-24-027]]` Hngh Component Map *(created: unknown)*
- `[[sources/SRC-2026-08-24-036]]` Cedar: property-based testing of a policy engine *(VGD: model + DRT)*
- `[[syntheses/portfolio-index]]` Engineering Portfolio and Research Index *(created: unknown)*
- `[[entities/hngh]]` Hngh Agent Kernel *(created: unknown)*
- `[[sources/SRC-2026-08-24-003]]` AgentSpec: Customizable Runtime Enforcement for Safe LLM Agents *(created: unknown)*
- `[[sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho]]` Research Lesson: If R1 confirms 1 surviving class on 1 ho *(created: unknown)*

**Repository root:** `[redacted path]  
**Note on verification:** This contraction record cites only the repository root and the prior art pointers provided in the prompt. No concrete subdirectory or filename has been confirmed to exist. Claims requiring live filesystem access or direct vault reading are explicitly marked as unverified.
