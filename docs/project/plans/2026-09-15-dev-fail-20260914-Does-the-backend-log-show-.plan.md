<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-15 - dev-fail-20260914-Does-the-backend-log-show- (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Rationale
This plan implements the instrumentation and verification gaps identified in the adopted research lines regarding `mark-read` persistence ambiguity, crumb writer staleness detection, and CI verdict rule drift by adding machine-checkable scripts to hngh-automation.

## Steps

- [ ] Create a script that parses backend logs to correlate `200 OK` responses with database commit events for `mark-read` requests
  Verification: bash -n scripts/verify-mark-read-persistence.sh
- [ ] Add a cadence check script that validates the crumb writer's last-run timestamp against a staleness threshold
  Verification: python3 cadence/check_crumb_staleness.py
- [ ] Implement a CI verification step that diffs the embedded patrol verdict rule in workflows against the kernel's canonical rules file
  Verification: grep -q "diff.*verdict" .github/workflows/ci.yml
- [ ] Define a closed vocabulary registry for reaction outputs to satisfy R1 constraints without splitting classes
  Verification: python3 -c "import json; json.load(open('lib/reaction_vocabulary.json'))"
