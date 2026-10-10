<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script under `scripts/` that parses a JSON digest file and writes a plain-text summary to `digest/last-run.txt`
  Verification: bash scripts/parse-digest.sh && cat digest/last-run.txt
- [ ] Add a shell script under `scripts/` that validates the JSON structure of a digest file using only stdlib tools
  Verification: bash scripts/validate-digest.sh
- [ ] Add a test file under `tests/` that runs both scripts against a sample digest fixture and asserts non-zero exit on malformed input
  Verification: make test
- [ ] Add a cadence entry under `cadence/` that schedules the digest parser and validator to run after every successful `make test`
  Verification: grep -q "parse-digest" cadence/*.sh
- [ ] Add a dashboard snippet under `dashboard/` that displays the last 5 lines of `digest/last-run.txt`
  Verification: bash dashboard/show-last-digest.sh
- [ ] Add a commit message template under `jobs/` that enforces a prefix for automation-related commits
  Verification: bash -n jobs/commit-msg-hook.sh
