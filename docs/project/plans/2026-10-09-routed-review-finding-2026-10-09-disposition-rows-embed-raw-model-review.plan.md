<!-- plan: status=accepted risk=normal accepted=2026-10-09T10:07:01Z routed-from=review-finding:2026-10-09:disposition-rows-embed-raw-model-review -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-16T10:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-09 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-09:disposition-rows-embed-raw-model-review`
at 2026-10-09T10:00:42Z. Alert text: disposition rows embed raw model review excerpts including markdown headers and leading "I'll search for..." preamble text into TSV fields — noisy, and any stray tab/newline in model output would corrupt column alignment fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
