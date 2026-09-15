<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260912-overnight-plan-accept-gate (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the crystallized research lines on gate-stale patrol alerts, kernel test artifact capture, and dashboard link integrity by adding bounded instrumentation and verification scripts to hngh-automation.

## Steps

- [ ] Create `scripts/verify-gate-crumb.sh` that checks for a recent gate crumb file in `digest/` and exits non-zero if missing or stale
  Verification: bash -n scripts/verify-gate-crumb.sh
- [ ] Add `tests/test-gate-crumb.sh` that runs the verification script against a mock crumb file to prove pass/fail behavior
  Verification: make test
- [ ] Create `scripts/capture-make-test-artifact.sh` that wraps `make test` and saves stderr plus failing target name to `digest/` on rc!=0
  Verification: bash -n scripts/capture-make-test-artifact.sh
- [ ] Add `tests/test-capture-artifact.sh` that simulates a failing make run and asserts the artifact file contains the target name and stderr
  Verification: make test
- [ ] Create `dashboard/verify-plan-links.py` (stdlib only) that parses `research-lines.tsv` and checks each plan link resolves to an existing file in `digest/`
  Verification: python3 dashboard/verify-plan-links.py
