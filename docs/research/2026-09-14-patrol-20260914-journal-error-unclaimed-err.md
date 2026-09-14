# patrol: surface journal-error filed unclaimed-err on two consecutive runs -- why does it keep failing and which guardrail closes it?

Status: crystallized 2026-09-14 from research line `patrol-20260914-journal-error-unclaimed-err`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-patrol-20260914-journal-error-unclaimed-err.md.

# Contracted record: patrol `unclaimed-err`

**Lifecycle:** contracting → contracted  
**Line:** patrol: surface journal-error filed unclaimed-err on two consecutive runs — why does it keep failing and which guardrail closes it?

## Verification boundary

This transition has no verified live read access to individual files in the working repository or `/home/bricker/Projects/etc/hngh`. Therefore, I do not assert specific source-file paths, function names, constants, error-code definitions, or upstream issue identifiers unless they are already present in the supplied prior material.

Claims below are grounded in:

- the prior material attached to this research line;
- the named prior-art pointers;
- the supplied kernel repository root, `/home/bricker/Projects/etc/hngh`.

Where a claim depends on unverified repository detail or external source content, it is marked as an open thread rather than asserted.

---

## Short answer

The recurring `filed unclaimed-err` failure persists because the journal-error is being filed but is not reaching a terminal state — claimed, waived, or closed — before the patrol run is scored. The error therefore remains open, resurfaces on the next run, and advances the consecutive-failure count without a clear owner or closure condition.

The guardrail that closes this line is a narrow **run-close invariant**:

> Every journal-error filed during a patrol run must be claimed or explicitly waived before that run can be scored as clean.

If any filed error remains unclaimed and unwived, the run should fail with reason `unclaimed-err`, carrying enough metadata to attribute the failure:

- error ID  
- line ID  
- run ID  
- filing surface  
- expected claim owner  
- linked issue or waiver ID, if present  

If the root cause is an already-filed upstream hngh guardrail bug, the close condition is not another broad block. It is:

1. link the recurring `unclaimed-err` surface to the filed issue; and  
2. either land the fix or record a bounded waiver with an explicit recheck condition.

The exact kernel module, threshold constant, upstream issue ID, and file paths are **not verified in this transition**.

---

## Findings

### 1. The failure is a claim-side lifecycle gap, not merely a journal-filing bug

The prior material establishes the recurring shape:

- error filed: yes  
- error claimed: no  
- run scored as clean or ambiguous: likely  
- same error resurfaces next run: yes  
- consecutive-failure counter advances: yes  

That means the system is correctly surfacing something, but it is not closing the loop. The journal-error exists, but no terminal state is reached before scoring.

This is the core reason the line keeps failing: the failure is not that the error fails to file; it is that the filed error has no enforced path into a resolved state.

### 2. Recurrence happens because the run can close without resolving the claim

If a patrol run can be scored as clean while a filed journal-error remains unclaimed and unwived, then the error line has no durable owner. The next run sees the same unresolved condition and files it again.

That produces a recurring patrol surface with no clear closure point.

The guardrail must therefore sit at **run close**, not merely at filing time.

### 3. Two consecutive surfaces make this dangerous because of demotion/cancellation pressure

The prior-art pointer `[[sources/outcome-demotion-at-two-consecutive-failures]]` names the relevant risk: consecutive bad-execution outcomes can trigger cancellation or demotion.

I cannot verify the full content of that source in this transition, but the named pointer is sufficient to treat the two-consecutive-failure threshold as a live constraint on this line.

That matters here because an unclaimed error can keep advancing the counter even though it may be:

- a known tracking gap;
- an upstream guardrail bug already filed;
- or a missing claim/waive transition in the run-close path.

Without closure, the line sits near the threshold where cancellation/demotion becomes likely, even if the underlying issue is already understood.

### 4. The closing guardrail is a run-close invariant, not a broader patrol block

The guardrail that closes this line is:

> No patrol run may be scored clean if any journal-error filed during that run remains unclaimed and unwived.

This is narrow enough to be enforceable and durable.

It converts the recurring surface from an anonymous failure into a correctly attributed run failure.

### 5. “Waived” must be a first-class terminal state, not an implicit absence of work

Some errors may be intentionally left unclaimed while an upstream fix is pending. That is legitimate only if it is explicit.

A valid waiver must record:

- reason  
- owner  
- linked upstream issue or internal tracking ID  
- expiry or recheck condition  
- the surface that filed the waiver  

Without a valid waiver, the error remains open and the run cannot close cleanly.

This distinction matters because it separates two different failure shapes:

- **logic failure:** the claim path is broken; no one can claim the error.  
- **tracking failure:** the error is known, filed upstream, but not yet fixed.  

The first needs a code fix. The second needs linkage and a bounded waiver. Conflating them produces either false confidence or repeated anonymous failures.

### 6. Attribution is required to stop the recurrence from becoming demotion pressure

A recurring `unclaimed-err` should not be treated as a new anonymous failure each time it appears. It should carry stable identity:

- error ID  
- line ID  
- run ID  
- filing surface  
- expected claim owner  
- linked issue or waiver ID, if present  

That lets the system distinguish:

- a genuinely new failure;
- a known unresolved tracking gap;
- an upstream bug awaiting fix;
- a missing waiver.

Without that attribution, the line keeps failing in the same shape and accumulates consecutive pressure without closure.

---

## Recommendations

### 1. Enforce a run-close guardrail for `unclaimed-err`

Add or verify a run-close check in hngh / hngh-automation with this rule:

> If any journal-error filed during the run remains unclaimed and unwived, fail the run with reason `unclaimed-err`.

The failure should not be silent. It should name:

- which error was left open;
- where it was filed;
- which line owns it;
- which run is failing because of it;
- what linked issue or waiver should have closed it, if one exists.

This is the primary guardrail that closes the line.

### 2. Make `waived` an explicit terminal state

Do not allow “no claim” to mean “no problem.”

A waived error must be a real state with required fields:

- reason  
- owner  
- linked issue or internal tracking ID  
- expiry or recheck condition  
- filing surface  

This makes the lifecycle honest:

- filed → open  
- claimed → in progress  
- waived → intentionally deferred, bounded  
- closed → resolved  

Without that, the system cannot tell whether an error is forgotten, blocked, or deliberately pending.

### 3. Link the recurring `unclaimed-err` surface to the filed issue or waiver

If this recurrence is caused by an already-filed upstream hngh guardrail bug, the line should not keep failing anonymously.

It must be linked to:

- the upstream issue, if one exists; or  
- the internal waiver, if the gap is being tracked locally.

The close condition is then one of two things:

1. the fix lands and the recurring surface stops; or  
2. a bounded waiver exists with an explicit recheck condition.

Until then, the run-close guardrail should keep failing the run in a correctly attributed way.

### 4. Keep consecutive-failure accounting tied to resolved state

The two-consecutive-failure pressure is dangerous if the same unresolved error keeps advancing the counter without closure.

The system should distinguish:

- a new failure;
- a recurring known unclaimed error;
- a waived pending-upstream issue.

That does not mean the run should be scored clean. It means the failure should be attributed, not anonymized.

The guardrail still fails the run if the error is unresolved. But the accounting should know why it is failing and what would close it.

### 5. Make the patrol surface report claim state, not only filing state

The patrol surface should not stop at “error filed.” It should also show:

[truncated at model call: completion hit the max_tokens cap (finish_reason=length) - re-run the beat]
