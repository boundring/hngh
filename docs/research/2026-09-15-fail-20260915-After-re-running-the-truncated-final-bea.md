# After re-running the truncated final beat, does the completed synthesis confirm or retract the optimistic-acknowledgment hypothesis with quoted code from hngh/src/api?

Status: crystallized 2026-09-15 from research line `fail-20260915-After-re-running-the-truncated-final-bea`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260915-After-re-running-the-truncated-final-bea.md.

# Final Structured Summary — Line: Optimistic-Acknowledgment Hypothesis (hngh/src/api)

**Line:** After re-running the truncated final beat, does the completed synthesis confirm or retract the optimistic-acknowledgment hypothesis with quoted code from hngh/src/api?
**Lifecycle:** contracting → **crystallized (terminal record)**
**Date of crystallization:** 2026-09-15

---

## Findings

### F1 — The hypothesis is unverified; no confirmation or retraction is warranted

The completed synthesis contains **no quoted code from `hngh/src/api`** and **no re-run artifact** demonstrating post-truncation behavior. The prior material's code block is explicitly labeled *"Pseudocode based on typical hngh patterns"* — it is an inference, not a repository quote. Without either artifact, the line cannot distinguish between:

- safe idempotent recovery after truncation (ACK sent, commit eventually succeeds, retry deduplicates), and
- premature ACK followed by lost or duplicated mutation (ACK sent, process dies before commit, retry re-applies).

The hypothesis therefore remains **unverified**. Any interim claim that it was "established" must be retracted. This is an evidence gap, not a safety verdict.

### F2 — File-path claims are unverifiable from this transition

I cannot read `~/Projects/etc/hngh` or any subpath thereof from this environment. The prior material names `hngh/src/api` and the kernel root `~/Projects/etc/hngh`, but I have no independent confirmation that either path exists, that `src/api` is the correct module for the ACK logic, or that the persistence point lives there rather than in a separate state-store or WAL module. **I say this explicitly rather than asserting it.**

### F3 — The prior art is directly on-pattern but was not integrated into the evidence base

Two vault pointers are relevant:

- `sources/async-proof-pattern-for-long-drop-ins` — "Prove long-running drop-ins with background job." This describes the exact class of problem the optimistic-ack hypothesis addresses: an operation that ACKs before its final beat completes. The pattern it prescribes (durable intent, polling/callback for final status, idempotent retry) maps one-to-one onto the recommendations below.
- `sources/obs-2026-08-25-hngh-promotion-rung-11-distributed-attestation-completed-pus` — "Observati…" (truncated in pointer). The title suggests an attestation or verification rung for hngh promotion; if it documents a completed attestation that includes code-level evidence, it may supply the missing quoted-code artifact. I cannot verify its full contents from this transition.

Neither source was cited as evidence in the prior beat. Their absence from the evidence base is itself a finding: the line contracted without consulting its own prior art.

### F4 — The re-run was never completed

No request ID, ACK timestamp, commit timestamp, state hash (before/after), duplicate-detection outcome, or failure log appears in any material on this line. The "truncated final beat" referenced in the line's name has no recorded completion. The re-run is an open action, not a finished experiment.

---

## Recommendations

These are the conditions under which the line may be re-opened (if ever) with a confirmable or retractable verdict. They are ordered by prerequisite.

**R1 — Gate confirmation on quoted kernel code.**
Do not mark the hypothesis confirmed unless the automation records: repository commit SHA, exact file path, line range, and an exact code quote showing the ACK being sent before durable state mutation or commit. If `hngh/src/api` does not exist or the API lives elsewhere, update the hypothesis to the real module path before proceeding.

**R2 — Locate the real persistence point.**
Find and quote the actual durability boundary in the kernel repository: transaction commit, WAL append, state-store apply, or equivalent. This is the "final beat" the line's name refers to. Without it, there is no reference point for "before" vs. "after" ACK.

**R3 — Require idempotency for re-runs.**
Any re-run after truncation must use a stable client operation ID. The server must deduplicate by that ID or use a transactional outbox. The pass criterion is: ACK sent → process interrupted before commit → same request retried → exactly one state mutation occurs.

