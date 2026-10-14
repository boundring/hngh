<!-- plan: status=accepted risk=normal accepted=2026-10-14T08:06:38Z routed-from=review:hngh:P1-scope-violation-2026-10-12- -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T08:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh:P1-scope-violation-2026-10-12-`
at 2026-10-14T08:00:12Z. Alert text: review P0/P1 (hngh): P1: scope violation — `2026-10-12-dev-env-contract-checkable.plan.md` is fully re-scoped in each of three consecutive "ledger sync" commits (cadence runner → dry-run pipeline → job-output validator → cadence output normalization), while reports.md records that same plan id auto-accepted ×4; an accepted plan silently rewritten under an acceptance granted to a different body defeats the accept-plans admission gate

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
