# 2026-08-24: Operator governance command surface for the dogfood loop

## Scope

Adds the operator-facing entry points that run the governance pipeline
in-process: `propose` forms a closed `policy-proposal` and renders the
deterministic verdict, `issue-cert` mints a candidate certificate bound to a
stored admitted run, and `mutation-check` replays the certificate against
fresh fixture evidence through injected mutation ports. No real Git
invocation, subprocess, or external transport is admitted anywhere in the
slice.

## Decision

1. The three commands extend the existing `hngh.main:dispatch-command*`
   dispatch table and `command-usage` text, keeping the closed exit code
   protocol (0 accepted/admitted/executed, 1 refused/mismatch/missing,
   2 malformed, 3 transport fault).
2. `propose` reuses the operator `key=value` option style of the existing
   surface, maps every field onto `make-policy-proposal` (all 15 fields
   required; closed kind validation stays in the domain), and renders the
   verdict through the existing presentation renderer with no new renderer.
3. `issue-cert` recomputes the certificate bindings from the store rather
   than asking the operator: repository identity from the store root
   directory name, base revision from the run identifier, candidate paths
   from the positional arguments (defaulting to the fixture candidate), and
   the admitted verdict from the deterministic fixture-proposal pattern
   already used by `close-run` for the promotion rung 8 `approve` path. A
   run without an `:admission` receipt is refused with labels.
4. `mutation-check` builds fresh mutation evidence with the shared
   poseld payload (`dogfood-payload`) so the certificate and the fresh
   evidence agree, then calls `execute-run-mutation` with the injected
   `:mutation-ports`; extra evidence arguments deliberately desync the
   evidence hashes so the mismatch path is observable from the CLI. Default
   ports are only consulted when no injection is passed, and no test drives
   that path.
5. `hngh.main:dispatch-command` gains only one new injection key —
   `:mutation-ports` — threaded to `dispatch-command*`. Everything else
   stays closed: no new renderers, no new adapters, no new application
   use cases, no process spawning.

## Evidence

- `make test` passes: 8 parent guard checks, 1,290 checks (including the
  new `tests/main/test-governance-dispatch.lisp`, registered in
  `tests/run.lisp`), and a clean ASDF load.
- The test suite guards that no test path ever calls `uiop:run-program`/
  `sb-ext:run-program` (symbol-function wind-up around the mutation-check
  execution path).
- All assertions exit-code behavior (admitted 0, refusal labels 1, malformed
  2) and lease the operator surface previously user-invoked in hand runs.

## Hints

- The certificate `expiry` is the fixed earlier-than-clock value
  `2026-08-25T00:00:00Z` against the fixed test clock
  `2026-08-24T00:00:00Z`; a live `mutation-check` outside the fixture
  window refuses with `expired-certificate`.
- The fixture-manifest and evidence-requirement parsing stay strict:
  `PATH=HASH:ROLE` and `PRINCIPLE:KIND:FINGERPRINTS` only.

## Remaining unknowns

- Wiring real Git ports (the actual `git` process transport) behind the
  fixture surface, to close the loop on a real repository, is the next dogfood
  rung and does not belong to this slice.
- A large-scale `propose` policy profile than "one requirement per matrix
  principle" (operator-tunable policy profiles) is deferred; the surface
  carries the fixture profile only.