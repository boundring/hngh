<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-26 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a cadence job that runs a daily digest summary of hngh-automation activity
  Verification: bash -n cadence/daily-digest.sh

- [ ] Create a verification script that confirms the digest job output is non-empty
  Verification: python3 scripts/verify_digest_nonempty.py

- [ ] Add a test that validates the cadence job runs without errors
  Verification: make test

- [ ] Commit the new cadence and verification files as a plain commit
  Verification: git diff --stat HEAD~1
