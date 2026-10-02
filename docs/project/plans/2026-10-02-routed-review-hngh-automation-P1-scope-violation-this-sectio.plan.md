<!-- plan: status=accepted risk=normal accepted=2026-10-02T07:05:44Z routed-from=review:hngh-automation:P1-scope-violation-this-sectio -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T07:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh-automation:P1-scope-violation-this-sectio`
at 2026-10-02T07:00:41Z. Alert text: review P0/P1 (hngh-automation): P1: scope violation — this section's evidence is byte-identical to the hngh section (kernel `docs/`, plans, roadmap commits); if these commits genuinely landed in hngh-automation, kernel docs work is crossing repo boundaries; if it's packet duplication, disregard.

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
