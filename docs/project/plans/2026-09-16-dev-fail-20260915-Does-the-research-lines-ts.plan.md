<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-16 - dev-fail-20260915-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

Implements the contracted line on state-to-template mapping in `research-lines.tsv` by adding an explicit, testable rendering-target column to the schema and a validation script that fails on unmapped states.

## Steps

- [ ] Add a `render_target` column to the header of `digest/research-lines.tsv` and populate it with a concrete output path for every existing state value (`planned`, `expanding`, `contracting`, `crystallized`).
  Verification: grep -q 'render_target' digest/research-lines.tsv && awk -F'\t' 'NR==1{print NF}' digest/research-lines.tsv | grep -q '^[0-9]+$'

- [ ] Create `scripts/validate-research-lines-schema.sh` that parses the TSV header, asserts the presence of a `state` and `render_target` column, and exits non-zero if any data row has an empty `render_target`.
  Verification: bash -n scripts/validate-research-lines-schema.sh

- [ ] Add `tests/test_validate_research_lines_schema.py` that invokes the validation script against a fixture TSV with a missing `render_target` value and asserts a non-zero exit code.
  Verification: python3 tests/test_validate_research_lines_schema.py

- [ ] Wire the schema validator into the existing test suite by adding an invocation of `scripts/validate-research-lines-schema.sh` to the `test` target in `Makefile`.
  Verification: make test
