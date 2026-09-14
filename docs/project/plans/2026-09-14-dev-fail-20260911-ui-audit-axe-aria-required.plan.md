<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-14 - dev-fail-20260911-ui-audit-axe-aria-required (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

The plan implements the fail-20260911-ui-audit-axe-aria-required-children research line by adding a diagnostic extraction step to the ui-audit pipeline that captures axe-core JSON output and diffs static HTML against live DOM to identify the disallowed child node on #tabs.

## Steps

- [ ] Create `scripts/ui-audit-extract.sh` that runs the existing axe scan and writes raw JSON output to `digest/axe-output.json`
  Verification: bash -n scripts/ui-audit-extract.sh
- [ ] Add a diff function to `scripts/ui-audit-extract.sh` that compares static HTML tab children against live DOM nodes in the JSON, flagging any node lacking role="tab"
  Verification: grep -q "role=\"tab\"" scripts/ui-audit-extract.sh
- [ ] Update the ui-audit job definition in `jobs/ui-audit.yml` to invoke `scripts/ui-audit-extract.sh` after the scan and log the offending node path to stdout
  Verification: grep -q "ui-audit-extract" jobs/ui-audit.yml
- [ ] Add a test fixture `tests/fixtures/axe-tablist.json` containing a minimal axe-core result with one invalid child under role="tablist" for regression testing
  Verification: python3 -c "import json; json.load(open('tests/fixtures/axe-tablist.json'))"
- [ ] Run the full test suite to confirm no regressions in existing ui-audit behavior
  Verification: make test
