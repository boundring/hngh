# 2026-09-25 — Canon audit and refoundation charter

## What this records

Operator thought experiment (2026-09-25): what parts of Hngh conflict with its
base principles, now informed by the annotated Chinese classics
(~/Projects/etc/tao-confucian-canon, six classics), broad-handed, no part of
Hngh sacred. The audit found ten conflicts (R1-R10) plus one law violation
(RJ, typed-decision sufficiency). This record preserves the findings, the
adopted strategy, and the capability test the refoundation enforces.
Execution rides the approved refoundation plan (phases P0-P10; one green
committed slice per phase).

## The ten conflicts (ranked; anchors are hints — reread before citing)

R1 Checks hoard. Chuang Tzu's mirror mind ("responds but does not retain")
   names the seam: a check that retains is not a check. Evidence: reports.md
   grew past 176k rows under a 7d re-fire window with no rotation; STATE.md
   21MB unbounded; mounting-churn crumbs ~900 rows/12h (tier-launching
   scripts are not signals); one parked condition rang x79. Tao Te Ching
   ch.48 (subtraction) is the cure: retention without a reader is deleted.
R2 Names unrectified. Analects 13.3 ("if names be not correct...") — the
   chain is our incident history. Evidence: hngh-overnight.timer names an
   overnight lane that is really a lead lane; scripts/omp-bridge drove jcode
   sessions with no scripts/jcode-bridge alias since 2026-09-14; repo-root
   scripts/ and automation/scripts/ share names under different law; the
   sibling hngh-automation/ name lures edits (guard rule now interrupts).
R3 Position without timing. One static `## Next` bullet, three pickers, no
   set= date, no TTL: pooled-hardware sat 31 days. A pointer without a clock
   is operator memory, not machine state.
R4 Supervision has two categories (active / evictable). idle-360m evicts
   slow-valid work; Zhuangzi's goose and tree (different categories, one
   knife) name the failure. Slow work emitting evidence must keep running.
R5 Ceremony is medicine without decay review. 2026-09-24: 88.67s job wall vs
   3.68s instrumented drive steps, ~20min session-level cost; lanes binary,
   no proportion; the flexibility doctrine accretes amendments because no
   graduated middle rung exists.
R6 Research starves gewu. Beats spend budget re-establishing structure
   instead of investigating things (Daxue: extend knowledge from the known);
   filings without ground truth still beat.
R7 Initiative without restraint. Filings about filings; Tao Te Ching ch.67
   (three treasures; not daring to be first) — self-referential initiative is
   the wrong courage.
R8 Gates refuse without reporting. A quota pacer block dead-ends a session
   and the watchers never hear. A refusal is a state change and belongs on
   the spine, re-queued at the next cheaper tier.
R9 Two homes plus three sensory channels, not one spine. The crumbs journal,
   reports.md, and the derived index answer the same question three ways.
R10 The canon method (adversarial pairing + recorded Disagreements) binds at
   four named seams but not at plan acceptance or architecture decisions.

RJ Typed-decision sufficiency, violated at two sites:
automation/cadence/calendar/daily/06-review-disposition.sh falls back to
legacy prefixes when typed is unavailable, and
automation/cadence/hour/33-research-beat.sh keeps the legacy verdict on low
typed confidence. A decision must carry a typed record or park.

## The admission rule (adopted)

docs/design/hngh-minimal-core-spec.md:118-131: every capability that
survives states five answers — which registry DECLARES it, which guard FAILS
CLOSED on it, which patrol WATCHES it, which certificate (if any) GATES it,
which disposition ledger RECORDS it. Missing any -> not admitted -> removed
in its phase.

## Preserved-lessons contract (condensed; authority = lessons-index.md + records/)

L1 plan supply is the bottleneck; blocked acceptances alert and re-queue.
L2 findings-only output contracts.
L3 monitoring never hides state; alert identities carry expiry; a route must
   consume or close its cause.
L4 lint gates catch whole error classes.
L5 cure tools get cadence callers at birth.
L6 the steer-vs-die rule (was OPEN) is decided by the supervision phase.
L7 launch-path tests pin their stub; tests register in the gate at birth.
L8 named measurement bases; size ceilings on ingest.
L9 alert seams proven against fake queues.
L10 continuous targets only.
L11 certificates persist at mint time.
L12 never clauses / ten closed principles / certificate path stay verbatim
   and mechanical; interpretation never admits, refuses, or overrides.

## Decision

Strangler evolve in-repo (minimal-core spec :452-461), not fork. Measured
pivot hooks preserved: extraction tax > ~2x rewrite estimate, >=2 slices
stall 30 days, or net reduction stalls above -10k LOC after R1-R4 ->
evaluate pivot (spec :465-510). Canon voices stay non-endorsed; the method
binds (interpretation doctrine).

## Preserved verbatim

GOVERNANCE.md:111-207 SHA-256 at time of writing:
76d6e5d1a2ad4f611d75dcf06d9d97ed2e64eb7cf94756ba5aaebab738a50d43
The closing phase re-checks this hash.
