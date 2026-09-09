<!-- plan: status=accepted risk=normal accepted=2026-09-09T06:01:51Z -->
# 2026-09-09 — automation schedule optimization: backlog sweep, selector priority, throughput review

Authorization: operator-directed 2026-09-09. The operator asked this session
to have hngh "apply any further optimization to its schedule" after reviewing
queue state (66 accepted plans, filename-order slot-0 selection, fail-first
speed ladder at FF_SPEED 1-3, 45-77 commits/day recent throughput, 20 parked).
The executing session folds this directive into docs/records/ with its first
commit so the audit trail lands with the plan file.

This plan is the enabler for docs/project/plans/2026-09-09-omp-hngh-integration.plan.md
(operator-prioritized): it executes first by design (filename order places it
ahead), and its step 3 flags that plan so the selector honors the operator's
priority once supported.

## Steps

- [ ] 1. Backlog disposition sweep. Classify every currently `status=accepted`
      plan in docs/project/plans/ as live / superseded / obsolete / duplicate,
      with evidence per plan (alert history, automation/research-dispositions.tsv,
      work already landed in git log, references from other plans, dashboard
      plans.json state). Park stale ones with `cause=obsolete` and the evidence
      inline (existing router disposition convention). Guardrails: never touch
      `risk=critical`, already-parked plans, or plans whose premise has no
      counter-evidence; when in doubt, leave it live.
      Verification: sweep report in docs/research/ listing every accepted plan
      with verdict + evidence; automation/dashboard/plans.json parked count
      rises by exactly the parked set; no other plan file modified.
- [ ] 2. Selector priority support (failing test first). Extend
      automation/scripts/overnight-cycle.sh slot-0 selection: accepted plans
      carrying `priority=high` in the front-matter comment sort ahead of
      others; ties and absence fall back to current filename order. Document
      the key in docs/project/plans/README.md (one line under Contract).
      Add the automation script-suite test BEFORE the behavior change.
      Verification: suite test covers three cases (flag present sorts first,
      multiple flags keep filename order, no flag preserves current order);
      full `make test` green.
- [ ] 3. Flag the operator-prioritized integration plan. Add
      `priority=high` to the front-matter of
      docs/project/plans/2026-09-09-omp-hngh-integration.plan.md (depends on
      step 2 landing).
      Verification: front-matter carries the key; the suite test from step 2
      demonstrates the selector would pick it as slot 0 despite filename order.
- [ ] 4. Throughput evidence review. From the last 7 days of beat results
      (overnight results logs, breadcrumb lines, sessions/day vs
      MAX_SESSIONS_DAY), measure: beats/day, slot utilization, degraded-session
      rate at each FF_SPEED tier. Only if the degraded rate is flat while
      slots go unused, draft a cadence-param or ceiling adjustment with the
      numbers, committed through the normal gate with its own test. No blind
      bumps: the speed ladder exists to protect against degraded cascades.
      Verification: analysis note in docs/research/ with the measured numbers;
      any tuning change ships with a test; if data does not support a change,
      the note says so and no code changes.

## Execution notes

- Steps 1 and 2 are independent; 3 depends on 2; 4 is independent and
  evidence-gated.
- The sweep (step 1) is the big lever: parallel slots currently spend beats on
  plans whose premise may already be landed or obsolete. Do it first.
- Guardrail inherited from the operator directive: optimization must not
  reduce safety — the fail-first pacing, session ceiling, and certificate
  gates stay intact; only ordering and hygiene change.
