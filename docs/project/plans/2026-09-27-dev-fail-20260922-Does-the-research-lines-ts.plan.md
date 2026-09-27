<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-27 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a shell script that validates hngh-automation test infrastructure is parseable
  Verification: bash -n scripts/validate-infra.sh
- [ ] Create a cadence job that runs make test after each commit to jobs/ directory
  Verification: make test
- [ ] Add a grep-based check that confirms no provider credentials appear in scripts/
  Verification: grep -r 'provider\|credential' scripts/ | grep -v '^[^:]*:#' | wc -l
- [ ] Add a node --check validation for any new dashboard digest scripts
  Verification: node --check dashboard/digest-validator.js
- [ ] Create a test that verifies cadence job output is non-empty
  Verification: make test
- [ ] Add a bash script that confirms all new paths are under allowed directories
  Verification: bash scripts/path-gate.sh
