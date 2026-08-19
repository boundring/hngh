# Task R7 presentation and composition record

## Scope

Implements roadmap promotion rung 7: the operator-visible presentation
layer and the composition root. It adds `hngh.presentation`, `hngh.main`,
fixture-backed tests, and no daemon, service, watcher, scheduler, provider
call, or default model or terminal transport. The kernel domain and
application packages remain free of adapter dependencies, and
`hngh.presentation` imports no adapter.

## Decision

`hngh.presentation` is a renderer-only component. Pure render functions
turn application results, domain runs and governance values, and installed
adapter results into plain factual strings. Canonical terms stay literal
(`state=evacuated`, `verdict state=refused`, `mutation status=executed`), a
refusal renders as a literal refusal, and rendering never mutates a value.
The optional reference lexicon is accepted only as a flat plist carrying
exactly a `:render` list of four-field entries
(`:surface`, `:original`, `:reference`, `:provenance`); it supplies display
copy at a named surface only, falls back to the original term for unknown
surfaces, and can never carry canonical control fields. `render` dispatches
over every known value type and falls back to the printed representation
for unknown values.

`hngh.main` is the composition root. `make-run-harness` composes the five
application use cases into one `run-harness` over injected port callbacks;
omitted callbacks default to fail-closed or environment-free ports — an
in-memory record store reachable through `harness-records`, a per-harness
identifier source (`run-1`, `run-2`, …), a clock, and `:unknown` admission,
verification, and manifest evidence so nothing is admitted without composed
authority. Coordinator functions wire the installed adapters: evidence
(`gather-run-evidence`) and review (`request-run-review`) through injected
transports, and mutation (`execute-run-mutation`) which rechecks the
certificate against explicit fresh evidence and refuses when none is
supplied. `default-evidence-ports` composes the installed read-only process
transport; `default-mutation-ports` reuses it, with no gather-evidence
default. `display` renders any result through `hngh.presentation`. Loading
`hngh.main` starts no background work.

The domain gained read-only accessors (`run-identifier`, `run-mission`,
`run-role`, `run-loadout`, `receipt-kind`, `receipt-facts`) so presentation
renders runs and receipts without touching canonical state, and
`hngh.application` now exports the bare `verification-result` and
`manifest-result` type names used by the renderer's dispatch. The inward
dependency guard now treats `hngh.presentation` as an inward package: a
fixture proves it cannot import an adapter, and a second fixture proves the
composition root may import presentation and all installed adapters.

## Evidence

- `src/presentation/render.lisp` supplies `render` (dispatch), the
  per-value renderers, `render-report`, `reference-lexicon-p`,
  `render-with-lexicon`, and `render-status-label`.
- `src/main.lisp` supplies `make-run-harness`, the five `harness-*` entry
  points, `harness-records`, `default-evidence-ports`,
  `default-mutation-ports`, `gather-run-evidence`, `request-run-review`,
  `execute-run-mutation`, and `display`.
- `src/packages.lisp`, `hngh.asd`, and `tests/run.lisp` register both
  packages; `tests/support/boundary-guards.lisp` extends the dependency
  guard to presentation, with three new fixtures under
  `tests/fixtures/dependency-guard/`.
- `tests/presentation/test-presentation.lisp` renders every application,
  domain, and adapter result through real use cases and fixture transports,
  checks factual status invariance and literal refusal rendering, and
  verifies the reference lexicon against the Task 1 fixtures.
- `tests/main/test-main.lisp` composes the full run lifecycle through one
  harness (create → arm → start → checkpoint → close, one atomic
  run-and-receipt record per accepted use case), exercises the default and
  fail-closed port adapters, and wires the evidence, review, and mutation
  adapters through fake transports, rendering every result.
- `docs/project/roadmap.md`, `docs/core/component-map.md`,
  `docs/architecture.md`, `docs/core/clean-architecture-charter.md`,
  `docs/core/test-boundary.md`, `docs/project/decisions.md`, `README.md`,
  and `CHANGELOG.md` record rung 7 as complete.
- `make test` reports 8 reader-guard checks, 1137 Common Lisp checks, and a
  successful ASDF `hngh` load. Tests invoke only fakes and never contact a
  provider, subprocess, or network.

## Remaining unknowns

An explicit operator command entry (`hngh.main` as an executable
entrypoint), real model or terminal transports, and persistence remain
future rungs. Real transports must be separately approved and stay disabled
until a run loadout admits them; the kernel supplies no default provider
transport now.
