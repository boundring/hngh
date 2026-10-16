<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-16 - dev-fail-20260917-overnight-plan-accept-bloc (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/routine-check.sh` script that logs the current timestamp and verifies the hngh agent is responsive via ping
  Verification: bash cadence/routine-check.sh && echo "Agent logged heartbeat"
- [ ] Create a `scripts/daily-digest.py` using only stdlib to fetch today's top HN items from the local cached list
  Verification: python3 scripts/daily-digest.py --help && echo "Digest module loads cleanly"
- [ ] Update `.gitignore` to exclude any non-standard artifacts and confirm repo hygiene with a clean build
  Verification: git status --porcelain | wc -l == 0 && make test
- [ ] Add `tests/test_digest_pipeline.sh` that runs the daily-digest script and asserts exit code zero
  Verification: bash tests/test_digest_pipeline.sh
