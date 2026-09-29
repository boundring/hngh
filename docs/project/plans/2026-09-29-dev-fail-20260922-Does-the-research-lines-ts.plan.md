<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new cadence job template for incremental digest generation
  Verification: bash -n cadence/incremental-digest.sh

- [ ] Add a test script that validates the new cadence job template syntax
  Verification: python3 tests/test_cadence_template.py

- [ ] Add a lib helper function for safe path resolution used by the new job
  Verification: bash -n lib/path_resolver.sh

- [ ] Add a dashboard snippet that displays cadence job status
  Verification: bash -n dashboard/cadence_status.sh

- [ ] Add a make test entry that exercises the new cadence job end-to-end
  Verification: make test

- [ ] Add a grep check confirming no secrets or credentials in new files
  Verification: grep -r 'password\|secret\|token' jobs/ cadence/ lib/ tests/ dashboard/ digest/ | grep -v 'none'
