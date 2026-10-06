<!-- plan: status=accepted risk=normal accepted=2026-10-06T11:06:40Z routed-from=review-finding:2026-10-06:lesson-harvest-handoff-counter-jumped-31 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-13T11:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-06:lesson-harvest-handoff-counter-jumped-31`
at 2026-10-06T11:00:41Z. Alert text: lesson-harvest handoff counter jumped 3121→3467 (+346) in a single tick commit with no accompanying change — either a runaway loop or the counter semantics drifted; worth a sanity check. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
