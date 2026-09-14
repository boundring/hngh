<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260913-Are-there-any-existing-int (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the research line on cadence beat latency and guardrails by adding a synchronous, bounded integration test that exercises the lib/automation.py to bin/hngh boundary with explicit timeout and token limits. This converts the overnight harness into a preventive gate and closes the open verification items regarding wall_s scope and missing guards.

## Steps

- [ ] Add a new integration test script `tests/integration/test_boundary_guardrails.sh` that invokes `bin/hngh` via `lib/automation.py` with a strict 10-second timeout wrapper.
  Verification: bash -n tests/integration/test_boundary_guardrails.sh

- [ ] Modify `cadence/hour/33-research-beat.sh` to explicitly wrap the model invocation in a `timeout` command and pass `--max-tokens` to cap output size, ensuring `wall_s` only measures the bounded leg.
  Verification: grep -q "timeout" cadence/hour/33-research-beat.sh && grep -q -- "--max-tokens" cadence/hour/33-research-beat.sh

- [ ] Create a helper function in `lib/automation.py` that validates the CLI contract returned by `bin/hngh`, raising an error if the exit code or stdout format deviates from the post-2026-08-25 corrected specification.
  Verification: python3 -c "import lib.automation; assert hasattr(lib.automation, 'validate_cli_contract')"

- [ ] Update the `Makefile` in `hngh-automation` to include a target `test-integration` that runs the new boundary test script and fails if the timeout or contract validation errors occur.
  Verification: make -n test-integration

- [ ] Execute the new integration test locally to confirm it passes under normal conditions and correctly fails when the timeout is artificially reduced to 1 second.
  Verification: make test
