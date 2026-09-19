<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-19 - dev-fail-20260917-Do-audit-records-in-hngh-a (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the adopted cadence-observability research line by adding small, testable status helpers for hngh-automation.
All changes stay in automation paths and are gated by make test.

## Steps

- [ ] Add scripts/cadence_list_jobs.sh to list local job directories without executing jobs.
  Verification: bash -n scripts/cadence_list_jobs.sh
- [ ] Add lib/cadence_status.py as a stdlib-only helper with a self-test main that normalizes cadence status names into stable tokens.
  Verification: python3 lib/cadence_status.py
- [ ] Add dashboard/render_cadence.sh to render normalized status tokens as plain text for local review.
  Verification: bash -n dashboard/render_cadence.sh
- [ ] Add tests/cadence_status_test.sh that runs the list and status helpers against a fixture and checks expected output.
  Verification: make test
