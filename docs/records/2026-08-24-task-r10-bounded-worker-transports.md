# 2026-08-24: Bounded model & terminal worker transports (rung 10)

## Scope

Implements roadmap promotion rung 10: two INPUT/ADVISOR transports admitted
behind run loadouts. The bounded model transport (`hngh.adapters.model`)
supplies the `complete` callback shape every transport already uses so the
existing review adapter can drive a real provider; the bounded terminal
input adapter (`hngh.adapters.terminal`) captures one operator statement
as a `:terminal` evidence fact. Both are advisors only: neither can issue a
certificate, mutate a repository, or advance a run, and no default provider
or input source exists by import or in `scripts/hngh`. The slice adds the
two adapters, closed loadout admission for `:model` and `:terminal`, the
`review` and `terminal` CLI operations with fail-closed defaults, one new
presentation renderer, and exhaustive fixture coverage. No live endpoint is
contacted and no executor surface exists.

## Decision

1. `hngh.domain:+admitted-transports+` becomes the closed set
   `(:filesystem :model :terminal)`. No new domain value types and no new
   loadout fields are added: authorization reuses the run's existing
   loadout.
2. `hngh.application:admit-transport` keeps its closed checks and adds one
   loadout gate with the closed refusal label
   `loadout-refuses-transport`:
   - `:terminal` requires the loadout tool label `terminal-input`;
   - `:model` requires a non-`local` route label and the network label
     `model-review`;
   - `:filesystem` stays loadout-free.
   Admission still records the one `:admission` receipt, and `arm-run`
   still requires a `:confirmed` receipt through the store.
3. `hngh.adapters.model:make-model-transports` validates a closed provider
   configuration (`endpoint`, `model-name`, `max-tokens`, `timeout`,
   `provider-token`) and returns the `complete` callback of the exact
   transport shape every consumer uses: `(lambda (prompt) (values
   exit-code stdout stderr))`. The provider is reached only through the
   installed curl binary (the same subprocess style as the evidence
   adapter's git and sha256sum); a failing, timed-out, or oversized
   completion returns a nonzero exit-code, so the review adapter's existing
   closed mapping applies — a provider failure is an `:unverifiable`
   "unavailable" review fact, never new refusal vocabulary. The route gate
   (non-local route plus `model-review` network label) is enforced by the
   application admission layer, not in the adapter.
4. `hngh.adapters.terminal`: `make-operator-ports` captures one statement
   through an injected `read-statement` callback (a nil return is the
   operator's cancel/EOF) and returns an `operator-result`. A `:complete`
   capture binds statement `:current` evidence fact of kind `:terminal`
   with the fingerprint `"sha256:<hex>"`, computed by an in-process,
   vector-verified SHA-256 so capture never spawns a subprocess. A
   statement is bounded at 64KiB and must be printable with no control
   characters; oversized, unprintable, duplicate, cancelled, or thrown
   reads refuse closed (`statement-too-large`, `malformed-statement`,
   `transport-fault`). A statement never enters a certificate, mutation
   input, or any other control surface: it is bound only as a `:terminal`
   evidence fact.
5. `hngh.main` is the only wiring point. `dispatch-command` gains
   `&key review-ports terminal-ports`, threading through
   `dispatch-command*`; no default provider or input is composed — without
   injection the `review` and `terminal` commands refuse
   `no-review-transport`/`no-terminal-transport`, and plain `scripts/hngh`
   therefore carries the two routes fail-closed. The `review` command
   (required `content-hash=` and `paths=` options, optional
   `policy-context=`) runs only when the run holds a `:model` admission
   receipt; the `terminal` command captures one statement only when the run
   holds a `:terminal` admission receipt. `hngh.presentation` gains exactly
   one renderer, `render-operator-result` (outward only).
6. Fixtures: `make-operator-ports-fake` in `tests/support/fakes.lisp`
   scripts `(:return statement)`, `(:cancel)`, and `(:error message)`;
   `tests/adapter/test-terminal.lisp` asserts statement bounds, known-answer
   SHA-256 vectors, oversized/unprintable/cancel/duplicate refusals, and
   fingerprint binding; `tests/main/test-governance-dispatch.lisp` drives
   `review`/`terminal` through injected fakes with `uiop:run-program`
   shadowed so no subprocess is ever spawned, asserts exit 1 without a
   matching admission receipt, exit 2 `unknown-transport` when the closed
   admitted set excludes the kind, and `loadout-refuses-transport` for a
   plain loadout; `tests/application/test-admit-transport.lisp` covers the
   two new kinds and the three new refusal labels;
   `tests/domain/test-governance.lisp` locks the closed set. All tests are
   local, deterministic, provider-free, and `make test` stays green (8
   reader guard checks + 2,495 checks + a clean ASDF load).

## Evidence

- `make test` passes end to end: 8 reader guard checks, fresh yields
  `2,495 checks passed`, and the ASDF load of `hngh` is clean.
- The review-coordinator maps every closed provider outcome at
  `hngh.main:request-run-review`: exit 0 JSON findings :complete, a failing
  provider 500 becomes `:unverifiable` "unavailable", a thrown provider
  fault refuses `transport-fault`, and malformed JSON refuses
  `malformed-output`.
- `review` and `terminal` never spawn a subprocess when the injected ports
  are fakes (symbol-function wind-up around `uiop:run-program`, the same
  pattern as the mutation-check guard).
- The `:terminal` evidence fingerprint is a real in-process SHA-256,
  verified against the FIPS standard vectors (empty, "a", "abc", the
  quick-brown-fox sentence, and the two-block abcde...nopq vector).

## Hints

- The model transport's provider call uses the system curl binary with
  `--fail` so any HTTP failure exits nonzero and maps to the `:unverifiable`
  review fact; the token travels only in that one subprocess Authorization
  header (`ponytail:` note: argv visibility is the same trade-off as the
  evidence adapter's git/sha256sum invocations; an env- or config-file-
  based provider client is the documented upgrade path).
- The grade of the loadout gates lives entirely in
  `transport-loadout-refused-p` in the application layer; domain, adapters,
  and presentation have no loadout knowledge.
- Statement duplicate detection is per-operator-ports session state (like a
  terminal's scrollback), not a global ledger.

## Remaining unknowns

- A real provider client inside `make-model-transports` (the curl call) is
  composed by the operator at the composition root and is not exercised by
  the gate; a live end-to-end provider run is explicitly out of scope for
  this rung ("do not run live endpoints").
- Terminal statements are advisor-only evidence: recording them into the
  store ledger or feeding them to a later policy requirement kind is
  future work and deliberately not part of this slice.