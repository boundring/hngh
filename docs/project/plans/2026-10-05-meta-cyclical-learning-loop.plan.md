<!-- plan: status=accepted risk=normal accepted=2026-10-05T05:06:28Z cause=missing-design held=2026-10-05T04:01:30Z -->
principle: evidence-before-claims -- a lesson is a claim about the world and must ride an evidence row through the two-sided review gate (docs/design/descent.md; canon method per docs/records/2026-09-25-p10-refoundation-close.md)
# Meta-cyclical learning loop over Hngh state changes

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

Design: docs/design/meta-cyclical-learning.md. Evidence of the
signal distribution: docs/agent-notes/jevify-2026-10-05-state-changes.md
(107 state changes judged; 40 carried operational lessons).

## Steps

- [ ] Cause-stamp and route the agent-handoffs delta: teach
      automation/cadence/calendar/daily/01-lesson-harvest.sh to stamp
      cause=class on rows lacking one via automation/lib/causes.sh
      classify_cause, and route knowledge-signal rows through
      append_research_subject (the single choke point - it inherits
      dedup, redaction, and the filing budget; no new ledger).
      Verification: failing test first (automation/tests/), one line
      added to automation/Makefile's explicit test recipe list; the
      test fails before the change and passes after; make test green.
- [ ] Loop-event identity in the report queue: classify:<source>
      identity rows (86400 dedup window, precedent
      dash-selfreview:<check>) so classification runs are visible to
      dashboard/patrol consumers without new surfaces.
      Verification: a unit test asserting dedup and the xN occurrence
      bump on repeat within the window.
- [ ] Weekly meta-check drop-in (automation/cadence/calendar/, mirror
      of the existing drop-in pattern): measures cause-recurrence per
      cause class against the prior window, retires stale
      research-lessons.tsv rows to retired, and reports which descent
      weekly checks (docs/design/descent.md:177-184) remain unwired.
      Verification: hermetic test with a fixed fixture of handoff and
      lesson rows asserting both the recurrence number and the
      retirement transition.
- [ ] Adoption-gate visibility: the meta-check flags any disposition
      row without a named consumer (docs/design/descent.md:137 says
      nothing enforces this today - the loop makes the gap visible
      before it makes it enforced).
      Verification: fixture disposition with empty consumer surfaces
      in the meta-check output.
- [ ] Reconcile the stale demand-wire notes (docs/design/descent.md
      :73-80, docs/design/bestiary.md:76 'designed, not built') with
      the live wire (append_research_subject, patrol auto-queue,
      synthesizer, two-sided review).
      Verification: grep both files for 'not built' returns nothing;
      docs links from docs/design/meta-cyclical-learning.md resolve.
