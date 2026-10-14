<!-- plan: status=accepted risk=normal accepted=2026-10-14T11:06:38Z routed-from=review-finding:2026-10-14:lesson-harvest-handoffs-counter-jumped -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T11:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-14:lesson-harvest-handoffs-counter-jumped`
at 2026-10-14T11:00:12Z. Alert text: `.lesson-harvest-handoffs` counter jumped 4964→6599 (+1635) in a single commit (dabbaf66) — the exact runaway-counter pattern already filed as review alert d0956e2b on 2026-10-06 ("3121→3467"); the earlier finding was never landed and the drift is accelerating. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
