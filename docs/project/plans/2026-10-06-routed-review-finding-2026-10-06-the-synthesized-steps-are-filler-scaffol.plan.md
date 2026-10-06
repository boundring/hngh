<!-- plan: status=accepted risk=normal accepted=2026-10-06T11:06:40Z routed-from=review-finding:2026-10-06:the-synthesized-steps-are-filler-scaffol -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-13T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-06:the-synthesized-steps-are-filler-scaffol`
at 2026-10-06T11:00:42Z. Alert text: the synthesized steps are filler scaffolding (echo a fixed timestamp, grep for EXIT_CODE/DIGEST markers) disconnected from the stated cadence-monitoring rationale — "verifiable" is satisfied syntactically, not semantically. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
