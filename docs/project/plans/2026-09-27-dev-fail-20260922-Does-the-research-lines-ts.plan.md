<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implement the "cadence-job-scaffold" research line by introducing a reusable shell template and a corresponding smoke test job that validates execution without touching kernel or credentials.

## Steps

- [ ] Create a reusable shell template at `scripts/cadence-scaffold.sh` that echoes a timestamp and exits 0
  Verification: bash -n scripts/cadence-scaffold.sh
- [ ] Add a smoke test job definition at `jobs/cadence-scaffold.yml` that invokes the scaffold script
  Verification: grep -q "cadence-scaffold" jobs/cadence-scaffold.yml
- [ ] Write a test runner at `tests/cadence-scaffold.test.sh` that executes the scaffold and asserts exit code 0
  Verification: bash -n tests/cadence-scaffold.test.sh
- [ ] Run the full test suite to confirm the new job integrates without breaking existing checks
  Verification: make test
- [ ] Commit the scaffold, job, and test files as a single atomic change
  Verification: git diff --stat HEAD~1 | grep -E "scripts/|jobs/|tests/"
