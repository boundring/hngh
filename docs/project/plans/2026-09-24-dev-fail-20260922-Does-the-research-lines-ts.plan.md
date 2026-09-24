<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-24 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-hngh.sh` that checks hngh-automation directory structure and runs `make test`
  Verification: bash scripts/validate-hngh.sh

- [ ] Add a `tests/test-hngh-structure.sh` that verifies required directories exist under jobs/, scripts/, cadence/, lib/, tests/, dashboard/, digest/
  Verification: bash tests/test-hngh-structure.sh

- [ ] Add a `cadence/cadence-check.sh` that validates cadence file syntax with `bash -n`
  Verification: bash -n cadence/cadence-check.sh

- [ ] Update `Makefile` to include `validate-hngh` target that runs `bash scripts/validate-hngh.sh`
  Verification: make validate-hngh

- [ ] Add a `lib/hngh-utils.sh` helper library with `git grep` to confirm no secrets or credentials are embedded
  Verification: git grep -i 'password\|secret\|credential' lib/hngh-utils.sh

- [ ] Run full test suite to confirm all changes pass `make test`
  Verification: make test
