<!-- plan: status=proposed risk=normal accepted=- -->
principle: adopted evidence before new surface (docs/project/decisions.md entry template)
# 2026-09-29 - dev-fail-20260922-Does-the-research-lines-ts (synthesized from adopted research)

Synthesized by the overnight cycle from verdict=adopted research
dispositions (local chain, pinned); admission via accept-plans.

## Steps

- [ ] Add a `scripts/validate-hngh.sh` helper that checks repository structure integrity
  Verification: bash scripts/validate-hngh.sh && echo "PASS"

- [ ] Add a `tests/test-hngh-structure.sh` that verifies required directories exist
  Verification: bash tests/test-hngh-structure.sh && echo "PASS"

- [ ] Add a `cadence/cadence-check.sh` script that validates cadence file syntax
  Verification: bash cadence/cadence-check.sh && echo "PASS"

- [ ] Add a `lib/hngh-utils.sh` library with common utility functions
  Verification: bash -n lib/hngh-utils.sh && echo "PASS"

- [ ] Add a `dashboard/dashboard-init.sh` that initializes dashboard state
  Verification: bash dashboard/dashboard-init.sh && echo "PASS"

- [ ] Add a `digest/digest-format.sh` script that formats digest output
  Verification: bash digest/digest-format.sh && echo "PASS"

Steps must be small, concrete, and land as plain commits in hngh-automation (gated by its make test). Normal-risk ONLY. FORBIDDEN, critical class, never include: provider or credential configuration, systemd unit lifecycle, hngh kernel src/tests/Makefile/hngh.asd changes, non-prune deletions, secrets or security posture.
