# Task C2 closed failure-disposition policy record

## Scope

Implements the separate closed failure-disposition policy over the closed
failure categories. It adds a pure `evaluate-failure-disposition` function and
fixtures, but no certificate, port, adapter, provider route, model review,
filesystem access, Git operation, process, service, daemon, watcher,
scheduler, or mutation.

## Decision

`evaluate-failure-disposition` maps each of the eight closed failure categories
to exactly one closed disposition, refusing unknown categories. Domain and
application invariants propagate to the test gate; port-callback faults and
malformed returns normalize to a refusal at that callback only; atomic
recording conflicts normalize to conflict without retry; insufficient or stale
evidence refuses; tool and environment faults refuse; review disagreement
escalates; and mutation precondition mismatches stop and record evidence.

The two conditionally worded table rows in
`docs/design/autonomous-development-control.md` resolve to their primary
default in the pure policy, per the operator-approved contract: a
domain-policy-or-invariant failure propagates to the test gate (the typed
domain refusal refinement belongs to a later runtime layer), and a tool or
environment fault refuses (named evidence-policy escalation is a later
refinement). The policy is deterministic and total over the closed category
set; a use case never decides a disposition by catch-all condition handling.

## Build note: list-valued constants and SBCL redefinition

The three list-valued vocabularies in `src/domain/governance.lisp`
(`+matrix-principles+`, `+failure-categories+`, `+failure-dispositions+`) use
`defparameter`, not `defconstant`. SBCL evaluates a `defconstant` form at
compile time (for constant folding) and again when the compiled fasl is
loaded; the two literal objects are not `eql`, so an ASDF recompile raises
`DEFCONSTANT-UNEQL` ("The constant ... is being redefined") even when the
values are textually identical. `eval-when (:load-toplevel :execute)` does not
prevent the compile-time side effect, and SBCL 2.6.7's `defconstant` accepts
no `:test` keyword. `#.` reader-eval made the plain source-load path fail.
`defparameter` survives the full compile/load/recompile cycle; immutability of
the vocabulary is enforced by the closed-vocabulary fixtures, not by the Lisp
constant mechanism. A future agent that adds another list-valued vocabulary
should follow the same pattern.

## Evidence

- `docs/project/decisions.md` records the closed failure-disposition decision
  and the primary-default resolution of the conditional rows.
- `src/domain/governance.lisp` supplies `+failure-categories+`,
  `+failure-dispositions+`, and `evaluate-failure-disposition` as pure values
  and a function; `src/packages.lisp` exports `evaluate-failure-disposition`.
- `tests/domain/test-governance.lisp` adds 10 checks covering all eight
  category-to-disposition mappings, unknown-category refusal, and disposition
  validation.
- `make test` reports 650 checks passed: 8 reader guard checks, 650 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The certificate issuer and evidence adapter do not exist yet. The conditional
refinements (typed-domain-refusal on top of a propagated domain failure;
escalation through named evidence policy) are deferred to the runtime layers
that can observe those facts. The next executable slice is the non-mutating
candidate authorization certificate, per `docs/project/roadmap.md`.