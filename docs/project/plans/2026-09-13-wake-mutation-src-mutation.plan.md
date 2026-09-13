<!-- plan: status=executed risk=normal accepted=2026-09-13 operator-authorized=2026-09-13 supersedes-park=2026-09-09-routed-wake-mutation-lane-src-mutation -->
# 2026-09-13 — the :wake-mutation src mutation lands through the ceremony

Operator-authorized 2026-09-13 (verbatim intent recorded in
docs/records/2026-09-13-wake-mutation-lane-landing.md): the
operator authorizes landing the :wake-mutation src mutation and removing
this class of needless operator stall.

## Steps

- [x] Write the failing tests first: the closed-vocabulary check in
      tests/adapter/test-mutation.lisp expects :wake-mutation; a wake
      fixture executes the certificate-bound argv
      ("hngh" "wake-peer" <run> <pins-file> <peer>) once behind the fake
      transport; tests/domain/test-governance.lisp mints a certificate
      for every closed action including :wake-mutation.
      Verification: suite red before the src change (check failed:
      mutation action set is fixed and enumerable).
- [x] Implement the kernel mutation: :wake-mutation joins
      +mutation-actions+ (src/adapter/mutation.lisp:8-9) with a fixed
      command-for template binding the r17 wake surface; the closed
      certificate-action set (src/domain/governance.lisp
      validate-certificate-action) admits :wake-mutation; the main.lisp
      dispatch checks (issue-cert/mutation-check) read the closed list
      and admit it unchanged.
      Verification: full sbcl suite green, 2894 checks.
- [x] Policy fix: doctrine section 2 amended (2026-09-13) and the
      AGENTS.md boundary paragraph generalized — certificate-bound
      kernel mutations need no separate operator stall; park only
      actions with no certificate path.
      Verification: the amended text is in this commit.
- [x] Land via scripts/omp-bridge --ceremony (propose -> issue-cert ->
      mutation-check prepare-candidate -> commit), gate make test green
      including the doc-numbers guard (README check count updated).
      Verification: ceremony drive exits 0; commit message
      "hngh: candidate <content hash>".
- [x] Resolve the parked lane at its source: queue row wake-mutation-lane
      flips to done, the ## Next pointer advances to
      node-lattice-admission, and the research-dispositions row
      fail-20260909-wake-mutation-lane-src-mutation moves from parked to
      landed so the alert identity stops re-occurring.
