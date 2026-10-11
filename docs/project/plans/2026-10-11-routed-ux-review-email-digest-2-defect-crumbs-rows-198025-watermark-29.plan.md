<!-- plan: status=accepted risk=normal accepted=2026-10-11T11:06:52Z routed-from=ux-review:email-digest:2-defect-crumbs-rows-198025-watermark-29 -->
<!-- attempt: 1 -->
<!-- expires: 2026-10-18T11:00:42Z -->
principle: routed candidates keep alert lineage machine-visible (docs/project/plans/README.md)
# 2026-10-11 — routed candidate

Routed by scripts/router-tick.py from alert identity `ux-review:email-digest:2-defect-crumbs-rows-198025-watermark-29`
at 2026-10-11T11:00:42Z. Alert text: 2. defect: "crumbs rows=198025 watermark=29625291 skipped_tota…" is cut off mid-word ("skipped_tota…") — the mismatch is reported but its consequence (data loss? sync failure?) is unnamed. fix: append the downstream effect or the remediation step. file: `crumbs mirror mismatch` alert row. fix or park with cause

## Steps

- [ ] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
