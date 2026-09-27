<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/` helper script that validates a job manifest schema before execution
  Verification: bash -n cadence/validate-manifest.sh

- [ ] Create a `tests/` unit test for the manifest validator that asserts valid JSON passes
  Verification: make test

- [ ] Add a `jobs/` entry that invokes the validator on a sample manifest before running
  Verification: bash -n jobs/sample-validate.sh

- [ ] Extend `lib/` with a shared `parse-manifest` function used by both validator and job runner
  Verification: bash -n lib/parse-manifest.sh

- [ ] Add a `dashboard/` summary line in the test output when validation passes
  Verification: make test
