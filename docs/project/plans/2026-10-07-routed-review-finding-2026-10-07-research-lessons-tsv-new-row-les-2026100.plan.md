<!-- plan: status=proposed risk=normal accepted=- routed-from=review-finding:2026-10-07:research-lessons-tsv-new-row-les-2026100 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-14T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-07 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-07:research-lessons-tsv-new-row-les-2026100`
at 2026-10-07T11:00:42Z. Alert text: research-lessons.tsv new row `les-20261006-…gate-evolve-ledger-race` was inserted mid-file ahead of the 2026-09-15 lesson rows, breaking append/chronological order in a ledger treated as append-only elsewhere. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
