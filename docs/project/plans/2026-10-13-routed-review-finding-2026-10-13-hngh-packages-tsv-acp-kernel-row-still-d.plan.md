<!-- plan: status=accepted risk=normal accepted=2026-10-14T00:05:44Z routed-from=review-finding:2026-10-13:hngh-packages-tsv-acp-kernel-row-still-d -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-20T11:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-13 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-13:hngh-packages-tsv-acp-kernel-row-still-d`
at 2026-10-13T11:00:12Z. Alert text: hngh-packages.tsv acp-kernel row still describes itself as "embodied in billion-context@0.1.174 … consumed inside the bili proxy" with disposition in-use — stale registry entry after the bili retirement in the same commit fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