**R4 — Make the pre-ACK intent durable.**
If the API returns success before commit, it must first persist a durable operation record or outbox entry. Otherwise, expose final status through polling, webhook, or callback so the client can learn whether the final beat completed. This is the pattern named in `sources/async-proof-pattern-for-long-drop-ins`.

**R5 — Do not let post-ACK failure be silent.**
If the final beat fails after ACK, the system must produce more than a log line: an alert or metric, a retry with backoff, a reconciliation task, and a dead-letter or compensation path for non-recoverable failures.

**R6 — Mandate observability fields in the re-run artifact.**
The automation should require and record: `operation_id`, `ack_time`, `commit_time`, `state_hash_before`, `state_hash_after`, `duplicate_detected`, `final_beat_status`. Absence of any one field means the artifact is incomplete and the hypothesis stays unverified.

**R7 — Block synthesis confirmation when artifacts are missing.**
Treat "quoted code + re-run result" as a hard prerequisite. If either is absent, the line's status is `unconfirmed` and no downstream claim may cite it as established.

**R8 — Treat destructive or non-idempotent mutations specially.**
Optimistic ACK is only acceptable for operations that are safe to retry or compensate. For destructive state changes, require idempotency, durable intent, or explicit client-visible finalization.

---

## Open Threads

These are the questions this line leaves unresolved. They are not failures of the synthesis; they are the work that would need to be done to move the hypothesis from *unverified* to a terminal verdict.

| # | Thread | What would close it |
|---|--------|---------------------|
| O1 | **Does `hngh/src/api` exist?** What is the real module path for the ACK logic? | A directory listing or file read of `~/Projects/etc/hngh` confirming or correcting the path. |
| O2 | **What is the actual persistence point?** Is it a WAL append, a transaction commit, a state-store apply? | A quoted code block from the real durability boundary with commit SHA and line range. |
| O3 | **Was the re-run ever completed?** The line's name presupposes a "truncated final beat" that was re-run. No artifact records its outcome. | A re-run log containing all fields in R6. |
| O4 | **Is the optimistic-ack pattern actually present in the codebase, or is it an inferred pattern?** The prior material's pseudocode is explicitly non-repository. | Either a real code quote showing pre-commit ACK, or a code quote showing the opposite (durable-intent-first), which would retract the hypothesis on different grounds. |
| O5 | **What does the attestation rung document?** The `obs-2026-08-25-hngh-promotion-rung-11` pointer may contain the code-level evidence this line needs, but its full text was not available in the prior beat. | Reading the full source from the vault and cross-referencing it against R1. |
| O6 | **Is the async-proof-pattern source prescriptive for hngh specifically?** It names a general pattern; whether hngh implements it (or should) is untested. | A mapping of the pattern's requirements onto actual hngh code paths, or an explicit gap report. |

---

## Status

**Unverified.** The line crystallizes with the hypothesis open. No claim of confirmation is supported by the available material; no claim of unsafety is either. The evidence gap is total: no quoted repository code, no re-run artifact, no verified file paths. The line's lasting record is that the question was asked, the evidence was found wanting, and the specific conditions (R1–R8) under which a future transition could produce a terminal verdict are now fixed.

---

## References

- **Prior material on this line:** `research beat 2026-09-15` (supplied in this transition). Contains the inferred pseudocode explicitly labeled "Pseudocode based on typical hngh patterns," the contracting analysis, and the interim verdict that the hypothesis cannot be confirmed.
- **Kernel repository root (unverified):** `~/Projects/etc/hngh`. Named in the prior material. I cannot verify its existence or contents from this transition.
- **API module path (unverified):** `hngh/src/api`. Named in the line's question and the prior material. No file read or directory listing confirms it.
- **Prior art pointer 1:** `sources/async-proof-pattern-for-long-drop-ins` — "Prove long-running drop-ins with background job." Read-only vault pointer; full text not available in this transition.
- **Prior art pointer 2:** `sources/obs-2026-08-25-hngh-promotion-rung-11-distributed-attestation-completed-pus` — "Observati…" (truncated). Read-only vault pointer; full text not available in this transition.
- **External sources:** None cited. All claims above are grounded in the prior material supplied in this transition or explicitly flagged as unverifiable. No external source is asserted without verification.
