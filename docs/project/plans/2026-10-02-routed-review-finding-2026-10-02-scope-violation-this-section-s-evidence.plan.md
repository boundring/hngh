<!-- plan: status=accepted risk=normal accepted=2026-10-02T14:05:48Z routed-from=review-finding:2026-10-02:scope-violation-this-section-s-evidence -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-09T12:00:41Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-02 — routed candidate

Routed by scripts/router-tick.py from alert identity `review-finding:2026-10-02:scope-violation-this-section-s-evidence`
at 2026-10-02T12:00:41Z. Alert text: scope violation — this section's evidence is byte-identical to the hngh section (same commit hashes d28e0ab1, 3df2199b, e87bf230, 890b5923, 3a09921f; kernel `docs/`, plans, research TSVs); either kernel docs work is being committed into hngh-automation, or the review packet duplicated the section — resolve which before treating any of it as automation-repo history fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
