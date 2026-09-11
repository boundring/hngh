# Why is the kernel gate (make test rc=2) red for two days and what exact commits break the loop-history guard — can the miss be declared and re-certified through the loop without rewriting history?

Status: crystallized 2026-09-11 from research line `fail-20260911-overnight-plan-accept-gate-kernel`; per-beat
material lives in hngh-automation digest/RESEARCH-BEAT-*-fail-20260911-overnight-plan-accept-gate-kernel.md.

# Contraction — kernel gate `rc=2` & the loop-history guard (final structured summary)

**Line:** Why is the kernel gate (`make test rc=2`) red for two days and what exact commits break the loop-history guard — can the miss be declared and re-certified through the loop without rewriting history?
**Lifecycle:** expanding → **contracting** (this record is the line's lasting crystallization)
**Access caveat for this beat:** I did **not** inspect the live filesystem. Claims are grounded in (a) the prior material on this line and (b) the read-only vault pointers below. Repo-internal file paths are cited only where they came from a verified pointer; everything else is labeled **[HYPOTHESIS]**. General engineering claims that need no repo access are labeled **[GENERAL]**. No commit SHAs are asserted anywhere in this record, because naming them requires `git log` access I do not have here.

**Verdict (one line):** The miss **can** be declared and re-certified without rewriting history — via an append-only *supersede* event that marks the implicated loop iterations invalid while preserving them, followed by N clean iterations to re-certify. The two-day red is **not yet attributable to the guard**; until R1 names the first failing recipe line, "the guard broke" is a hypothesis, not a finding.

---

## 1. Findings

**F1 — `rc=2` is ambiguous and does not, by itself, implicate the loop-history guard.** [GENERAL]
GNU make exits with status 2 when *any* recipe line fails **or** when make itself errors (missing target, missing file, bad rule). So a two-day red at `rc=2` is consistent with at least three distinct failure classes:
1. a test binary/assertion failed (recipe returned nonzero → make reports 2);
2. the harness is broken (missing fixture / state file / Makefile target);
3. a build step *before* the tests failed (compile/lint), so the guard code was never even reached.
Reasoning about the guard for two days without confirming the guard is what ran is the line's central risk. This is the cheapest possible contraction and de-risks everything downstream.

**F2 — "What exact commits break the guard" is currently *unanswerable* from this beat.** [HONEST LIMITATION]
Identifying the breaking commit(s) requires (i) confirming the guard is the failing component (F1/R1) and (ii) running `git log --since="3 days ago" -- <guard/history paths>` inside `/home/bricker/Projects/etc/hngh`. I have neither, so **no commit SHA is named here by design**. Any specific commit claim in this record would be fabrication.

**F3 — The declare-and-re-certify path exists and needs no history rewrite (the firm finding).** [GENERAL + HYPOTHESIS]
If the history state is append-only / event-sourced (the line's working model, unconfirmed), a *supersede* event appended to that state declares the miss without truncation: it carries `type: supersede`, the hash/range of the loop iterations being declared a miss, the implicated commit SHA(s) (filled in once F2 is resolved), and a reason string citing this research line. The bad entries remain, marked invalid by a later entry — preserving the audit trail and the postmortem evidence. Truncating or rewriting the log would itself trip any guard worth the name and destroy that evidence. **Precondition:** the guard must treat supersession as a *first-class, non-violating* event. If it currently hard-fails on any non-monotonic entry, R3 must land before R2 is usable.

**F4 — Leading root-cause candidate: schema drift behind a non-tolerant guard.** [HYPOTHESIS]
The strongest expanding-phase candidate remains that a commit changed the history schema without a version bump or guard update, so the guard rejects what should be a parseable-but-newer record. The forward
