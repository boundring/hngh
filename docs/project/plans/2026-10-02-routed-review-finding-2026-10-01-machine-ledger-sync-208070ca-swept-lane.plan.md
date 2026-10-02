<!-- plan: status=accepted risk=normal accepted=2026-10-02T06:06:25Z routed-from=review-finding:2026-10-01:machine-ledger-sync-208070ca-swept-lane -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T06:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-01:machine-ledger-sync-208070ca-swept-lane`
at 2026-10-02T06:00:41Z. Alert text: machine ledger sync 208070ca swept lane-owned `docs/` content (3 new routed plans, rewritten dev-synth plan, current-overlay.json, roadmap stage-3 flip) into a single machine commit — the exact whole-index sweep race synth-2026-10-01-3 was opened to check; the sync demonstrably lacks path-scoping/allowlist guard. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
