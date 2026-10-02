<!-- plan: status=accepted risk=normal accepted=2026-10-02T02:06:27Z routed-from=review-finding:2026-10-01:scope-violation-this-section-s-evidence -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T02:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-01:scope-violation-this-section-s-evidence`
at 2026-10-02T02:00:41Z. Alert text: scope violation — this section's evidence is byte-identical to the hngh section (kernel `docs/`, plans, roadmap commits); if these commits genuinely landed in hngh-automation, kernel docs work is crossing repo boundaries; if it's packet duplication, disregard. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
