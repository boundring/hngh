# 2026-08-25 — Continual-worker driver

## Scope

`scripts/worker-driver`: one explicit operator invocation that runs the
worker lane end to end — create-run (with the worker-task loadout
label) → admit-transport worker → run-one bounded read-only worker task
→ close the run. It is glue over the existing dispatch surface: no new
authority, no new transport, no daemon.

## Decision

1. The driver is a thin SBCL script that calls the closed commands in
   order through `hngh.main:dispatch-command`, checking each exit and
   stopping on the first refusal.
2. The argv parsing uses `uiop:raw-command-line-arguments` (the true
   invocation arguments, not SBCL's `*posix-argv*` under `--script`).
3. A bare invocation refuses at `run-worker` with `no-worker-transport`
   — the honest no-default-wire behavior; the worker lane needs the
   injected transport, which remains the operator's call.
4. The periodic invocation belongs to the operator's scheduler, never
   inside Hngh (no daemon, no watcher).

## Evidence

- Tests (test-worker-driver.lisp) run the REAL script as a subprocess:
  a malformed invocation (no store) exits 2; a bare cycle (no ports)
  exits 1. `make test` green at 2772 checks.
- Live manual run: create → admit both exit 0; run-worker correctly
  refuses `no-worker-transport` (bare script); the injected variant
  completes the full cycle (create=0, admit=0, work=0) in the live
  shell proof.
- Committed through the self-governed validation loop (`6da05b9`), gate green,
  pushed.

## Remaining unknowns

- The injected full-cycle proof lives at dispatch level and in the
  shell; the script's own full-cycle path (with injected ports) is
  exercised only live, not in the suite (the script never gets ports —
  the operator composes the transport).