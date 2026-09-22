<!-- plan: status=proposed risk=normal accepted=- -->
# launch-item trio: fleet-plan unblock, dispatch ceilings, T1 evidence passes

Operator-approved launch order 3 -> 2 -> 1 (review 2026-09-22): unblock
the governed-fleet plan acceptance first (un-sticks roadmap
`Land stage 2`), then land the charter step-4 dispatch-side remainder,
then run the T1-trio evidence passes. All three lanes stay on the
automation free-commit and docs surface; any need for kernel
`src/`, `tests/`, `Makefile`, `hngh.asd` mutation outside the
certificate ceremony parks on the operator.

## Steps

- [ ] 1. UNBLOCK (review item 3) — add per-step Verification lines to
      `docs/project/plans/2026-09-13-governed-fleet-consolidation.plan.md`.
      The plan is status=proposed with a global Verification paragraph
      only; the acceptance parser
      (`automation/scripts/accept-plans.py:39`, regex
      `(?m)^[ \t]+Verification[ \t]*:`, `first_unverified_step` :153-165)
      needs an indented `Verification:` line inside each unchecked
      step's block, else it alerts
      `overnight:plan-accept-blocked:<slug>` and blocks stage 2. Use the
      README standard line `Verification: see plans/README verification
      contract; kernel `make test` green.` except where the step names a
      non-standard check (ratification record, roadmap pipe-field
      counts, backlog flips — full text there). Plain docs commit; do
      not flip the front-matter (accept-plans owns that flip).
      Verification: importing accept-plans.py, `first_unverified_step(steps_text(...))`
      returns 0 for the fleet plan; kernel `make test` green.
      SLA: same-session edit + commit. Halt: parser still rejects after
      a grammar-faithful edit -> fix to the actual grammar (parser source
      already read once); a red-gate blocker unrelated to this plan
      files an alert and parks, never widens this lane.
- [ ] 2. DISPATCH (review item 2) — charter step-4 remainder: staged
      dispatch + spend ceilings on the dispatch side. ng cadence gains a
      dispatch admission gate alongside the `_token_cap`/`_attempt_cap`
      pattern in `automation/ng/cadence.py`: daily dispatch cap (env
      `HNGH_DISPATCH_DAY_CAP` > cadence-params row `dispatch-day-max` >
      fail-closed default; operator owns the value) refusing
      dispatch-classified work with an `escalation.filed`
      reason=dispatch-capped event and defer-to-next-beat semantics
      matching the budget-exhausted handling; pre-paid-leg-first leg
      ordering (quota rows before paid-cash fallback; a cap block
      re-routes to the next window instead of stalling). Test file in
      `automation/ng/` per the `test_jcode_guard.py` standalone pattern,
      wired into the automation/Makefile test target. Automation commit.
      Verification: automation `make test` green including the new
      dispatch-gate cases (admit under cap; refuse + escalate at cap;
      deferred work survives to the next beat; leg ordering prefers
      pre-paid legs); kernel `make test` green.
      SLA: one slice, one commit, both gates green same session.
      Halt: if enforcement requires kernel-side state (src/tests/
      Makefile/hngh.asd) -> file the defect, park on operator; that is
      a charter amendment, not the remainder.
- [ ] 3. EVIDENCE (review item 1) — T1-trio evidence passes:
      hngh-8ls reader-audit-m census (six probes: catalog strict-reader
      reconciliation, hngh-catalog disposition, outside-repo
      writers/readers, path-encoding dedupe — CONFIRMED LIVE defect —,
      research TSV reader inventory, wild-catalog drift);
      hngh-6ih line-tooling damage matrix (read-only; snapshot the
      scratch `~/.jcode/scratch/nl-tooling/SETUP.md` specs into the repo
      first) + close-run-poisoning-recovery drills (kernel-test touches
      route through the certificate lane);
      hngh-ays rotate-queue-driver audit (the second certificate-driven
      mutation lane never audited). Evidence lands as docs slices; beads
      close with evidence or narrow with comments.
      Verification: each probe lands file:line evidence in a docs slice
      or a bd comment; bead states updated via bd from the hngh repo
      root; kernel `make test` green.
      SLA: evidence per probe lands as a docs slice the same session it
      is gathered. Halt: a probe needing src/tests mutation beyond the
      ceremony -> file defect, park, move to the next probe; scratch
      spec missing -> reconstruct from
      `.agent-scratch/swarm-resume/BACKLOG-2026-09-20.md` (:49-110) or
      park that node.

## Notes

- hngh-8ls correction comment already delivered 2026-09-22 00:40 (the
  live bead is reader-audit-m, not the glyph-cache item the overnight
  plan mislabeled).
- Sequencing: step 1 feeds the accepted-plans lane the step-2 gate
  supervises; step 3 is independent and may ride either side.
- Escalation discipline: every lane above carries SLA + halt condition;
  routed alerts are never reported resolved.