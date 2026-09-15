<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260912-overnight-plan-accept-gate (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the contracted research lines on gate-closure artifacts, slow-unit instrumentation, dashboard link integrity, and mark-read persistence verification by adding bounded, verifiable checks to hngh-automation.

## Steps

- [ ] Add a script under scripts/ that parses the last kernel make test log for rc=2 and extracts the failing target name into digest/gate-artifact.txt
  Verification: bash -n scripts/capture-gate-artifact.sh && grep -q "rc=2" scripts/capture-gate-artifact.sh
- [ ] Create a helper under lib/ that detects bimodal latency clusters in slow-unit rows and writes a summary to digest/slow-unit-summary.md
  Verification: python3 lib/detect-bimodal-latency.py --help && grep -q "median" lib/detect-bimodal-latency.py
- [ ] Update the dashboard Plans page generator under dashboard/ to validate that each enumerated plan link resolves to an existing file before rendering
  Verification: bash -n dashboard/generate-plans.sh && grep -q "404\|exists" dashboard/generate-plans.sh
- [ ] Add a test under tests/ that asserts mark-read requests only return 200 after persistence completes, using a mock backend log fixture
  Verification: make test && grep -q "mark-read" tests/test-mark-read-persistence.sh
- [ ] Extend the patrol gate check under jobs/ to require a fresh gate crumb timestamp before accepting routed plans, logging missing crumbs to digest/patrol-gate-missing.log
  Verification: bash -n jobs/check-gate-crumbs.sh && grep -q "crumb" jobs/check-gate-crumbs.sh
