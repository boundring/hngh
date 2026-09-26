<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence script that validates the current test suite baseline before any new job is queued
  Verification: bash scripts/cadence/baseline-check.sh

- [ ] Create a lib helper that normalizes job output into a fixed schema for downstream digest consumption
  Verification: bash -n lib/hngh-automation/job-normalizer.py && python3 lib/hngh-automation/job-normalizer.py --dry-run

- [ ] Extend tests/ with a regression guard that asserts no new job output exceeds the baseline variance threshold
  Verification: make test

- [ ] Add a dashboard snippet that renders a single-line status of the last 3 job runs for quick admission review
  Verification: bash -n dashboard/status-render.sh && bash dashboard/status-render.sh --sample 3

- [ ] Wire a small cadence hook that runs the baseline check before any new job script is committed
  Verification: bash scripts/cadence/baseline-check.sh && make test
