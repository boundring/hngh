# Second self-governed commit record

## Scope

Records the second commit produced, certified, and executed by Hngh's own
governance loop — this time a pair of genuine code fixes found by the first
governance loop, committed under a new certificate from the real evidence chain and
pushed to origin.

## Decision

The first self-governed run (2026-08-24, see `docs/records/
2026-08-24-first-self-governed-commit.md`) surfaced two real adapter bugs
during its own execution:

1. `src/adapter/run-gather.lisp` — `process-run-at` consumed UIOP's return
   values in the wrong order. `uiop:run-program` with `:output :string
   :error-output :string` returns `(values stdout stderr exit-code)`, but the
   adapter contract and every caller expect `(values exit-code stdout
   stderr)`. The real-subprocess evidence path therefore always failed
   (fake-port tests never exercised it, so the suite stayed green).
2. `src/main.lisp` — `real-certificate` bound candidate paths in argv order,
   while the mutation executor rechecks against the sorted manifest from
   `verify-candidate.py`, yielding `candidate-paths-mismatch` refusals.

Both fixes were applied to the working tree and then committed through the
governance loop rather than by hand: a `prepare-candidate` certificate bound
the exact diff (content hash `1befdda9...`103833`, base revision `2a16a69`),
the mutation executor staged exactly those two paths, the full gate passed (8
reader guards + 1334 checks), and a `commit` certificate executed
commit `33b8d94` with message `hngh: candidate 1befdda9...`. The commit was
pushed to `origin/main` (`aa9cb64..33b8d94`).

## Evidence

- `docs/project/roadmap.md` — rung 9 completed bullet updated to name both
  self-governed commits.
- `CHANGELOG.md` — 2026-08-24 entry: second self-governed commit (code
  fixes).
- `git log`: `33b8d94` (candidate `1befdda9...`) self-governed code fixes;
  `2a16a69` (candidate `4415287c...`) first self-governed docs commit;
  `aa9cb64` public-launch merge.

## Remaining unknowns

Push was performed directly by the executor transport as in run 1; an
operator-facing push-policy tightening of the closed `:push` action vocabulary
remains future work. The two real bugs prove the loop's value: the governance
loop is now a genuine integration test of the evidence chain.