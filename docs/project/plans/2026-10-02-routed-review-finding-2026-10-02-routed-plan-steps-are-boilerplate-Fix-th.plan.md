<!-- plan: status=accepted risk=normal accepted=2026-10-02T15:05:46Z routed-from=review-finding:2026-10-02:routed-plan-steps-are-boilerplate-Fix-th -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T15:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-02:routed-plan-steps-are-boilerplate-Fix-th`
at 2026-10-02T15:00:41Z. Alert text: routed plan steps are boilerplate — "Fix the review finding in docs/automation with a named verification" is emitted verbatim for hngh-scoped findings (roadmap flip, ledger-sync sweep) whose fixes don't live in docs/automation; the step is unactionable as written fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
