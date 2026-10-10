<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-10 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job in `jobs/` that runs the existing automation pipeline with a synthetic low-volume input to confirm baseline stability
  Verification: `make test`

- [ ] Create a helper script in `scripts/` that generates a fixed-size placeholder dataset for controlled testing of downstream digest steps
  Verification: `bash -n <file>`

- [ ] Update the cadence configuration in `cadence/` to include the new synthetic job alongside existing ones without modifying scheduling logic
  Verification: `grep <new-job-name> <file>`

- [ ] Add a test case in `tests/` that asserts the synthetic dataset is correctly ingested and produces an expected non-empty digest output
  Verification: `bash <script>`
