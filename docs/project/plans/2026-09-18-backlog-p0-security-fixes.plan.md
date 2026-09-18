<!-- plan: status=accepted risk=normal accepted=2026-09-18T01:41:57Z -->
# 2026-09-18 — backlog TIER 1: P0 security/correctness bundle

Author: stage-p0-security-bundle session (coordinator task), from
`~/.jcode/scratch/BACKLOG.md` TIER 1 only. All steps touch
`automation/` or `docs/` exclusively — free-commit lane, no kernel
`src/`, `tests/`, `Makefile`, or `hngh.asd`, no ceremony, no
provider/credential configuration changes. Cites the plans/README
verification contract and autonomy reference instead of repeating them.

## Steps

- [x] Fix the email-digest intake overwide-alert drop: widen or remove the `len==5` cell-count guard in `automation/scripts/email-digest.py` (patrol alerts wider than 5 fields at the intake site, backlog item rq-gap-email-digest-intake) so overwide patrol alerts parse instead of being silently dropped.
      Verification: see plans/README verification contract; automation `make test` green plus `automation/tests/test-email-digest.py` (or the digest intake test file covering the alert-parse path) passing with a new overwide-row fixture case.
- [x] Fix the dead overnight-cycle awk disposition pattern: repair the leading-space timestamp regex at `automation/scripts/overnight-cycle.sh:339-342` (backlog item rq-gap-overnight-awk-disposition) so ts cells with leading spaces match, and add a regression test for the fixed pattern.
      Verification: see plans/README verification contract; automation `make test` green plus a new named test asserting the awk regex matches both flush and leading-space ts cells.
- [x] Guard the synthesize_dev_plan mint site: add an accept-plans-style redact+scrub seam around the unguarded slug-mint path in the `synthesize_dev_plan` flow (backlog item gap-slug-synth-mint-uncured) so credential-bearing input cannot pass through into a minted plan slug or body.
      Verification: see plans/README verification contract; automation `make test` green plus a new test that a credential-shaped string fed through the seam is redacted before mint.
- [x] Cure the residual slug-mint sites: apply the same redact/scrub treatment to the remaining mint surfaces from backlog item gap-slug-residual-mints — `automation/jobs/patrol.py` `queue_repeat_subjects` (exposure NIL, low priority), and the alert-identity slug constructions in `automation/cadence/day/06-review-disposition.sh:46-56` and `automation/cadence/day/19-ux-review.sh:39-42` (slug fields, not filenames).
      Verification: see plans/README verification contract; automation `make test` green plus per-site checks that minted slugs contain no raw credential-bearing substrings.
- [x] Backfill 1Password item metadata completeness: for 1Password-referenced items cited by automation records, complete missing metadata fields (title/URL/last-updated provenance) per backlog item rot-gap-1password-item-metadata, recorded in the automation docs surface.
      Verification: see plans/README verification contract; automation `make test` green plus a record cite (docs/ record noting the completed metadata for each item).
- [x] Pin the 5 unpinned cadence committers: add `-c user.name="hngh-machine" -c user.email="automation@hngh.local"` identity pins to the 5 cadence writer sites listed in `docs/records/2026-09-16-identity-seam-reconciliation.md` — `automation/cadence/day/01-lesson-harvest.sh:86`, `automation/cadence/day/14-plan-ledger-sync.sh:39`, `automation/cadence/day/17-torch-audit.sh:202`, `automation/cadence/hour/30-kernel-ledger-sync.sh:45`, `automation/cadence/hour/33-research-beat.sh:183` — matching the contract already pinned by `automation/tests/test-identity-seam.py`.
      Verification: see plans/README verification contract; automation `make test` green plus `automation/tests/test-identity-seam.py` extended (or re-run green) asserting each of the 5 sites carries the `-c` identity pin.
- [x] Produce the tracked-remediation-plan doc: write the remediation-plan document for the tracked dash-form slug leak population (3 id families, 6 surfaces, backlog item gap-slug-tracked-remediation-plan) into `docs/records/`.
      Verification: see plans/README verification contract; docs change verified by record presence — `docs/records/2026-09-18-tracked-remediation-plan.md` exists, cites the 3 id families and 6 surfaces, and repo-root `make test` stays green.
- [x] Add identity-record hygiene caveats: append the hygiene caveats (attribution-only exposure, forgeable authorship, nil security value where applicable) to `docs/records/2026-09-16-identity-seam-reconciliation.md` per backlog item identity-record-hygiene-caveats.
      Verification: see plans/README verification contract; docs change verified by record cite — the caveats section is present in the record and repo-root `make test` stays green.
