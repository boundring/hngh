<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-20 - dev-fail-20260918-Does-the-path-collision-bu (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the adopted cadence observability research line by adding small, locally testable hngh-automation artifacts for status normalization, summary rendering, and digest documentation.

## Steps

- [ ] Add a stdlib-only Python helper at lib/hngh_automation/cadence_status.py that normalizes cadence state names and exits 0 when run directly.
  Verification: python3 lib/hngh_automation/cadence_status.py
- [ ] Add scripts/render_cadence_summary.sh that prints a plain-text cadence summary and exits 0 without touching deployment configuration.
  Verification: bash scripts/render_cadence_summary.sh
- [ ] Add dashboard/cadence_summary.js exporting a pure function that formats cadence records as text for local review.
  Verification: node --check dashboard/cadence_summary.js
- [ ] Add tests/cadence_status_test.py using unittest to assert the helper's normalization behavior for normal cadence states.
  Verification: make test
- [ ] Add digest/cadence_observability.md documenting the new status fields and the verification commands used by this plan.
  Verification: grep -q "cadence" digest/cadence_observability.md
