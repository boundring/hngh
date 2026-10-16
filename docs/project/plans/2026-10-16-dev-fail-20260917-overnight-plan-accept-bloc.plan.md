<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates the current branch is not main before running automation jobs
  Verification: bash -n jobs/pre-check-branch.sh

- [ ] Create a test that asserts the pre-check script exits non-zero on main branch
  Verification: make test

- [ ] Add a grep check confirming no secrets are referenced in new job scripts
  Verification: grep -r "password\|secret\|token" jobs/ --include="*.sh" | grep -v "^Binary"

- [ ] Commit the new pre-check and test as a plain commit
  Verification: git log --oneline -1
