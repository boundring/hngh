<!-- plan: status=executed risk=normal accepted=2026-09-09T06:01:51Z -->
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

PRIORITY NOTE 2026-09-09 (operator session): step 2 is the
highest-leverage unfinished item in the queue — until the priority
selector lands, every operator-priority plan waits behind one-step
misc plans in filename order. Sessions executing this plan should take
step 2 (with step 5's gate isolation) before discretionary work; step 1
is already complete (operator-procedural sweep, twice over).

## Steps

- [x] 1. Backlog disposition sweep. Classify every currently `status=executed`
      plan in docs/project/plans/ as live / superseded / obsolete / duplicate,
      with evidence per plan (alert history, automation/research-dispositions.tsv,
      work already landed in git log, references from other plans, dashboard
      plans.json state). Park stale ones with `cause=obsolete` and the evidence
      inline (existing router disposition convention). Guardrails: never touch
      `risk=critical`, already-parked plans, or plans whose premise has no
      counter-evidence; when in doubt, leave it live.
      Executed operator-procedurally 2026-09-09 (report: docs/research/2026-09-09-backlog-disposition-sweep.md);
      dashboard plans.json mirror refreshes on the 30m tick. Performed outside the session-budget
      cap because the cap itself was the blocker (see stall-recovery plan).
      Verification: sweep report in docs/research/ listing every accepted plan
      with verdict + evidence; automation/dashboard/plans.json parked count
      rises by exactly the parked set; no other plan file modified.
- [x] 2. Selector priority support (failing test first). Extend
      automation/scripts/overnight-cycle.sh slot-0 selection: accepted plans
      carrying `priority=high` in the front-matter comment sort ahead of
      others; ties and absence fall back to current filename order. Document
      the key in docs/project/plans/README.md (one line under Contract).
      Add the automation script-suite test BEFORE the behavior change.
      Executed 2026-09-12T16:35Z: tests/test-plan-priority-selector.sh
      (three cases, red-first), selector bucket ordering in
      overnight-cycle.sh, contract line in docs/project/plans/README.md.
      automation `make test` green rc=0; commits 3542a19 (automation)
      + 82e026e (kernel docs).
      Verification: suite test covers three cases (flag present sorts first,
      multiple flags keep filename order, no flag preserves current order);
      full `make test` green.
- [x] 3. Flag the operator-prioritized integration plan. Add
      `priority=high` to the front-matter of
      docs/project/plans/2026-09-09-omp-hngh-integration.plan.md (depends on
      step 2 landing).
      Executed 2026-09-12T18:35Z: front-matter now carries priority=high;
      suite test test-plan-priority-selector.sh green rc=0 (all three
      selector cases pass), demonstrating the selector would pick it as
      slot 0 despite filename order.
      Verification: front-matter carries the key; the suite test from step 2
      demonstrates the selector would pick it as slot 0 despite filename order.
- [x] 4. Throughput evidence review. From the last 7 days of beat results
      (overnight results logs, breadcrumb lines, sessions/day vs
      MAX_SESSIONS_DAY), measure: beats/day, slot utilization, degraded-session
      rate at each FF_SPEED tier. Only if the degraded rate is flat while
      slots go unused, draft a cadence-param or ceiling adjustment with the
      numbers, committed through the normal gate with its own test. No blind
      bumps: the speed ladder exists to protect against degraded cascades.
      Verification: analysis note in docs/research/ with the measured numbers;
      any tuning change ships with a test; if data does not support a change,
      the note says so and no code changes.
      Executed 2026-09-12T22:02Z: note docs/research/2026-09-12-throughput-evidence-review.md;
      23 beats / 43 sessions 2026-09-09..12 (aggregate crumbs only; the
      09-05..08 window is pre-format-drift), non-ok 18/43=42%, degraded
      22% at speed 1 vs 6-11% at speeds 2-3 — NO-GO: degraded rate not flat,
      no tuning change, the ladder demotion is the safety mechanism working.
      Gate-flap (step 5) named as the real lever.
- [x] 5. Gate-evaluation isolation under parallel beats (failing test
      first). Evidence: 2026-09-09 kernel-gate-red-rc2 and
      automation-gate-red-rc2 blocks at 14:01-19:01Z while isolated
      `make test` runs pass rc=0 twice (2855 checks); the flap is
      load-correlated — 3 parallel delegated sessions compiling SBCL
      on the same host interfere with the acceptance gate's
      subprocess runs, plan-blocking everything for whole beats.
      Change: serialize gate evaluation against beat sessions — e.g.
      take the existing flock before running the gate inside
      accept-plans.py, or shed to 2 parallel slots while a gate
      evaluation runs; keep the 300s subprocess cap (already lowered
      from 600s). Test the serialization seam in the automation suite
      before the behavior change.
      Verification: suite test covers gate-under-concurrency
      serialization; the acceptance log stops filing gate-red-rc2 on
      a green gate across a full parallel beat; `make test` green.

      Executed 2026-09-13T00:45Z: accept-plans.py holds an exclusive
      flock (hngh-gate.lock under TMPDIR, ACCEPT_GATE_LOCK overrides)
      across both repo gates; a busy lock is a loud skip -- alert row
      (overnight:plan-accept-gate:busy), blocked <slug> gate-lock-busy
      notes, plans untouched, next tick re-evaluates. Red-first suite
      cases in tests/test-plan-acceptance.py: concurrent gate runs never
      interleave (the pre-fix log showed start,start,end,end), busy lock
      blocks loudly, free lock keeps the normal accept path. automation
      make test green; commit ec22664. The isolation guarantees
      serialization at the seam; the acceptance-log side of the
      verification (no gate-red-rc2 across a full parallel beat) is
      observable only in production and is verified by the next
      beats' logs.

## Execution notes

- Steps 1 and 2 are independent; 3 depends on 2; 4 is independent and
  evidence-gated.
- The sweep (step 1) is the big lever: parallel slots currently spend beats on
  plans whose premise may already be landed or obsolete. Do it first.
- Guardrail inherited from the operator directive: optimization must not
  reduce safety — the fail-first pacing, session ceiling, and certificate
  gates stay intact; only ordering and hygiene change.
