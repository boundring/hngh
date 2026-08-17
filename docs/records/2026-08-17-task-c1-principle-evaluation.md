# Task C1 deterministic principle evaluation record

## Scope

Implements the deterministic evaluator over the immutable proposal ledger
added in task C0. It adds a pure `evaluate-policy-proposal` function and
fixtures, but no certificate, port, adapter, provider route, model review,
filesystem access, Git operation, process, service, daemon, watcher,
scheduler, or mutation.

## Decision

`evaluate-policy-proposal` consumes one immutable `policy-proposal` and returns
a `policy-verdict` carrying exactly ten principle results in matrix order, one
per closed principle: `closed-authority`, `least-authority`,
`dependency-direction`, `fail-closed`, `evidence-before-claim`,
`atomic-mutation`, `reversibility`, `no-hidden-execution`,
`cost-and-route-discipline`, and `source-grounding`. The order is fixed by the
matrix, never by requirement order in the proposal.

A principle with no evidence requirement is a refusal: a `:refused` principle
result with no fingerprints and reason label `missing-principle-result`. A
single evidence requirement passes only when every required fingerprint is
supplied exactly once by a `:current` fact. Missing, stale, malformed,
conflicting, or unverifiable facts refuse with the labels `missing-evidence`,
`stale-evidence`, `malformed-evidence`, `conflicting-evidence`, and
`unverifiable-evidence`. A fact supplied under one principle never satisfies a
requirement of another principle. The verdict is `:admitted` only when every
principle result is `:passed`; otherwise `:refused` with the deduplicated
union of refusal labels in matrix order.

Evaluation is deterministic, side-effect-free, and independent of requirement
order. The pure evaluator never emits `:needs-escalation`; that state remains
reserved for later reviewer and failure-disposition policy. Extra `:current`
facts beyond a requirement's required fingerprints do not refuse: the closed
refusal vocabulary names only missing, duplicate, stale, malformed,
conflicting, and unverifiable facts.

## Recovery observation

This slice ran cleanly against its brief on the first pass: the implementation
and its tests landed together and the full gate passed without a recovery pass.
No recovery lane from task C0 was re-entered.

## Evidence

- `docs/project/decisions.md` records the principle matrix, the rule that a
  missing principle result is a refusal, and this exact evaluation contract.
- `src/domain/governance.lisp` supplies `+matrix-principles+`,
  `evidence-requirement-passed-p`, and `evaluate-policy-proposal` as pure
  values and functions. `src/packages.lisp` exports `evaluate-policy-proposal`.
- `tests/domain/test-governance.lisp` adds 30 checks covering ten-principle
  admission, missing-principle refusal, absent/stale/malformed/conflicting/
  unverifiable/missing evidence labels, two-requirement principles,
  cross-principle evidence isolation, requirement-order independence, extra
  current facts, and nil/non-proposal input.
- `make test` reports 640 checks passed: 8 reader guard checks, 640 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The failure-disposition mapping, certificate issuer, and evidence adapter do
not exist yet. `:needs-escalation` is present in the state vocabulary but not
emitted by the pure evaluator; the reviewer-challenge and failure-disposition
policy that may reach it are a later slice.