# Task D1 policy-gated close-run record

## Scope

Resumes the remaining application use cases under the admitted policy proposal
and evidence process. It adds the `close-run` application use case and its
ports, but no certificate issuance, adapter, filesystem access, Git operation,
process, service, daemon, watcher, scheduler, or mutation executor.

## Decision

`close-run` advances a run to a terminal state — `:cancelled`, `:evacuated`,
or `:dead` — only under an `:admitted` policy verdict. The `close-request`
carries the run, a closed terminal target, and a policy proposal; the use case
evaluates the proposal deterministically via `evaluate-policy-proposal` and,
unless the verdict is `:admitted`, refuses with the verdict reason labels. An
illegal target for the run's current state refuses with the closed
`invalid-transition` label. Recording is one atomic run-and-receipt callback;
conflicts refuse without retry and stay atomic; malformed or erroring
callbacks refuse.

`close-run` issues no certificate. The hash-bound `candidate-certificate`
vocabulary serves the future mutation executor (which rechecks every
certificate fact immediately before its named action); run-state transitions
do not bind hash-bound mutation facts. Action-admission policy remains with
that executor.

## Evidence

- `docs/project/decisions.md` records the policy-gated run close decision.
- `src/application/ports.lisp` supplies `close-request`,
  `make-close-request`, `close-request-run`, `close-request-target`,
  `close-request-proposal`, and `run-close-ports`; `src/application/close-run.lisp`
  supplies `close-run`; `src/packages.lisp` exports them.
- `tests/application/test-close-run.lisp` adds 38 checks covering admitted
  and refused proposals, every terminal target, illegal transitions, atomic
  recording conflicts, callback errors, malformed returns, and wrong-typed
  inputs; `tests/support/fakes.lisp` gains `make-close-fake`.
- `make test` reports 717 checks passed: 8 reader guard checks, 717 in
  `tests/run.lisp`, then an ASDF `:hngh` load.

## Remaining unknowns

The read-only evidence adapter, mutation executor, and model-review adapters
do not exist yet; the executor is the first consumer of the issued
certificate and the verification gates named in
`docs/design/autonomous-development-control.md`. The next executable slice
per the roadmap is the read-only evidence adapter, then the mutation executor.