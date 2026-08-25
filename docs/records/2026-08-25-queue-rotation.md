# 2026-08-25 — Queue rotation: the loop that runs itself

## Scope

`scripts/rotate-queue` is the continual-worker cadence closer: a
session does the slice work, then rotate-queue closes the governance
loop around it — flip the queue row, gather real candidate evidence,
run the operator reviewer (a real local-model session via the reviewer
file), propose under the ten principles, capture the verdict, bind the
certificate, execute the mutation, and land the queue ledger in the
same candidate commit. The periodic invocation belongs to the
operator's scheduler, never inside Hngh.

## The first rotation (doc-sync-loop)

Rotated **doc-sync-loop** — the documentation-sync item (a
`make test` doc-numbers guard that recomputes the README's check count
from the live suite, so the count can no longer drift by hand).

The live run:

- `create-run` (model route, worker-task+mutation tool labels,
  model-review network label) → exit 0;
- `admit-transport run-1 model repository` → exit 0;
- `review` through the operator reviewer file (local Unsloth,
  Ornith-1.0-35B) → `review status=complete findings=4` — four
  advisory metadata-level findings (shebang/scripting notes; the
  reviewer sees the content hash and paths, never file bytes, per the
  r6/r13 design; reviewers advise, never decide);
- `propose` with real evidence (content-hash = the candidate hash) →
  **verdict state=admitted principles=10**, captured as the operator
  verdict file;
- `issue-cert` + `mutation-check` `prepare-candidate` → `git add`
  executed; `commit` → `git commit` executed;
- `hngh: candidate bbd1d598…` landed; the queue row flipped to done;
  the ledger rode in the same commit.

## Evidence

- The rotated commit (`2fc6ac3`) contains the guard
  (`tests/scripts/test-doc-numbers.py`), its Makefile wiring, the
  `scripts/rotate-queue` runner, and the flipped queue ledger.
- `make test` green after rotation: **2774 checks**, doc-numbers guard
  passes (`README matches the live suite (past 2,774 checks)`),
  loop-history guard 15 code-surface commits / 1 named exemption / 0
  violations.
- Rotation exit 0 with `rotation complete: <hash> committed (item
  doc-sync-loop)`.

## Decisions

- The rotation is glue over the existing closed surface: every step is
  the same command an operator would run by hand; no new authority.
- The reviewer is advisory and the verdict is the gate — a refused
  verdict halts the rotation with exit 1.
- The queue ledger is part of the candidate, so the flip is
  certificate-bound like everything else.

## Remaining unknowns

- The other queued items (wake-mutation lane, node-lattice admission,
  bridge-operator-host, key-rotation-freshness, pooled hardware,
  tunnel automation, governance benchmark, DSSE export) wait their
  turn; a scheduler (operator-owned) can invoke rotate-queue
  periodically.