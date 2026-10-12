<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-12 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `lib/verify.sh` helper that runs `make test` and returns exit code
  Verification: bash -n lib/verify.sh

- [ ] Create `scripts/cadence-check.sh` that validates cadence schedule files exist under `cadence/`
  Verification: bash scripts/cadence-check.sh

- [ ] Add a `tests/test-verify.sh` that asserts `lib/verify.sh` exits 0 after `make test`
  Verification: bash tests/test-verify.sh

- [ ] Update `jobs/README.md` to document the new verification helpers
  Verification: grep -q "verify.sh" jobs/README.md
