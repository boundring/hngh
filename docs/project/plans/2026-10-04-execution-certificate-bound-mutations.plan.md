<!-- plan: status=accepted risk=normal accepted=2026-10-04T04:06:35Z -->
principle: atomic-mutation — an effect without a certificate reference is an unrecorded mutation (docs/design/triple-kernel.md §2 effect-row)
# S3: execution kernel mutations ride certificates minted by legislation

Proposed via `omp-bridge --propose` (omp session propose surface;
see docs/project/plans/README.md).

## Steps

- [ ] Effect-row contract in automation: every dashboard POST mutation
      appends {certificate-ref, effect, files-touched, gate-result, ts}
      to automation/dashboard/effects.jsonl (JSON lines, append-only,
      atomic rename on rotation).
      Verification: py_compile automation/dashboard-server.py and a
      unit test posting one mutation asserts the effect row exists with
      all five keys.
- [ ] Control-room verbs (handle/dismiss/park/expire/suppress/
      acknowledge) request a certificate through the S2 admit entry
      point instead of bare token comparison; the dashboard token
      degrades to transport auth only.
      Verification: automation/tests/test-dashboard-p0.py mutation
      tests stay green with the admit shim in place.
- [ ] Self-review enforcement: automation/jobs/dashboard-self-review.py
      gains a check that every effect row cites a certificate and every
      certificate-granted mutation produced an effect row (drift
      alarm filed as an alert row on mismatch).
      Verification: python3 -B automation/jobs/dashboard-self-review.py
      self-test green with an injected drift fixture.
- [ ] Retire the raw-token mutation path once all verbs mint
      certificates (flag flip; token remains for read auth only).
      Verification: grep -c "X-Hngh-Token" automation/
      dashboard-server.py shows the token only on the read path.
- [ ] Document the landing in docs/design/triple-kernel.md section 3
      (S3 marked landed).
      Verification: grep -q "S3 .*landed" docs/design/triple-kernel.md

Note: risk=critical by policy — this plan changes the mutation trust
path end to end; reserved for the operator's deliberate ceremony.
