<!-- plan: status=accepted risk=normal accepted=2026-10-15T11:06:40Z routed-from=review-finding:2026-10-15:omarchy-config-adopt-sh-s-runtime-refere -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-22T11:00:12Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-15 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-15:omarchy-config-adopt-sh-s-runtime-refere`
at 2026-10-15T11:00:12Z. Alert text: omarchy-config-adopt.sh's runtime/reference disagreement check runs after the newline case on `$UPSTREAM` but the die3 message only tells the user to unset the alias; if both are set equal it passes silently — consider warning on any OMARCHY_UPSTREAM_DIR use so the deprecated alias actually deprecates. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
