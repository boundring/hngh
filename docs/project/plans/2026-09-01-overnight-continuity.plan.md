<!-- plan: status=accepted risk=normal accepted=2026-09-01T00:31:18Z -->
# 2026-09-01 — overnight continuity

Slim follow-on wave in the 24/7 continuous cycle so the plan queue
does not run out (foldback lesson 1: the plan queue is the throughput
governor). Runs after the 2026-08-31 overnight-continuity plan
(executed 2026-09-01T00:00Z–00:30Z, steps 1–5 in one beat); same
authorization and autonomy rules: operator away, pre-authorized
normal-risk development; critical-class parks with operator-facing
alerts; hngh kernel src/, tests/, Makefile, hngh.asd changes are
forbidden to machine sessions — park them.

Carried state: the alert→plan-candidate router tick is landed and
proven (hngh-automation 87e6bc3; router-rearm-precheck done in the
queue) but has NO production caller yet — no job invokes it, so the
routing loop's observation edge is still hand-demonstrated. Wiring
that caller is this plan's first grow beat, automation-side where
commits are free. The §4 research backlog has exactly one
uncrystallized candidate left: honest gamification mechanics.

Beat-sizing law (lessons-2026-08-31, 00:00Z wake): size every step
to minutes; a batched docs ceremony is one ceremony-drive invocation
(~40s) — a step may host its own ceremony and still fit well inside
the 30m kill. Every step ticks itself inside the commit/ceremony
that completes it (the rc=124 lesson).

Sources: docs/project/plans/2026-08-31-overnight-continuity.plan.md
(the executed prior wave; this plan copies its structure), its
execution record docs/journal/2026-09-01.md, docs/project/lessons-
2026-08-31.md (beat-sizing + ceremony-drive lessons),
docs/research/2026-08-30-alert-to-work-routing-patterns-closing-the-
self-observation-loop.md (routing table; F1 the observation edge),
hngh-automation/scripts/router-tick.py + scripts/overnight-cycle.sh
+ jobs/oversight-tick.sh (the tick and its candidate call sites),
docs/project/master-plan.md §4 (honest gamification mechanics — the
last uncrystallized candidate), docs/project/queue.md (queued rows;
router-rearm-precheck done 2026-09-01; ebook-book-inputs next
publication-side), docs/project/backlog.md, and the acceptance
machinery this contract must satisfy: hngh-automation
scripts/accept-plans.py and tests/test-plan-acceptance.py.

Paced-cadence contract: steps ≤ ~60m wall, strict grow↔research
alternation, every step self-verifying and executable by a bounded
delegated session with no human present. Beats are killed at 30m —
keep each wake's work well inside that. If this plan executes to
empty, the final step authors the NEXT follow-on plan so the queue
refills (plan-supply law).

## Parked

What the next author must NOT do:

- hngh kernel src/, tests/, Makefile, hngh.asd — forbidden to machine
  sessions (hard session guardrail). Any item whose smallest useful
  outcome lives there parks with an operator-facing alert.
