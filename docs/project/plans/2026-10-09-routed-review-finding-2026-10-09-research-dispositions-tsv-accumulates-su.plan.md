<!-- plan: status=accepted risk=normal accepted=2026-10-09T10:07:01Z routed-from=review-finding:2026-10-09:research-dispositions-tsv-accumulates-su -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T10:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-09:research-dispositions-tsv-accumulates-su`
at 2026-10-09T10:00:42Z. Alert text: research-dispositions.tsv accumulates superseding rows per subject (fail-20260916-overnight-plan-accept-gate-automation has three killed rows, two explicitly contradicting each other's mechanism) with no supersedes pointer except prose ("superseding correction of the c506584d row") — consumers must parse free text to learn which row wins fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
