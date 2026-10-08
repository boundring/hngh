<!-- plan: status=accepted risk=normal accepted=2026-10-08T05:06:56Z routed-from=review-finding:2026-10-07:lesson-harvest-handoffs-jumped-3467-366 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-14T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-07 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-07:lesson-harvest-handoffs-jumped-3467-366`
at 2026-10-07T11:00:42Z. Alert text: `.lesson-harvest-handoffs` jumped 3467 → 3663 (+196) in a single counter tick — plausibly legitimate, but a ~200x-per-tick rate is worth a sanity check for a harvesting loop. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
