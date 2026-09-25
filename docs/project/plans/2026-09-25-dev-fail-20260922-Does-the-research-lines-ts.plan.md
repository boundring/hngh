<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-25 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `jobs/automation/README.md` documenting the adopted ADOPTED research line and its intended automation scope
  Verification: grep -q "ADOPTED" jobs/automation/README.md

- [ ] Create `scripts/adopted-scan.sh` that iterates over `jobs/` directories and prints each directory name as a plain commit-safe list
  Verification: bash scripts/adopted-scan.sh | grep -q "jobs"

- [ ] Add `tests/adopted-scan.test.sh` that runs `scripts/adopted-scan.sh` and asserts the output contains at least one job path
  Verification: bash tests/adopted-scan.test.sh && echo "PASS"

- [ ] Create `cadence/adopted-rhythm.md` listing a weekly cadence of small hngh-automation commits derived from the ADOPTED findings
  Verification: grep -q "weekly" cadence/adopted-rhythm.md

- [ ] Add `dashboard/adopted-status.md` with a single-line status row showing "active" and the current date
  Verification: grep -q "active" dashboard/adopted-status.md && grep -q "2026-09-25" dashboard/adopted-status.md

- [ ] Create `digest/adopted-summary.md` containing a one-paragraph summary of the ADOPTED research line and its automation goals
  Verification: grep -q "ADOPTED" digest/adopted-summary.md
