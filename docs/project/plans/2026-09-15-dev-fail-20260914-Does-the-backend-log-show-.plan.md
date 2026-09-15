<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-backend-log-show- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the instrumentation and verification gaps identified in the adopted research lines regarding crumb writer staleness, embedded CI verdict rule drift, and reaction class vocabulary constraints. It introduces machine-checkable scripts under `scripts/` to enforce closed vocabularies and detect rule divergence, ensuring that automation failures are no longer reliant on human observation or manual log inspection.

## Steps

- [ ] Create a Python script at `scripts/check_reaction_vocabulary.py` that imports the reaction module and asserts that all emitted action names belong to a predefined static set, preventing unbounded vocabulary outputs.
  Verification: python3 scripts/check_reaction_vocabulary.py

- [ ] Add a shell script at `scripts/verify_crumb_freshness.sh` that checks the modification time of the latest crumb file against a threshold and exits non-zero if stale, providing an automatic failure signal for cadence enforcement.
  Verification: bash -n scripts/verify_crumb_freshness.sh

- [ ] Implement a diffing utility at `scripts/diff_verdict_rules.sh` that compares the embedded CI verdict rule snippet against the canonical kernel rules file path and fails if they diverge, addressing the drift finding.
  Verification: bash -n scripts/diff_verdict_rules.sh

- [ ] Update the GitHub Actions workflow definition in `.github/workflows/ci.yml` to invoke `scripts/diff_verdict_rules.sh` as a pre-commit check, ensuring that any future drift between CI and kernel rules is caught automatically.
  Verification: grep -q "diff_verdict_rules" .github/workflows/ci.yml

- [ ] Add a unit test at `tests/test_reaction_split.py` that verifies the reaction class correctly separates internal state transitions from external observable effects, ensuring the closed vocabulary constraint is structurally enforced.
  Verification: python3 tests/test_reaction_split.py
