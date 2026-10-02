<!-- plan: status=accepted risk=normal accepted=2026-10-02T01:06:32Z routed-from=review-finding:2026-10-01:synth-2026-10-01-3-disposition-is-parked -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T01:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-01:synth-2026-10-01-3-disposition-is-parked`
at 2026-10-02T01:00:41Z. Alert text: synth-2026-10-01-3 disposition is `parked` with the generic reason "typed verdict parked (confidence 0.88)" while the line's own doc admits zero verification (no filesystem walk; core question — which sync shape — unanswered); the disposition reason should record that basis, especially given the adjacent sync commit evidencing behavior 2. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
