<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-28 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a new job template for automated digest generation
  Verification: bash -n jobs/digest-template.sh

- [ ] Create a test script validating the new job template syntax
  Verification: make test

- [ ] Add a verification script to confirm template integration
  Verification: bash scripts/verify-digest-template.sh

- [ ] Update cadence configuration to include the new template
  Verification: grep -q 'digest-template' cadence/config.yaml

- [ ] Run full test suite to confirm no regressions
  Verification: make test

---

**Rationale:** Implements the research line `hngh-job-template-automation` by introducing a new digest generation template with syntax validation and integration verification, all gated by `make test` for normal-risk delivery.
