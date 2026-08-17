# Task C3 non-mutating candidate authorization certificate record

## Scope

Implements the pure certificate issuer over an admitted policy verdict. It
adds a `candidate-certificate` value and `issue-candidate-certificate`, but no
action, callback, port, filesystem access, Git operation, process, service,
daemon, watcher, scheduler, or mutation executor.

## Decision

`issue-candidate-certificate` mints an immutable `candidate-certificate` from
an `:admitted` `policy-verdict`. The certificate authorizes one action only —
`:none`, `:prepare-candidate`, `:stage`, `:commit`, or `:push` — and records
repository identity, base revision, ordered candidate paths, content hash,
evidence hashes, the admitting verdict, review findings, source manifest,
policy profile, and expiry.

The issuer is mechanical, per the operator-approved boundary for this slice:
it validates the verdict is `:admitted`, the action is one of the closed
classes, and every recorded fact is present, nonempty, and duplicate-free,
then binds them into the immutable value. It does not judge whether a given
action is policy-admissible — a commit certificate never authorizing a push is
enforced later by the executor, not by the domain issuer. Unknown, missing,
duplicate, and malformed facts refuse; candidate paths and evidence hashes
must be nonempty and duplicate-free; the verdict list is nonempty and
duplicate-free; accessors defensively copy every string and list slot.

## Build note: leftmost `&key` occurrence

Validation tests that override a keyword in a base plist must not rely on a
later duplicate keyword winning: SBCL's `&key` argument binding uses the
leftmost occurrence of a duplicated keyword. Force a bad value with a direct
call, not a base-plist plus override.

## Evidence

- `docs/project/decisions.md` records the non-mutating candidate authorization
  certificate decision and the deferred action-admission boundary.
- `src/domain/governance.lisp` supplies `validate-certificate-action`,
  `candidate-certificate`, `make-candidate-certificate`, and
  `issue-candidate-certificate`; `src/packages.lisp` exports them.
- `tests/domain/test-governance.lisp` adds 29 checks covering every closed
  action being issuable, accessor round-trips, non-admitted/non-verdict
  refusal, unknown-action refusal, empty/duplicate candidate paths, missing
  content hash, missing/duplicate evidence hashes, duplicate verdicts, empty
  source manifest, missing expiry, and defensive copies.
- `make test` reports 679 checks passed: 8 reader guard checks, 679 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The mutation executor that rechecks every certificate fact immediately before
its named action does not exist yet; action-admission policy (such as commit
never authorizing push) is deferred to it. The next executable slice is
resuming the remaining application use cases under the admitted policy
proposal and evidence process, per `docs/project/roadmap.md`.