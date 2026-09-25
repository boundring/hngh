<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a script that validates the cadence directory structure exists and is readable
  Verification: bash scripts/cadence-validate.sh

- [ ] Add a test that confirms the lib module loads without errors
  Verification: python3 -c "import sys; sys.path.insert(0, 'lib'); import lib; print('lib loaded')"

- [ ] Add a job that runs the cadence-validate script and reports pass/fail
  Verification: make test

- [ ] Add a dashboard snippet that displays cadence directory contents
  Verification: bash -n dashboard/cadence-display.sh

- [ ] Add a digest helper that logs the last successful test run timestamp
  Verification: python3 -c "import datetime; print(datetime.datetime.now().isoformat())"

- [ ] Add a test that verifies all new scripts pass bash syntax check
  Verification: bash -n scripts/cadence-validate.sh && bash -n dashboard/cadence-display.sh
