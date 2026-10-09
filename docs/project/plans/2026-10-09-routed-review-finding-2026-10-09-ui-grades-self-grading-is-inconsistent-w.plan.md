<!-- plan: status=accepted risk=normal accepted=2026-10-09T11:07:04Z routed-from=review-finding:2026-10-09:ui-grades-self-grading-is-inconsistent-w -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-09:ui-grades-self-grading-is-inconsistent-w`
at 2026-10-09T11:00:42Z. Alert text: ui-grades self-grading is inconsistent with its own evidence: contrast 10.1:1 graded 10/10 (03:48 gen2) while 11.8:1 graded 8/10 (04:01 gen2) and 1.1:1 graded 6/10 (02:46 gen1) — rubric is non-deterministic, undermining the "not sanded" ledger claim fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
