<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence runner script that iterates over jobs/ and executes each with make test, logging pass/fail per job
  Verification: bash scripts/run-cadence.sh && grep -c "PASS\|FAIL" scripts/run-cadence.log

- [ ] Create a lib/cadence.py helper that exposes a single function to parse job metadata from cadence/manifest.yaml and return a sorted job list
  Verification: python3 -c "from lib.cadence import load_jobs; print(len(load_jobs()))"

- [ ] Update cadence/manifest.yaml to include a new 'nightly' job entry with a simple echo payload and make test target
  Verification: grep -q "nightly" cadence/manifest.yaml && make test

- [ ] Add a dashboard digest script that aggregates job results from the last run and writes a summary to dashboard/digest.txt
  Verification: bash scripts/run-cadence.sh && cat dashboard/digest.txt

- [ ] Add a test for the cadence runner that asserts each job in manifest.yaml is executed exactly once per run
  Verification: bash tests/test-cadence.sh && grep -q "OK" tests/test-cadence.log

- [ ] Update the README to document the new cadence workflow and required paths under jobs/, scripts/, cadence/, dashboard/
  Verification: grep -q "cadence" README.md
