<!-- plan: status=accepted risk=normal accepted=2026-10-11T11:06:52Z routed-from=ux-review:email-digest:3-defect-518-accepted-plans-with-uncheck -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T11:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:email-digest:3-defect-518-accepted-plans-with-uncheck`
at 2026-10-11T11:00:41Z. Alert text: 3. defect: "518 accepted plans with unchecked steps" and "0 executed (24h)" state the stall but do not name the blocking condition — is it a resource lock? a missing input? a human gate? fix: add one concrete blocker per stalled plan group. file: `pace: stalling` summary line. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
