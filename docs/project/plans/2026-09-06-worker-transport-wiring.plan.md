<!-- plan: status=parked risk=normal accepted=2026-09-07T01:01:21Z source=gate-inventory-audit run-worker row cause=ceremony-required disposed=2026-09-11T19:10:00Z reason=kernel src/tests steps require the certificate ceremony lane; machine delegated sessions must not execute them (beat-stall diagnosis 2026-09-11); step 1 already landed in e42f637 -->
# 2026-09-06 — run-worker transport wiring (operator-file worker transport)

Rung 18 shipped the worker injection point — `dispatch-run-worker`
(src/main.lisp:1703) refuses `no-worker-transport` — but the kernel CLI never
builds worker ports, so every mounted recon run refuses (audit row in
docs/design/gate-inventory.md, proven live 2026-09-06). The fix mirrors the
review command's `reviewer=` file path (src/main.lisp:839-901): an operator
file names the worker transport; run-worker reads it, builds ports over the
worker adapter's `execute-worker` callback (src/adapter/worker.lisp, unchanged),
and the bounded read-only task rides the shipped rung. Landing rides the
dogfood ceremony per kernel law — the working recipe is recorded in the
evidence section of docs/records/2026-09-06-generate-publication-post-hoc-certification.md.
Serves the backlog "Certificate-bound wake mutation lane" recon prerequisite
and the "Bridge-backed continual worker" lane: step 3 lands the first mounted
worker evidence row.

## Steps

- [ ] Wire the operator-file worker transport in src/main.lisp mirroring the
      reviewer= pattern: add a closed +worker-config-keys+ vocabulary
      (command, timeout-seconds), a parse-worker-config / read-worker-file pair
      reading the file passed as worker=PATH on run-worker, building
      hngh.adapters.worker:make-worker-ports over a callback that executes the
      named command with the task label as argv and the payload on stdin;
      accept the worker= option key in dispatch-run-worker (alongside task= and
      payload=), and update the usage line and docstring. No worker= file named
      means the existing no-worker-transport refusal stands.
      Verification: new fixture alongside tests/adapter/test-worker.lisp — a
      dispatch-command invocation with worker=<temp file> whose command exits 0
      completes the task (rc=0, :worker evidence fact rendered); the same run
      without worker= still refuses no-worker-transport; a malformed file
      refuses with rc=2; make test green.
- [ ] Land the src change through the dogfood ceremony exactly as recorded in
      docs/records/2026-09-06-generate-publication-post-hoc-certification.md:
      create-run (mutation tool label, local route) -> admit-transport <run>
      filesystem repository -> propose under the ten closed principles ->
      issue-cert prepare-candidate + mutation-check (git add) -> issue-cert
      commit + mutation-check (fixed-message git commit "hngh: candidate
      <content-hash>").
      Verification: git log -1 --format=%s on the src change matches
      ^hngh: candidate [0-9a-f]{64}$; make test green; the loop-history guard
      reports 0 new violations.
- [ ] Recon run against the mounted wake-mutation-lane lane card: invoke
      run-worker <run> task=<bounded label> worker=<operator file> once; the
      bounded read-only task executes and the completion binds the :worker
      evidence fact in the run ledger. No mutation beyond the read-only task
      scope; no certificate is issued by this command.
      Verification: present <run> renders rc=0 with the :worker evidence row in
      the kernel ledger; the store records exactly one completed task and no
      mutation receipt from run-worker.
