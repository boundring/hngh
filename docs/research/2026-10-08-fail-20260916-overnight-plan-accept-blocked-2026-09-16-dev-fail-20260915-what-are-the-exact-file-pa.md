# What closes alert identity overnight:plan-accept-blocked:2026-09-16-dev-fail-20260915-What-are-the-exact-file-pa (plan not auto-accepted: step 2 has no Verification line), and is that failure mode still reachable?

Status: crystallized 2026-10-08 from research line `fail-20260916-overnight-plan-accept-blocked-2026-09-16-dev-fail-20260915-what-are-the-exact-file-pa`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260916-overnight-plan-accept-blocked-2026-09-16-dev-fail-20260915-what-are-the-exact-file-pa.md.

# Crystallization Record — Contracted Line

_line: What closes alert identity overnight `plan-accept-blocked:2026-09-16-dev-fail-20260915-What-are-the-exact-file-pa` (plan not auto-accepted: step 2 has no Verification line), and is that failure mode still reachable? | state: contracting -> closed (crystallized) | transition: final structured summary_

---

## 0. Epistemic Status (read first)

This record consolidates prior material on the line. **Limitation carried forward from the prior beat:** the hngh kernel working tree and the automation tree were not directly readable in the transitions available to this line; no file contents were verified byte-for-byte. Claims below are tiered:

- **Tier A — grounded in the line's own context:** the line state file `research-lines.tsv` (given as the state of record), the hngh kernel repository root `[redacted path] (given as the kernel location), and the vault prior-art pointers listed in §5.
- **Tier B — inferred from prior-art descriptions:** anything about sweep behavior, acceptance logic, or intake flow as *described* by the vault notes. These describe behavior at the time the notes were written; current reachability requires re-verification.
- **Tier C — explicitly unverified:** specific file paths *inside* the repos (schema files, sweep scripts, acceptance modules). None are asserted to exist. Where a fix requires locating one, the verification step is stated.

No external sources are relied upon; none were verifiable from this line.

---

## 1. Findings

**F1. The alert identity describes a two-clause event, not a single fact.**
`plan-accept-blocked:2026-09-16-dev-fail-20260915-…` encodes (a) the blocking condition — step 2 of the plan carried no Verification line — and (b) the mechanism — auto-acceptance refused the plan on the overnight (unattended) path. Any durable fix must address both: the *condition* (authoring-side) and the *mechanism* (acceptance-side). Treating it as only "add a Verification line" leaves the silent-drop mechanism intact.

**F2. The failure mode should be treated as reachable and enforced (Tier B).**
The prior art points in one consistent direction:
- `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` describes a disposition sweep that *actively filters* accepted plans — evidence that a post-hoc gate exists and bites.
- `[[sources/SRC-2026-08-24-030]]` (overnight multi-agent sprint case study) shows acceptance logic running unattended — the same operational context in which the 2026-09-16 block fired.
Nothing in the line's material suggests the gate was removed. Absent contrary evidence, the correct operating assumption is: **a plan whose any step lacks a Verification line will still fail overnight auto-acceptance.** The blocking question this line could not close is *where* the gate lives (see F3).

**F3. The gate's location is unresolved, and it is the only thing that determines the fix.**
Two candidate sites, mutually exclusive in implication:
- **Parse/validation time** — the plan loader in the hngh kernel rejects steps missing a Verification field. Consequence: deterministic, schema-level failure; the plan never appears accepted.
- **Disposition time** — a sweep re-evaluates already-accepted plans and downgrades those lacking verification. Consequence: a window exists where the plan *appears* accepted and is later silently revoked — the worse failure mode, because it corrupts downstream state that assumed acceptance.
The prior material's framing ("plan not auto-accepted") is consistent with either; it does not disambiguate.

**F4. The rejection is observed only from the submitting side (Tier B/C).**
The alert identity and the failure notes describe the block as experienced by the submitter. No material on this line evidences a structured rejection record (plan id, failing step index, missing field) emitted at the point of refusal. This gap is exactly the class `[[concepts/crowdsourced-failure-intake]]` was created to close — but whether the intake is wired to this gate is **unverified**.

**F5. The three sibling failure lessons from 2026-09-15 share a root cause.**
`[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]`, `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]`, and `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` are all *uncertainty-about-the-system* failures, not execution failures. Combined with this line, the pattern is: operators (human or agent) cannot enumerate the automation's concrete touchpoints — paths, schemas, gates — from the artifacts alone. That meta-finding outlives this specific bug.

