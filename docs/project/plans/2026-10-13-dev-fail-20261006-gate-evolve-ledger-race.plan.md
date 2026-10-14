<!-- plan: status=accepted risk=normal accepted=2026-10-14T00:05:44Z -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-13 - dev-fail-20261006-gate-evolve-ledger-race (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a utility script to `scripts/hngh-log-check.sh` that validates log file integrity
  Verification: bash -n scripts/hngh-log-check.sh

- [ ] Create a test case in `tests/test-hngh-log-check.sh` that asserts the script exits cleanly on valid input
  Verification: bash tests/test-hngh-log-check.sh

- [ ] Update `cadence/hngh-automation.yaml` to register the new log-check job with a standard cadence
  Verification: grep -q "log-check" cadence/hngh-automation.yaml

- [ ] Run the full test suite to confirm no regressions after adding the new script and test
  Verification: make test
