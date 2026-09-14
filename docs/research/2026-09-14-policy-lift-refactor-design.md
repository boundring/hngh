# Which automation-tier policies (failfirst speed state machine, causes classification table, supervision triage thresholds, model/cost routing) lift into hngh.domain/application as pure fixture-tested use cases per the charter's policy law, and which mechanisms stay behind ports (agent-supervision classify() and kernel select-course as the in-repo lift pattern)?

Status: crystallized 2026-09-14 from research line `policy-lift-refactor-design`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-policy-lift-refactor-design.md.

# Research Line Contraction — Final Structured Summary

**Line:** Which automation-tier policies (failfirst speed state machine, causes classification table, supervision triage thresholds, model/cost routing) lift into `hngh.domain/application` as pure fixture-tested use cases per the charter's policy law, and which mechanisms stay behind ports?
**State:** contracting → **closed** (final record)
**Verification constraint:** No live filesystem access to `/home/bricker/Projects/etc/hngh` or sibling repos in this transition. All file-path citations below are **user-asserted / prior-art pointers only**; I do not assert their existence beyond the vault pointers listed in References. Where a claim requires repo inspection, it is framed as an action item, not a fact.

## Findings

### F1 — The charter's policy law admits exactly four tiers into `hngh.domain/application`
Per [[sources/SRC-2026-08-18-002]] (Hngh Clean Architecture Charter), the "policy law" governs what may reside in `domain/application`: a unit qualifies iff it is a **pure function over fixtures** — no I/O, no clock reads, no process-state mutation. Applying this test to the four automation tiers yields a consistent split:

| Tier | Lifts into `domain/application` (pure) | Stays behind port (infrastructure adapter) |
|---|---|---|
| Fail-first speed state machine | Transition table over finite speed tiers keyed on failure-signal *categories* | Signal acquisition (test-runner exit codes, timeouts); actuation (re-invocation at new tier) |
| Causes classification table | Signature → cause-category mapping; the *policy* of which signature maps to which category | Log parsing, LLM calls, evidence gathering |
| Supervision triage thresholds | Threshold comparison predicates over metric vectors | Metric acquisition; escalation channel dispatch |
| Model/cost routing | Routing/selection rule over a course catalog + price snapshot | Live price feeds; model invocation |

The in-repo lift pattern for `agent-supervision classify()` and kernel `select-course` (user-asserted) confirms this decomposition is already practiced: the pure decision content lives in `domain/application`; the executor (I/O, actuation) sits behind a port. The four tiers follow the same shape.

### F2 — Volatile inputs must be *parameters*, not lifted content
Cost data and live metrics are volatile by nature. The fixture-tested artifact is the **rule parameterized by a snapshot**, not the snapshot itself:
- `select-course(catalog, price_snapshot) -> course` is pure; fetching `price_snapshot` is the port.
- Triage predicates take a metric vector as input; scraping that vector is the port.

This keeps fixtures deterministic and the policy law intact. If any current implementation bakes live values into the "policy" module, that is a charter violation to refactor out.

### F3 — Threshold constants must be injected configuration
A known risk in triage thresholds: environment-specific constants smuggled into what should be pure predicates. The policy law requires these to be **injected configuration** (fixture-provided in tests). Hardcoded literals inside comparison logic violate the purity contract and break fixture determinism.

### F4 — Fixture coverage is the acceptance test for the lift, not an afterthought
A policy has not "lifted" until it is fixture-tested as a pure function. The bar:
- Every transition/branch in the state machine has at least one fixture exercising it.
- Boundary cases (just-below / just-above threshold) are explicitly covered.
- No test may depend on wall-clock, network, or process state.

If a tier resists this decomposition — i.e., its "policy" cannot be expressed without I/O — that is itself a finding: the tier is **mechanism, not policy**, and stays put behind the port. Do not force-fit.

## Recommendations

### R1 — Apply the "decision content vs. decision executor" split to all four tiers
Decompose each tier exactly as the user-asserted in-repo pattern does for `agent-supervision classify()` and kernel `select-course`. Write the pure module first against fixtures. If a tier resists decomposition, record that resistance as a finding rather than forcing the fit.

### R2 — Treat volatile inputs as parameters
Parameterize all volatile data (prices, metrics, signals) as function arguments. The fixture provides the snapshot; the port fetches it. This preserves determinism and keeps the policy law intact.

### R3 — Audit and extract threshold constants
Audit existing threshold values in triage logic. If any are hardcoded literals inside comparison logic, extract them to injected parameters and add fixtures that exercise boundary cases (just-below / just-above threshold).

### R4 — Gate the lift on fixture coverage
Do not merge a tier into `domain/application` until its fixture suite passes under the purity contract. The acceptance test is the fixture suite itself; there is no secondary gate.

## Open Threads

1. **Repo verification of the in-repo lift pattern.** The user-asserted pattern for `agent-supervision classify()` and kernel `select-course` has not been independently verified against `/home/bricker/Projects/etc/hngh`. Action item: inspect the actual module boundaries to confirm the pure/executor split matches the charter's policy law as stated in [[sources/SRC-2026-08-18-002]].

2. **Whether any tier is irreducibly mechanism.** The decomposition assumes all four tiers yield a pure core. If, upon inspection, a tier's "policy" cannot be expressed without I/O (e.g., if the fail-first state machine inherently requires re-invocation as part of its transition), that tier stays behind the port and the recommendation set shrinks accordingly. This is an empirical question requiring repo access.

3. **Interaction with [[concepts/clean-architecture]] and [[concepts/agent-harness-governance]].** The clean-architecture positioning and agent-harness governance concepts may impose additional constraints on how ports are defined (e.g., whether a port must be a single function or may be a small interface). These vault entries have not been fully reconciled with the policy law in this line. Action item: cross-reference to ensure no conflict.

4. **Cistern Emacs Rewrite case applicability.** [[cases/cistern-emacs-rewrite]] was created 2026-09-07 and may contain a worked example of the lift pattern in practice. Its relevance to this line is unassessed. Action item: review for transferable patterns or counterexamples.

## References

- [[sources/SRC-2026-08-18-001]] — Hngh Project Intent and Architectural Charter
- [[sources/SRC-2026-08-18-002]] — Hngh Clean Architecture Charter (source of the policy law)
- [[concepts/clean-architecture]] — Clean Architecture for Agent Systems
- [[concepts/agent-harness-governance]] — Agent-Harness Governance Positioning
- [[cases/cistern-emacs-rewrite]] — Cistern Emacs Rewrite
