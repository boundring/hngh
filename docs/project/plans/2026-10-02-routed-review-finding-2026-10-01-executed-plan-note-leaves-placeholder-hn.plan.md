<!-- plan: status=accepted risk=normal accepted=2026-10-02T04:06:25Z routed-from=review-finding:2026-10-01:executed-plan-note-leaves-placeholder-hn -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T04:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-01:executed-plan-note-leaves-placeholder-hn`
at 2026-10-02T04:00:41Z. Alert text: executed-plan note leaves placeholder `hngh: candidate <hash>` instead of the actual certificate hash — the record's own traceability requirement is unmet. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
