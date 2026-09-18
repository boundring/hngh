<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-15 - dev-fail-20260914-Does-the-github-ci-workflo (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Create `scripts/check-verdict-rule-drift.sh` that greps for the canonical patrol verdict rule string in both the CI workflow definition and the kernel rules file, failing if they differ.
  Verification: bash -n scripts/check-verdict-rule-drift.sh
- [ ] Add a test case to `tests/` that executes the drift check script against fixture files representing drifted and identical rule surfaces.
  Verification: make test
- [ ] Create `lib/reaction-vocabulary.py` defining a closed set of external reaction outputs and a validation function that rejects unbounded or dynamically named payloads.
  Verification: python3 -c "import lib.reaction_vocabulary as rv; assert rv.validate('known_output') == True"
- [ ] Add a unit test in `tests/` verifying that the reaction vocabulary validator accepts only closed-vocabulary outputs and raises on arbitrary strings.
  Verification: make test
- [ ] Create `dashboard/sessions-scroll-probe.js` that inspects the DOM for shared layout components across dashboard tabs and logs scroll container heights.
  Verification: node --check dashboard/sessions-scroll-probe.js
