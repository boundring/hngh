# Task C0 proposal evidence ledger record

## Scope

Implements the pure input contract needed before deterministic principle
evaluation. It adds immutable domain values and fixtures, but no evaluator,
certificate, port, adapter, provider route, model review, filesystem access,
Git operation, process, service, daemon, watcher, scheduler, or mutation.

## Decision

Every future deterministic evaluation receives one immutable
`policy-proposal`. It records the closed proposal class; problem; smallest
useful outcome; purpose; caller; input; output; failure contract; declared
capabilities; capability diff; source manifest; risk note; dependency; evidence
trigger; and ordered evidence requirements.

Each immutable `evidence-requirement` binds one closed principle to a closed
requirement kind, required fingerprints, and supplied immutable evidence facts.
The closed requirement kind provides evaluator meaning while evidence-fact kind
remains open. A requirement is complete only when each required fingerprint is
supplied exactly once by a current fact. Missing, duplicate, stale, malformed,
conflicting, or unverifiable facts refuse.

The proposal and ledger are non-authoritative. They contain no action,
certificate, repository authority, provider execution detail, port, callback,
filesystem, Git, process, clock, environment, or network field.

## Recovery lesson

This slice required recovery after overlapping partial delegated edits left
duplicate definitions and an unbalanced package boundary. The recovery worker
inspected the actual lane, retained valid refusal and defensive-copy fixtures,
reconciled one canonical value surface, and reran the full gate before a fresh
review. Future partial delegated lanes follow the same rule: recover the
candidate in place; do not discard coverage or restart from an assumed-clean
state.

## Evidence

- `docs/project/decisions.md` makes proposals and source manifests mandatory
  for policy evaluation and requires invalid evidence to refuse.
- `docs/project/backlog.md` requires problem, smallest outcome, source
  manifest, principle matrix, risk note, dependency, and evidence trigger.
- `docs/design/autonomous-development-control.md` supplies the ten principles,
  required evidence, and refusal conditions.
- `src/domain/governance.lisp` supplies immutable source, evidence, principle,
  and verdict values but intentionally leaves fact kind open; the ledger closes
  policy meaning without turning fact producers into domain policy.

## Remaining unknowns

The deterministic evaluator, failure-disposition mapping, certificate issuer,
and evidence adapter do not exist yet. The next executable slice is pure
principle evaluation over these immutable values.
