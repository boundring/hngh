<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-18 - dev-fail-20260917-Does-the-in-toto-v1-schema (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implement the `scripts/validate-jobs.sh` helper to ensure job definitions are syntactically valid before execution.

## Steps

- [ ] Create `scripts/validate-jobs.sh` with syntax to check JSON/YAML job files.
  Verification: `bash -n scripts/validate-jobs.sh`
- [ ] Add a digest entry in `digest/jobs.md` referencing the new script.
  Verification: `grep validate-jobs.sh digest/jobs.md`
- [ ] Run `make test` to ensure no regressions.
  Verification: `make test`
