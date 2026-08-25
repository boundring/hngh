# 2026-08-25 — Machine-checked self-governance (loop-history guard)

## Scope

Makes the README's restated governance claim falsifiable by
construction: a guard in the gate walks every code-surface commit since
the restatement and fails on anything that is not certificate-bound or
rule-exempt. The carve-out ("the exception is by rule, not by mood")
ceases to be prose and becomes a checked invariant.

## Decision

1. `tests/scripts/test-loop-history-guard.py` walks `git log` from the
   restatement commit `1915713`; every commit touching the code surface
   (`src/`, `tests/`, `scripts/`, `Makefile`, `hngh.asd`) must be
   `hngh: candidate <64-hex>` or carry
   `excluded from cert manifest by dependency guard` in its message.
2. The one known pre-guard violation — `915e0e3`, a comment-only
   alignment of composition-root references committed as a plain docs
   commit — is exempted by name and recorded in
   `docs/project/decisions.md` as history, not rewritten.
3. The carve-out is a recorded decision entry (export-only/no-behavior
   changes excluded by the dependency guard, labeled in the commit
   message).
4. `make test` runs the guard (before the paren lint), so the claim is
   checked on every gate.

## Evidence

- The guard passes on current history:
  `8 code-surface commits checked, 1 named exemption(s), 0 violations`
  — the 4 candidate commits and 3 labeled chore-export commits since
  the restatement, plus the named `915e0e3`.
- The README now says the sentence is machine-checked; CHANGELOG and
  decisions.md record the carve-out and the pre-guard blemish.
- Committed through the self-governed ceremony (code: Makefile + guard;
  docs: decisions, changelog, README, this record) — the guard's own
  introduction commits are themselves candidate-bound.

## Remaining unknowns

- The guard watches the code surface; the docs surface rides the loop
  by convention (all since the restatement are candidate-bound or
  docs-only). Extending the guard to docs would change project history
  handling (docs-commits predate the restatement) and is future work.