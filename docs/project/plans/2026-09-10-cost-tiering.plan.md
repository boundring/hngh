<!-- plan: status=accepted risk=normal accepted=2026-09-10T18:31:14Z -->
# 2026-09-10 - cost tiering: class tags and worker tiering

Operator directive 2026-09-10: local for mechanical, quota for
intelligence, paid last. Design: docs/design/cost-tiering.md.
First rungs only - no provider-key changes, no systemd lifecycle.

## Steps

- [ ] 1. Session-class plumbing (test-first). Generalize the
      SESSION_SOURCE pattern (overnight-cycle.sh, eb8c242 lineage):
      launch-session.sh appends `class=<T1|T2|T3>` to the budget
      session-run row, taken from the plan step's tag (the selector
      already knows which step it launches); untagged steps record
      class=T2. Add a selector helper `step_class <plan_file>` in
      overnight-cycle.sh parsing the first `class=` tag in the next
      unchecked step's text block. Suite test
      automation/tests/test-session-class.sh: fixture plans (tagged
      T1, tagged T2, untagged) -> helper returns the right class;
      budget row carries the class field (fixture launch-session run
      with the stub bridge pattern from test-remote-push.sh).
      Verification: suite test covers tagged, untagged, and budget-row
      cases; full `make test` green.
- [ ] 2. Class-aware model pinning in select_model (test-first).
      select_model accepts a class argument (from the selector's plan
      step): class=T1 pins the local-bench rung (skips quota and paid
      unless bench is empty), class=T2 keeps the current ladder
      (env > quota > local-bench > paid), class=T3 leaves the ladder
      untouched but the beat files an operator-item noting a T3 step
      is being executed by a session (the director should take it).
      Demotion and health gates apply to every rung as landed in
      eb8c242/e2b4701. Suite test: three classes x ladder order,
      demoted-quota interplay, T3 operator-item filed.
      Verification: suite test covers class pins for T1/T2/T3 and the
      T3 operator-item; full `make test` green.
- [ ] 3. Plan-authoring prompt line. The "Plan authoring" and
      wake-prompt blocks in overnight-cycle.sh gain the tagging
      convention line: tag each step class=T1|T2|T3 (mechanical /
      bounded intelligence / deep intelligence) so the selector can
      route cost tiers; untagged means T2. Update the
      docs/design/cost-tiering.md decomposition section pointer.
      Verification: prompt blocks carry the line (grep-checked);
      `make test` green.

## Execution notes

- Steps 1 and 2 are independent; 3 depends on neither (prompt text
  only) but lands last for a single ceremony.
- No provider keys are activated by this plan: the quota rung's
  health gate (step 9, stall-recovery) stays fail-closed.
- The class tag convention gets one line in
  docs/project/plans/README.md only after step 1 lands (kept out of
  this plan to keep the contract diff minimal - the selector tolerates
  untagged steps from day one).
