<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

This plan implements the "deterministic cadence parsing" research line by introducing a shared log-extraction utility and integrating it into the digest pipeline to ensure consistent job status reporting.

## Steps

- [ ] Create `scripts/parse_cadence.sh` to extract status lines from job logs
  Verification: `bash -n scripts/parse_cadence.sh`
- [ ] Create `lib/cadence_parser.py` wrapping the extraction logic for Python consumers
  Verification: `python3 -c "import ast; ast.parse(open('lib/cadence_parser.py').read())"`
- [ ] Add `tests/test_cadence_parser.py` to verify extraction against sample log fixtures
  Verification: `python3 tests/test_cadence_parser.py`
- [ ] Update `digest/summary.py` to invoke the new parser for status aggregation
  Verification: `git grep -l "parse_cadence" digest/summary.py`
- [ ] Run the full test suite to confirm no regressions
  Verification: `make test`
