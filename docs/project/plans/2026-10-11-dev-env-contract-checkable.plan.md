<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-10-11 - dev-env-contract-checkable (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `cadence/` script that emits a single-line status digest for the current `jobs/` tree and commit it to `digest/`
  Verification: bash cadence/digest.sh && git diff --quiet HEAD~1 digest/

- [ ] Add a `scripts/` helper that validates the new digest format with `bash -n` and a grep for the expected status token
  Verification: bash -n scripts/validate-digest.sh && grep -q "STATUS_OK" scripts/validate-digest.sh

- [ ] Add a `tests/` unit that runs `cadence/digest.sh` against a synthetic `jobs/` tree and asserts the output matches the regex
  Verification: bash tests/run-digest-test.sh && echo "PASS"

- [ ] Wire the new digest step into the existing `make test` target so it runs as part of the normal CI gate
  Verification: make test && echo "ALL GREEN"

- [ ] Add a `dashboard/` snippet that reads the latest `digest/` file and renders a one-line summary for the web view
  Verification: bash dashboard/render-digest.sh && grep -q "hngh-automation" dashboard/render-digest.sh

- [ ] Commit the full set as a single plain commit and confirm `git log --oneline -1` shows the new digest integration
  Verification: git log --oneline -1 && git diff --stat HEAD~1 | wc -l
