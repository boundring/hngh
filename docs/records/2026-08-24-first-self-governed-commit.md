# First self-governed commit record

## Scope

Completes roadmap promotion rung 9 — the dogfood development loop — with
the first commit produced, reviewed, certified, and committed by Hngh
itself under its own certificate. The candidate mutation is this
documentation change plus the roadmap and changelog entries.

## Decision

The operator governance surface (`propose`, `issue-cert`,
`mutation-check` in `scripts/hngh`) was exercised end to end against
live repository evidence: the policy proposal was evaluated to an
admitted verdict; the certificate was issued under the real evidence
chain (live base revision, per-file content hashes, verify-candidate
manifest); and `mutation-check` executed the certificate-bound commit
action through the installed git transport. The executed commit is bound
to the certificate content hash and candidate paths.

Push followed only after the full gate (`make test`) remained green on
the self-committed change.

## Evidence

- `src/main.lisp` supplies `dispatch-propose`, `dispatch-issue-cert`,
  `dispatch-mutation-check`, `real-run-evidence`, and the verdict
  report parser; `src/adapter/run-gather.lisp` supplies the real
  candidate-evidence runner (verify-candidate.py + SHA-256 file
  hashing + repository identity) behind an injected transport.
- `tests/run.lisp` executes 1334 checks and 8 reader guards green,
  including `tests/adapter/test-run-gather.lisp` and
  `tests/main/test-governance-dispatch.lisp`.
- The self-governed commit and its push were executed from this
  repository under certificate `candidate` of `commit` action;
  `git log` shows the certificate-bound commit message.
- Recorded in `docs/project/roadmap.md` (rung 9 Completed bullet),
  `CHANGELOG.md` (2026-08-24), and `docs/records/2026-08-24-first-self-governed-commit.md`.

## Remaining unknowns

The loop now self-commits documentation changes. Real model/terminal
worker transports and distributed attestation remain the next rungs;
self-push is exercised but push policy can be tightened later via the
closed `:push` action vocabulary.