---

## 2. Recommendations (lasting)

**R1. Disambiguate the gate before any code change — one decisive experiment.**
Take the original blocked plan from the 2026-09-15 failure, add a Verification line to step 2 *only*, and re-submit through the overnight path against the current kernel.
- **Accepts** → Verification line is the sole gate; proceed to R2 with the authoring-side fix.
- **Still blocks** → a second condition exists; the line's single-cause framing was wrong, and a new line should open on the actual predicate.
This experiment also *answers the line's reachability question directly* on the current codebase.

**R2. Shift the failure left: refuse at queue time, not at acceptance time.**
Whichever site owns the gate, `hngh` or the automation wrapper should reject a plan at authoring/queue time when any step lacks a Verification line, with an error naming the step index. This converts an overnight silent-drop into a same-second authoring error and is the cheapest durable fix regardless of R1's outcome.

**R3. Emit a structured rejection record where the alert identity closes.**
The gate (validator or sweep) should log, per rejection: plan id, failing step index, missing field, gate identity. This feeds `[[concepts/crowdsourced-failure-intake]]` and makes the next occurrence of this alert class self-describing. **Precondition (unverified):** confirm whether any rejection logging exists today; the submitting-side-only framing of the prior material suggests it does not.

**R4. Do not relax the gate to close the alert.**
The disposition sweep halving accepted plans is plausibly the gate *working* (Tier B). The defect is the *silence and timing* of the rejection, not its existence. Any fix that makes plans without Verification lines auto-accept trades a visible, recoverable failure for latent unverified work.

**R5. Address the meta-finding (F5) as its own work item.**
Produce a single authoritative enumeration of the automation's touchpoints — plan file paths, the `research-lines.tsv` schema, gate locations — checked into the repo it describes, so the answer to "what are the exact file paths" is a document, not a research line.

---

## 3. Open Threads (handoff)

| # | Thread | Blocking check |
|---|--------|----------------|
| T1 | Gate location: parse-time vs. disposition-time | Run the R1 experiment |
| T2 | Does a rejection record exist at the gate? | Read the sweep/acceptance code path in `[redacted path] |
| T3 | Is `crowdsourced-failure-intake` consuming rejection events from this gate? | Trace intake inputs after T2 resolves |
| T4 | Current reachability on *today's* kernel (all prior evidence is ≥ 2026-09-16 vintage) | R1 experiment doubles as this check |
| T5 | Touchpoint-enumeration document (R5) — owner and location undecided | New line if adopted |

---

## 4. Line Disposition

**Contracted to a stable record.** The line's answer, in one sentence: *the Verification-line gate on overnight auto-acceptance is presumed reachable and enforced; the failure's true defect is that rejection is silent, late, and unlogged — fix by failing loud at authoring time (R2) and recording rejections at the gate (R3), after locating the gate with the R1 experiment.* Further progress requires repository read access that this line did not have; T1–T5 are the continuation surface.

---

## 5. References

**Repositories (paths given in this line's context; contents unverified):**
- `research-lines.tsv` — line state of record (this repository)
- `[redacted path] — hngh kernel repository root

**llm-wiki vault (read-only pointers, as provided):**
- `[[sources/LES-fail-20260915-Does-the-obs-2026-08-25-hngh-automation-]]` — Research Lesson (truncated title as given)
- `[[sources/LES-fail-20260915-Does-the-research-lines-tsv-schema-inclu]]` — Research Lesson (truncated title as given)
- `[[sources/LES-fail-20260915-What-are-the-exact-file-paths-for-the-ca]]` — Research Lesson (truncated title as given)
- `[[concepts/crowdsourced-failure-intake]]` — Crowdsourced Failure Intake (created 2026-08-24)
- `[[sources/SRC-2026-08-24-030]]` — Case Study: Overnight Multi-Agent Sprint (2026-08-24)
- `[[sources/backlog-disposition-sweep-reduces-accepted-plans-by-half]]` — Evidence-gated disposition sweep (truncated title as given)

**Explicitly not referenced:** no schema file, sweep script, acceptance module, or other in-repo path is cited, because none could be verified from this line. Any future record that names such a file should be treated as superseding this one on F3/T1.
