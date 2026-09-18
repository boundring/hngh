# 2026-09-18 — G4 fixture-identity fanout census (narrowed, read-only)

Bead: hngh-4j4 acceptance item G4. Node: g4-fixture-fanout.
Scope: commits authored by Fixture touching kernel paths
(`src/`, `tests/`, repo-root `scripts/`, `Makefile`, `hngh.asd`),
outside guard exemptions `ba6b3905` and `d2d8f51`. No mutations
performed during the census; this file is the only write.

## Invocation

```
git log --all --format='%H %an %s' --author='Fixture' -- src/ tests/ scripts/ Makefile hngh.asd
```

## Verdict: sanctioned

20 Fixture-authored commits touch kernel paths. Excluding the two
named guard exemptions leaves 18 commits, every one covered:

- `ba6b3905` — fixture pair head: Makefile+README gut (guard-table
  declared miss; tests/scripts/test-loop-history-guard.py:177).
- `d2d8f51` — fixture pair revert 47s later, tree-net-zero
  (guard-table declared miss; test-loop-history-guard.py:181).

## The 18 outside the pair

12 carry the `hngh: candidate <64hex>` ceremony label
(CANDIDATE regex at test-loop-history-guard.py:246):

cf36b6f2, fc2ab203, 59c63bf0, 117d463f, 30966c38, 92ecf674,
307e9581, ff07c157, 9faf25a3, fd4ccbda, 2ad2dfa9 (touches
src/adapter/mutation.lisp, src/domain/governance.lisp plus tests),
2bd1e505.

6 carry non-candidate messages but each holds a named guard-table
exemption:

- a5520fb2 — mixed-lane cure commit (kernel declaration +
  automation test tracking).
- 7637c560 — ledger repair; swept tests/ content certified
  separately by candidate 117d463f.
- e6e98f7 — queue Next advance sweeping a staged packages.lisp
  export edit (inert exports); test-loop-history-guard.py:81.
- c3bf9861 — fleet-manager capitalized Peer-map acceptance,
  scripts/ CI-green chase; test-loop-history-guard.py:217.
- 29d2a27c — omp-bridge --ceremony ephemeral-store fix,
  scripts/; test-loop-history-guard.py:208.
- 04f00013 — report-queue evidence-gated dedup, scripts/;
  test-loop-history-guard.py:203.

## Guard state

`python3 tests/scripts/test-loop-history-guard.py` →
143 code-surface commits checked, 27 named exemptions, 0 violations.

## Evidence pointers

- Code surface + candidate-or-exemption rule:
  tests/scripts/test-loop-history-guard.py:13
- CANDIDATE regex: test-loop-history-guard.py:246
- CODE_SURFACE tuple: test-loop-history-guard.py (~line 244)
- Exemption entries: ba6b390 (~177), d2d8f51 (~181), e6e98f7
  (~81), a5520fb2 (~89), 7637c560 (~68), 04f0001 (~203),
  29d2a27 (~208), c3bf986 (~217)

## Pathspec note

The bead says repo-root `scripts/`; the guard CODE_SURFACE says
`scripts/`. Treated as identical (the repo-root scripts/ dir).
4 Fixture commits touch scripts/ and all are covered above.

## Not checked

- Whether each of the 12 candidate hashes maps to a real issued
  certificate (label syntax only).
- Fixture commits touching automation/ or docs/ outside kernel paths.
- Pre-guard or purged-history Fixture commits unreachable from HEAD.
