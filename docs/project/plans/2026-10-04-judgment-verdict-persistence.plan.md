<!-- plan: status=accepted risk=normal accepted=2026-10-04T04:06:35Z -->
principle: evidence-before-claim — verdicts that steer later kernels must be durable rows, not ceremony-time memories (docs/design/triple-kernel.md §2 verdict-row)
# S1: judgment kernel persists verdict rows at run close

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

## Steps

- [ ] Add a verdict-row serializer to the run-close path
      (src/application close-run flow): one row per component verdict,
      keys exactly {run-id, component, verdict, evidence-refs,
      computed-at, ten-principle-exceptions}, appended beside the run's
      existing outcome records (no new store).
      Verification: repo-root make test passes including the extended
      close-run unit test.
- [ ] Extend the close-run unit test to assert a closed run yields a
      verdict-row file that round-trips through the reader with all six
      keys present and evidence-refs non-empty for every non-open
      verdict.
      Verification: grep -c "verdict-row" src/tests output >= 1 and the
      kernel suite is green.
- [ ] Document the landing in docs/design/triple-kernel.md section 3
      (S1 marked landed with the run-close row path).
      Verification: grep -q "S1 .*landed" docs/design/triple-kernel.md

Note: risk=critical by policy — this plan mutates kernel src/ and is
reserved for the operator's deliberate ceremony, not the autonomous
cycle.
