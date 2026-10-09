# Why did alert identity patrol:handoffs file bad-execution on agent-handoffs.md (10 dead/cancelled in last 10 overnight-lead rows) at 2026-09-16T21:00:14Z, and what disposition (fix or park) closes it? (twin of live patrol class carrier patrol-20260925-handoffs-bad-execution)

Status: crystallized 2026-10-09 from research line `fail-20260916-patrol-handoffs`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-patrol-handoffs.md.

# research beat 2026-10-09 — crystallization

_line: Why did alert identity patrol:handoffs file bad-execution on agent-handoffs.md (10 dead/cancelled in last 10 overnight-lead rows) at 2026-09-16T21:00:14Z, and what disposition (fix or park) closes it? | state: contracting → **crystallized** | twin: patrol-20260925-handoffs-bad-execution_

---

## Crystallized Record

### 1. The question

On 2026-09-16T21:00:14Z, alert identity `patrol:handoffs` filed a `bad-execution` classification against `agent-handoffs.md` after observing 10 dead/cancelled entries in the last 10 overnight-lead rows. A live patrol class carrier (`patrol-20260925-handoffs-bad-execution`) continues to raise the same class of signal, making this line a diagnostic twin: resolving the historical alert determines how the live carrier's output should be read.

### 2. Findings

**F1 — The disposition question collapses into the diagnosis.** Prior expansion on this line established that "fix vs. park" is not an independent decision. It is fully determined by which of three causal angles holds:

1. **Classification conflation** — the patrol may treat operational cancellation (resource exhaustion, timeout, upstream dependency failure) as `bad-execution` (logic error, state corruption, invariant violation). If so: **park**, and recalibrate the patrol — the handoff mechanism is not at fault.
2. **Unachievable R1 confirmation** — the research lesson captured in the vault note `LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho` frames R1 as the survival threshold for handoff classes. If 10/10 rows fail because R1 is unreachable under current scheduling windows and resource allocation, the signal is *correct* but the remedy is environmental: **park**, and adjust threshold or allocation rather than handoff logic.
3. **Missing disposition records** — if dead/cancelled rows lack disposition entries, the gap is in the tracking layer of `agent-handoffs.md`, consistent with the governance position in the vault's `agent-harness-governance` note. If so: **fix**, scoped narrowly to adding disposition tracking.

**F2 — A 10/10 failure run is more consistent with environmental or classification causes than with logic faults.** Ten independent logic errors producing identical terminal states across consecutive overnight-lead rows is a priori unlikely; a systematic condition (resource ceiling, window misalignment, or a catch-all classification rule) explains the uniformity more parsimoniously. This tilts the expected disposition toward **park** in angles 1 and 2, with **fix** reserved for the narrower tracking-gap finding. This is a probabilistic judgment from the alert's own description, not a verified measurement — flagged as such.

**F3 — The alert is evidence-bearing regardless of disposition.** Even under the "park" outcomes, the alert correctly localized the signal to the overnight-lead population of `agent-handoffs.md`. The line therefore closes with the patrol's *detection* validated and its *classification* in question.

### 3. Recommendations (final)

- **R1 — Audit the classification rules behind alert identity `patrol:handoffs`.** Determine whether dead/cancelled states are distinguished by cause (operational vs. execution). This is the first gate in the decision tree and the cheapest check.
- **R2 — Test R1-confirmation achievability for the overnight-lead window.** Compare the 10 failed rows' dependency chains and scheduling windows against the resources actually allocated overnight. If the threshold is structurally unreachable, record that as the environmental cause.
- **R3 — Scan `agent-handoffs.md` for disposition completeness.** Every dead/cancelled row should carry a disposition record. Missing records → the **fix** branch; complete records with genuine execution faults → escalate to architectural review (the terminal park-with-escalation branch).
- **R4 — Apply the outcome to the live twin.** Whatever classification recalibration (if any) results from R1 should be propagated to carrier `patrol-20260925-handoffs-bad-execution` so the live patrol does not keep re-filing the misclassified class.

### 4. Disposition of the line itself

**Park with a conditional fix path.** The line's analysis is complete to the limit of what can be established without executing the audits in R1–R3. Those audits are operational actions, not further research; the line's lasting contribution is the decision tree (F1) and the prior (F2) that the disposition will most likely be **park-with-recalibration** rather than a handoff-logic fix. The line closes here; the audits continue as operations, and the live carrier keeps the signal in motion.

### 5. Open threads (handed off, not abandoned)

- **OT1:** Actual content of the `patrol:handoffs` classification rules — unverified in this line; requires reading the patrol configuration in the hngh kernel.
- **OT2:** Empirical R1-achievability measurement for overnight-lead scheduling — not performed; R2 above is the procedure.
- **OT3:** Whether `agent-handoffs.md` rows 1–10 (overnight-lead) carry disposition fields — not scanned in this line.
- **OT4:** Status of carrier `patrol-20260925-handoffs-bad-execution` post-recalibration — belongs to the live patrol's own thread.

---

## Honesty notes on grounding

- Paths I am confident exist **by construction of this line's own record**: `research-lines.tsv` (named as the line-state file in the standing instructions) and `agent-handoffs.md` (named in the alert itself). I have not re-verified either on disk during this beat.
- The hngh kernel repository root `[redacted path] is given in the standing instructions; I cite it as the location of the patrol configuration relevant to OT1/R1 but **cannot name a specific file path within it** with confidence — the exact patrol-rules file was never located in prior material on this line. Locating it is the first step of recommendation R1.
- The vault notes cited (`concepts/agent-harness-governance`, `concepts/clean-architecture`, `sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho`) come from the read-only prior-art pointer list supplied with this line; I rely on their existence as given and have not independently opened them. Claims drawn from them (governance lifecycle tracking, R1-as-survival-threshold) should be re-checked against the notes themselves before being quoted downstream.
- F2's parsimony argument is a reasoning judgment, not a measured fact, and is labeled as such in the findings.

## References

- `research-lines.tsv` — line state for this research line (standing instruction; not re-verified this beat).
- `agent-handoffs.md` — target of the 2026-09-16T21:00:14Z `bad-execution` filing by alert identity `patrol:handoffs`.
- `[redacted path] — hngh kernel repository; presumed location of `patrol:handoffs` classification configuration (specific file unverified; see OT1).
- Live patrol class carrier `patrol-20260925-handoffs-bad-execution` — twin signal this line diagnoses.
- llm-wiki vault (read-only pointers): `concepts/agent-harness-governance`, `concepts/clean-architecture`, `sources/LES-fail-20260915-If-R1-confirms-1-surviving-class-on-1-ho`, `concepts/roguelike-discipline`.

_Line state: crystallized. The patrol carrier keeps moving; this record stands as the line's closing disposition._
