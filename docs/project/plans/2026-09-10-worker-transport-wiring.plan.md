# 2026-09-10 — run-worker transport wiring (operator-file worker transport)

Executed session for the accepted plan "2026-09-06 — run-worker transport
wiring" (routed run-worker-transport plan, accepted 2026-09-07T01:01:21Z).
New slug per the plan-file rule; the accepted plan text is authoritative
and is not modified here.

## Authorization chain (kernel src through the ceremony)

- The accepted plan's step 2 directs landing the src change through the
  dogfood ceremony recorded in
  docs/records/2026-09-06-generate-publication-post-hoc-certification.md.
- docs/records/2026-09-09-operator-flexibility-doctrine.md §2 + guardrail
  ("kernel src mutations go through the certificate ceremony with green
  `make test`") is the standing operator authorization; AGENTS.md encodes
  the same exception ("certificate-bound :wake-mutation work"). This
  wiring is the wake-mutation lane's recon prerequisite (plan step 3
  mounts the lane run), so it rides that exception.
- Session scope: src/main.lisp + tests (kernel, via ceremony only);
  docs/records, CHANGELOG, plan/ledger files (docs ceremony);
  hngh-automation ledger commits (free). No provider, credential,
  systemd, or secret changes. Push per standing push-on-demand; on push
  refusal, file an alert row and continue.

## Design (mirrors the reviewer= pattern, src/main.lisp:839-901)

- `+worker-config-keys+` = `(:command :timeout-seconds)`, closed.
- `parse-worker-config`: strict KEY=VALUE over the closed keys (`#`
  comments, blank lines skipped; unknown/duplicate/missing/empty refuse;
  timeout-seconds parsed as a positive integer). All keys required —
  mirrors `parse-reviewer-config`.
- `read-worker-file`: returns (values ports nil) or (values nil refusal);
  file-error → "cannot read worker file", parse error → "malformed
  worker file". Builds `hngh.adapters.worker:make-worker-ports` over a
  callback executing the named command with the task label as argv[1]
  and the payload on stdin.
- Timeout enforcement (the rung's "bounded" invariant): `uiop:launch-program`
  with :input/:output/:error-output :stream, write payload + close input,
  poll `uiop:process-alive-p` against timeout-seconds, `uiop:terminate-process`
  + reap on expiry → (values nil nil nil) → adapter faults the run
  (worker-fault). Verified live 2026-09-10 (SBCL 2.6.8): /bin/cat
  roundtrip exit=0 with payload echo; /bin/sleep 30 killed at 0.5s
  deadline, exit=143. `uiop:run-program` has no timeout and
  `sb-ext:process-wait-with-timeout` does not exist on this SBCL — the
  poll loop is the minimum working bound.
  ponytail ceiling: the payload stdin write can block against a child
  that fills its stdout pipe before reading stdin (payload ≤ 64 KiB,
  pipe ≥ 64 KiB); replace the write with non-blocking plumbing only if
  a real worker ever hangs there.
- `dispatch-run-worker`: accepts `worker=PATH` alongside `task=` and
  `payload=`; a named file replaces injected ports and is validated
  BEFORE any run lookup or admission work (exact reviewer= precedent,
  test-governance-dispatch.lisp:465-530); refusal rc=2 for missing or
  malformed files; no worker= named leaves the no-worker-transport
  refusal intact. Usage line and docstring updated.

## Verification contract

- New fixture file alongside tests/adapter/test-worker.lisp (keeps that
  file's "no subprocess" header true): run-worker with worker=<temp
  file> command=/bin/true → rc=0, complete, :worker fact rendered;
  command=/bin/false → rc=1 refused; missing file → rc=2; malformed
  file → rc=2; bad timeout-seconds → rc=2; command=/bin/sleep with
  timeout-seconds=1 → rc=3 fault (the bound fires); no worker= without
  injected ports → rc=1 no-worker-transport. `make test` green.
- Ceremony: create-run (mutation tool label, local route) →
  admit-transport filesystem repository → propose ten principles →
  issue-cert prepare-candidate + mutation-check → issue-cert commit +
  mutation-check (`hngh: candidate <content-hash>`); make test green;
  loop-history guard 0 new violations.
- Recon: run-worker on the mounted wake-mutation-lane lane card once,
  task=<bounded label>, worker=<operator file>; :worker evidence fact
  bound in the run ledger; no mutation receipt from run-worker.
