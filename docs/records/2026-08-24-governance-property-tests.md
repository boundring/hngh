# Governance property tests record

## Scope

Lands the backlog item "Governance property tests"
(`docs/project/backlog.md`): an exhaustive fixture suite proving two
properties of the deterministic policy evaluator
(`hngh.domain:evaluate-policy-proposal`):

1. **Totality over closed kinds** — every closed proposal class × every
   closed evidence-requirement kind (7 × 21 = 147 combinations) evaluates
   without error to an `:admitted` verdict carrying exactly one principle
   result per matrix principle. An absent matrix principle refuses with
   the `missing-principle-result` label rather than erroring, for every
   class.
2. **Monotonicity** (the in-toto monotonic principle adopted as an
   invariant in `docs/records/2026-08-24-prior-art-landscape.md`) —
   ignoring evidence never flips a refusal into an admission. For each
   proposal class: an admitted baseline; then each single requirement's
   evidence facts emptied (required fingerprints kept) must refuse; and a
   second, different requirement also emptied must preserve the refusal.

## Decision

The properties are asserted **exhaustively over the closed
vocabularies**, not by random generation: the sets are small (7 classes,
21 kinds, 10 principles), so enumeration is both stronger and fully
deterministic. Boundaries are sourced from the live closed-vocabulary
constants in `src/domain/governance.lisp` via `prop-matrix` (copy of
`+matrix-principles+`) and the two `defparameter`s defined in the test
file, which the file itself asserts are the right sizes (7, 21, 10) so
the suite fails loudly if a vocabulary grows and the enumeration is no
longer exhaustive. `make-evidence-requirement` /
`make-evidence-fact` are used exactly as the domain enforces them; the
"ignored evidence" form is facts emptied with fingerprints kept, which is
the evidence-before-claim direction the monotonic principle describes.

## Evidence

- `tests/domain/test-governance-properties.lisp` — the exhaustive suite:
  coverage checks, the 147-combination totality loop, the
  absent-principle refusal path, and the single- and double-ignore
  monotonicity loops (each assertion a `check`, so a failure identifies
  the class/kind/principle).
- `tests/run.lisp` — one registration line after
  `tests/domain/test-governance.lisp`.
- `make test`: 8 reader guards + **2353 checks** passed (up from 1334),
  ASDF load clean.
- Recorded in `CHANGELOG.md` and this record; governance commit bound to
  the change (see governance record if a separate commit).

## Remaining unknowns

The properties are proven for the current closed vocabularies; any
future addition to the classes, kinds, or principles must extend this
suite (the size guards will fail loudly until it does). A formal
property-checking harness (QuickCheck-style) is not warranted while the
sets stay enumerable.