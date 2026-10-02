<!-- plan: status=accepted risk=normal accepted=2026-10-02T07:05:44Z routed-from=review:hngh:P1-plan-2026-10-01-dev-synth-2 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T07:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh:P1-plan-2026-10-01-dev-synth-2`
at 2026-10-02T07:00:41Z. Alert text: review P0/P1 (hngh): P1: plan 2026-10-01-dev-synth-2026-09-24-3 had all six steps rewritten in place inside a machine sync commit (plan-identity drift on an already-routed-drift identity), and reports.md shows the same plan auto-accepted ×8 — the accept gate is re-accepting a mutated plan without dedup or re-review.

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
