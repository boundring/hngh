<!-- plan: status=accepted risk=normal accepted=2026-10-02T14:05:48Z routed-from=review-finding:2026-10-02:current-overlay-json-gen-oscillates-1-2 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T12:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-02:current-overlay-json-gen-oscillates-1-2`
at 2026-10-02T12:00:41Z. Alert text: current-overlay.json `gen` oscillates 1→2→1 across consecutive syncs and `warning` flips between #e6b450 and #5af78e (== success color) — non-monotonic generation plus warning/success color collision suggests competing writers and a broken palette state fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
