<!-- plan: status=accepted risk=normal accepted=2026-10-04T04:06:35Z -->
principle: no-hidden-execution — every mutation's legitimacy enters through one auditable door (docs/design/triple-kernel.md §2 admit entry point)
# S2: legislation kernel formalizes admit(instrument, state) as the only legitimacy path

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

## Steps

- [ ] Define admit(instrument, state) in src/application (the
      admit-transport generalization): instrument is exactly one of
      certificate | accepted-plan | scoped-request; the return is an
      admission decision row naming the granted action, target, and
      expiry.
      Verification: repo-root make test passes with the new
      admit unit tests (one per instrument kind, plus a fail-closed
      unknown-instrument case).
- [ ] Route the existing legitimacy checks through admit:
      scripts/verify-candidate.py verdicts and plan front-matter
      checks consume admission rows instead of re-implementing their
      own verdict logic; behavior stays byte-compatible during the
      cutover.
      Verification: automation/tests/test-plan-acceptance.py and
      bash tests/test-accept-plans-principle.sh stay green.
- [ ] Plan archival: executed plans move to
      docs/project/plans/archive/ with a cert-ref front-matter field
      naming their certificate; ~200 live plan files stop growing
      unbounded.
      Verification: grep -q "cert-ref" docs/project/plans/README.md and
      an archived example plan exists with a cert-ref line.
- [ ] Document the landing in docs/design/triple-kernel.md section 3
      (S2 marked landed with the admit signature).
      Verification: grep -q "S2 .*landed" docs/design/triple-kernel.md

Note: risk=critical by policy — this plan mutates kernel src/ and the
legitimacy chokepoint; reserved for the operator's deliberate ceremony.
