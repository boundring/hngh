<!-- plan: status=accepted risk=normal accepted=2026-10-02T04:06:25Z routed-from=review-finding:2026-10-01:current-overlay-json-regressed-gen-2-1-s -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T04:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-01:current-overlay-json-regressed-gen-2-1-s`
at 2026-10-02T04:00:41Z. Alert text: current-overlay.json regressed gen 2→1 (seed 2984719→2984731, churned fields) inside an unattributed machine commit; ui-grades shows gen2 earning 6/10 at 1.3:1 contrast, so a rollback may be warranted, but it should ride a lane commit with rationale, not the sync. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
