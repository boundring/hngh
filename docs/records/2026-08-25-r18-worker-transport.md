# 2026-08-25 — Rung 18: bounded read-only worker task

## Scope

The worker-rung first slice: one closed, read-only worker task through
an injected transport, bound as `:worker` evidence. This is the runtime
surface the backlog's bridge-backed worker will exercise — the steps
toward "the loop that runs itself" begin here, read-only.

## Decision

1. `hngh.adapters.worker` supplies the closed worker surface:
   - `worker-request` — a bounded task label (≤256 printable chars, no
     control characters) plus an optional bounded payload (≤64KiB);
   - `worker-ports` — one injected `execute-worker` callback, called
     `(EXECUTE-WORKER REQUEST)` returning
     `(values exit-code stdout stderr)`, no default transport;
   - `run-worker-task` — a zero exit binds a `:worker` `:current`
     evidence fact (fingerprint = the task label), a nonzero exit
     refuses `worker-refused`, a throw faults `worker-fault`.
2. `:worker` joins `+admitted-transports+` behind the `worker-task`
   tool label on the run loadout (the `admit-transport` loadout gate).
3. `run-worker RUN task=LABEL [payload=TEXT]` is the surface: the run
   must hold a `:worker` admission receipt; without injected
   `worker-ports` it refuses `no-worker-transport`; a malformed task is
   a malformed invocation. Exit 0 complete, 1 refused, 3 fault.

## Evidence

- Tests first, red, then green: `make test` passes 8 reader guards and
  2770 checks (+21: adapter request/result/refusal/fault + payload
  travel, worker admission accept/refuse, dispatch
  complete/no-ports/unadmitted). The transport-set assertion is updated
  to the five closed kinds.
- The gate was run after every change; the final gate passed on the
  candidate commit.
- Committed through the self-governed ceremony: `src/packages.lisp`
  exports via the chore lane excluded by the dependency guard
  (`5574943`); implementation and tests proposed (admitted 10/10),
  certified against real evidence, committed as
  `hngh: candidate 55a2d741…` (`f29c6e2`), pushed; gate green.
- README, changelog, roadmap, and this record updated.

## Remaining unknowns

- The hngh-omp bridge tools for the worker surface (driving a disposable
  omp session behind the bridge) remain the next worker-rung slice;
  this rung ships the harness side only.
- A worker self-report stays evidence, never acceptance.

## Live end-to-end proof (2026-08-25, same day)

A full lifecycle ran through the dispatch surface with a real worker
transport (a bounded python3 subprocess doing read-only scan work):

- `create-run` (with the `worker-task` tool label) exit 0;
- `admit-transport run-1 worker repository` exit 0;
- `run-worker run-1 task=scout candidates payload=candidate.lisp` exit 0
  with `worker status=complete task=scout candidates`;
- `present run-1` exit 0, rendering the run in the ledger.

The adapter-level call bound the `:worker` `:current` evidence fact
(fingerprint = the task label) from the same real subprocess. The lane
from run to worker evidence is exercised end to end.