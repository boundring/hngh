# Command surface and transport admission record

## Scope

Implements the operator-facing command surface and real transport admission
rung. It adds `hngh.adapters.filesystem`, `admit-transport` in
`hngh.application`, `+admitted-transports+` in `hngh.domain`,
`hngh.main:dispatch-command`, the executable entry point `scripts/hngh`, and
in-process test suites. The kernel remains side-effect-free by default: no
ambient persistence exists, no daemon or watcher starts, and the filesystem
store operates only when an explicit `--store=PATH` is supplied.

## Decision

1. **Transport admission**: `hngh.application:admit-transport` extends the run
   lifecycle with explicit transport verification. A transport is admitted
   only when it belongs to the closed domain set `+admitted-transports+`
   (`(:filesystem)`), the run is in state `:created` or `:armed`, the scope is
   authorized by the mission and loadout, and no duplicate admission exists.
   Admitting a transport records an `:admission` receipt carrying the
   transport, scope, loadout route, run identifier, and clock timestamp.

2. **Default admission facts**: `hngh.main` wires default admission facts to
   consult the active store for a recorded `:admission` receipt naming the run.
   When found, all four admission axes (`:authority`, `:ledger`, `:loadout`,
   `:exclusive-write`) are `:confirmed`; otherwise they remain `:unknown` and
   `arm-run` refuses fail-closed.

3. **Filesystem adapter**: `hngh.adapters.filesystem` is a pure Common Lisp
   component importing only `CL` and `hngh.application` (no domain imports,
   enforced by boundary fixtures). It records run-and-receipt pairs as
   canonical plist lines under an operator-supplied root directory. Paths
   escaping the root or absolute identifiers signal `store-refusal`; missing
   or unwritable roots signal `transport-fault`.

4. **Command surface & protocol**: `hngh.main:dispatch-command` parses argument
   vectors and coordinates the 7 CLI operations (`create-run`,
   `admit-transport`, `arm-run`, `start-run`, `checkpoint`, `close-run`,
   `present`). It returns `(values output-string exit-code)` adhering to a
   strict exit code protocol:
   - `0`: accepted / successful query
   - `1`: application refusal or record conflict (literal status rendered)
   - `2`: malformed invocation (unknown command, arity, or transport)
   - `3`: adapter transport fault
   Usage information is written to `*error-output*` on malformed invocations;
   successful rendering uses existing `hngh.presentation` formatters.

5. **Executable wrapper**: `scripts/hngh` provides a portable SBCL script
   wrapper invoking `hngh.main:dispatch-command` with standard command-line
   arguments and propagating the integer exit code via `uiop:quit`.

## Evidence

- `src/application/admit-transport.lisp` and `src/domain/governance.lisp`
  supply transport admission and `+admitted-transports+`.
- `src/adapter/filesystem.lisp` supplies `make-filesystem-store`,
  `store-record-run`, `store-entries`, `store-refusal`, and `transport-fault`.
- `src/main.lisp` exports `dispatch-command` and wires the store, CLI parser,
  and admission callback.
- `scripts/hngh` is an executable script wrapper verified with end-to-end
  lifecycle execution (`create-run` -> `admit-transport` -> `arm-run` ->
  `start-run` -> `checkpoint` -> `close-run` -> `present`).
- `tests/application/test-admit-transport.lisp` exercises transport admission
  contracts, scope checks, duplicate detection, and receipt generation.
- `tests/adapter/test-filesystem.lisp` verifies replay survival, duplicate
  conflict detection, root confinement, and fault conditions.
- `tests/main/test-dispatch.lisp` exercises all 7 commands and exit codes (0,
  1, 2, 3) in-process.
- `make test` runs 8 reader guard checks, 1260 Common Lisp checks, and ASDF
  system loading cleanly.

## Remaining unknowns

Real model and terminal transports remain disabled and require separate run
loadout admission and adapter implementations. Multi-machine federation and
distributed attestation remain future governance proposals.