- wake-mutation-lane (queue ## Next): smallest useful outcome is a
  `:wake-mutation` kernel mutation-vocabulary action — kernel src/.
  Parks.
- dss-e-export: YAGNI until an interop consumer exists. Parks.
- key-rotation-freshness, credential/provider/systemd state, secrets:
  operator-owned. Parks.
- Remote GLM budget leg: operator-only token file. Parks.
- Routed-outcome dashboard panels: whether panels are wanted is an
  operator decision. Parks.
- Gamification-narrative work beyond the research doc: per
  master-plan §4, narrative never enters governance (honesty leash) —
  this plan's research beat is docs-only.

## Steps

- [x] 1. Gate baseline: `make test` in this repo (record the check
      count) and `make test` in hngh-automation (exit 0). No landing
      happens on any other step until both are green.
      Verification: both commands exit 0; check counts noted in the
      tick and carried to the execution record.
      (Done 2026-09-01: kernel 2855 checks, hngh-automation 21 tests
      + identifier lint, both exit 0; counts carried to the journal.)

- [x] 2. GROW BEAT (normal-risk, hngh-automation only — commits
      free, no ceremony): give the router tick its production caller.
      Price the call site first (read jobs/oversight-tick.sh and
      scripts/overnight-cycle.sh): the router tick must be invoked on
      deduplicated alert rows with identities that name routable
      classes, never on operator-owned/critical alert identities
      (those already park inside the tick, but do not feed it noise
      by design). Minimum scope: one invocation point + a hermetic
      test of the wiring + `make test` green. If the honest price
      shows the call site needs kernel changes or systemd unit state,
      park with an operator-facing alert row naming exactly what is
      missing and record the remainder.
      Verification: hngh-automation `make test` exit 0 including the
      wiring test; one observable end-to-end row (a real or
      simulated alert reaching router-tick through the production
      path) in STATE.md or reports.md.

- [x] 3. RESEARCH BEAT (never code): crystallize honest gamification
      mechanics — the last uncrystallized master-plan §4 candidate.
      One doc under docs/research/ with a Grounding section listing
      verified repo paths (`test -f` each) and explicit
      "not established" framing where evidence is thin — the
      hallucinated source line is the named anti-pattern. Anchor the
      honesty leash: narrative renders only from real run fields and
      never enters governance (master-plan §4; docs/research/
      2026-08-11-clean-architecture-roguelike-run-review.md and the
      buddy/menu-learning doc are the in-repo priors to build on —
      do not redo them). If already crystallized by execution time,
      take ebook-book-inputs research (queue row; publication-
      pipeline-grounding.md) instead.
      Verification: doc exists under docs/research/; Grounding paths
      verified with `test -f`; kernel `make test` green.

- [x] 4. GROW BEAT (normal-risk): batched hngh docs ceremony — land
      the step-3 research doc (plus uncommitted kernel docs
      stragglers) in ONE certificate ceremony via scripts/
      ceremony-drive (fresh /tmp store; pre-flight candidates against
      the public-content gate first: absolute home paths, credential
      shapes, eval/exec) with kernel `make test` green in the same
      beat; no src/ files in candidate paths. Tick steps 2–4 inside
      the same ceremony (the rc=124 lesson).
      Verification: one ceremony commit; `git show --stat` matches
      the intended list; push to origin succeeds or is recorded as an
      alert row.

- [ ] 5. Wrap: append the cycle's outcomes to
      docs/project/lessons-2026-09-01.md (open it if absent), journal
      update under docs/journal/, queue/backlog sync (including the
      step-2 caller-wiring outcome against the alert→plan-candidate
      routing row), and author the NEXT slim follow-on plan at
      docs/project/plans/2026-09-02-overnight-continuity.plan.md
      (same contract: exact header, first-step gate baseline, strict
      grow↔research alternation, ≥3 runnable steps each with a
      Verification line, final step authors the next plan) so the
      queue never runs empty. Kernel-side wrap artifacts land by
      ceremony-drive with `make test` green; automation-side
      artifacts commit free. Tick this step inside the ceremony/commit
      that completes it.
      Verification: next-day plan file exists with
      status=proposed risk=normal accepted=- and ≥3 runnable steps
      each with a Verification line; lessons and journal files exist;
      queue rows updated; `make test` green.

## Verification summary

- Kernel gate `make test` green before every hngh ceremony;
  automation gate green before any plain commit; strict grow↔research
  alternation; every step ≤ ~60m wall with its own Verification line;
  critical-class parks; every completing ceremony/commit ticks its
  steps inside itself (the rc=124 lesson); steps sized to minutes so
  a wake can host several (the 00:00Z beat-sizing lesson).
- Plan-supply law: this plan exists so foldback lesson 1 cannot
  repeat; its final step authors the next plan.

## Autonomy rule

Governance is the only barrier: certificates and green gates, never
human approval. No step waits for an operator. hngh-automation
commits are free — plain git commit once its `make test` is green.
hngh landings happen ONLY through the certificate ceremony (one
ceremony-drive invocation for docs batches) with kernel `make test`
green in the same beat. The Parked list above is absolute for machine
sessions (kernel src/, tests/, Makefile, hngh.asd; wake-mutation-lane;
dss-e-export; key-rotation/credential/systemd state and secrets; the
remote GLM token file). Beats are killed at 30m — keep each wake's
work well inside that. If a step is blocked, write the blocker into
this plan file as an alert row and move on to the next step; never
idle waiting for a human.
