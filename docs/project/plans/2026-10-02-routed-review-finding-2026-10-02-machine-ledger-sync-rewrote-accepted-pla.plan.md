<!-- plan: status=proposed risk=normal accepted=- routed-from=review-finding:2026-10-02:machine-ledger-sync-rewrote-accepted-pla -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T16:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-02:machine-ledger-sync-rewrote-accepted-pla`
at 2026-10-02T16:00:41Z. Alert text: machine ledger sync rewrote accepted plan `2026-10-02-dev-fail-20261001-beat-parked-2026-09-13-gov.plan.md` in place twice (03:06 and 04:06 syncs) after auto-acceptance at 00:35:02Z (×11) — post-acceptance mutation with no re-review, confirming the already-routed P1 alerts fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
