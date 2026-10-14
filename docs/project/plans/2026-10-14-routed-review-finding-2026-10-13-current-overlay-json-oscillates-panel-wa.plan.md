<!-- plan: status=accepted risk=normal accepted=2026-10-14T04:35:29Z routed-from=review-finding:2026-10-13:current-overlay-json-oscillates-panel-wa -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-21T03:00:14Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-14 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-13:current-overlay-json-oscillates-panel-wa`
at 2026-10-14T03:00:14Z. Alert text: current-overlay.json oscillates panel/warning between commits — 093a230 wrote warning=#14181e (≈ background #0b0e11, an effectively invisible warning color) and panel=#e6b450; 958a2ee flips them back; the generator is producing and committing unreadable states fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
