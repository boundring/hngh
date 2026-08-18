# Task R5 mutation executor record

## Scope

Implements roadmap promotion rung 5: the certificate-bound mutation executor.
It adds `hngh.adapters.mutation`, fixture-backed tests, and no daemon, service,
watcher, scheduler, model-review adapter, remote push, or default process. The
kernel domain and application packages remain free of adapter dependencies.

## Decision

`execute-mutation` accepts a `candidate-certificate`, optional fresh
`mutation-evidence`, and `mutation-ports`. When fresh evidence is omitted, the
ports may gather it through an injected callback. The executor rechecks
repository identity, base revision, ordered candidate paths, content hash,
evidence hashes, admitted principle verdicts, review findings, source
manifest, policy profile, and expiry before creating the command. A mismatch or
invalid/stale fact returns a typed refusal and invokes no mutation transport.

The action vocabulary is fixed: `:none`, `:prepare-candidate`, `:stage`,
`:commit`, and `:push`. `:none` is refused. `:prepare-candidate` and `:stage`
use `git add -- <candidate-paths>`, `:commit` uses a fixed `git commit`
message containing the certificate content hash and the bound candidate paths,
and `:push` uses `git push origin HEAD`. An optional requested action must
match the certificate action; it cannot escalate a stage or commit certificate.
Commands are argv lists, never shell strings, and all process calls sit behind
`mutation-ports`.

Results are closed values: `:executed`, `:refused`, `:mismatch`,
`:command-failed`, or `:transport-fault`, with stable refusal labels and
bounded command output. Unknown, malformed, duplicate, unadmitted, expired,
unsupported, or unauthorized inputs fail closed.

## Evidence

- `src/adapter/mutation.lisp` supplies `mutation-evidence`, `mutation-ports`,
  `mutation-result`, the fixed action set, and `execute-mutation`.
- `src/packages.lisp`, `hngh.asd`, and `tests/run.lisp` register the adapter.
- `tests/support/fakes.lisp` supplies the mutation process/evidence fake;
  `tests/adapter/test-mutation.lisp` covers every action, every certificate
  fact mismatch, expiry, missing verdict, action escalation, malformed input,
  command failure, transport fault, and evidence gathering through the port.
- `docs/project/roadmap.md`, `docs/core/component-map.md`, `README.md`, and
  `CHANGELOG.md` record rung 5 as complete and bounded model review as next.
- `make test` reports 8 reader-guard checks, 888 Common Lisp checks, and a
  successful ASDF `hngh` load. Tests invoke only fakes and never mutate the
  repository or working tree.

## Remaining unknowns

Bounded model-review adapters remain the next roadmap rung. Real composition of
repository identity and fresh evidence is deferred to an outer composition
root; this adapter intentionally requires explicit evidence or an injected
gather callback and never reads ambient state itself.
