<!-- plan: status=accepted risk=normal accepted=2026-10-06T10:05:46Z routed-from=review-finding:2026-10-06:duplicate-handling-is-inconsistent-acros -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-13T10:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-06 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-06:duplicate-handling-is-inconsistent-acros`
at 2026-10-06T10:00:42Z. Alert text: duplicate handling is inconsistent across the new seed flags: `--package`/`--service` refuse duplicates naming the offender, `--repo` silently allows duplicate URLs — same fail-closed posture should apply. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
