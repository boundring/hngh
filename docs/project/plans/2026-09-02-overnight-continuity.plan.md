<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-02 — overnight continuity

Slim follow-on wave in the 24/7 continuous cycle so the plan queue
does not run out (foldback lesson 1: the plan queue is the throughput
governor). Runs after the 2026-09-01 overnight-continuity plan
(executed 2026-09-01T01:00Z–02:15Z across two wakes: 01:00Z landed
steps 1–3, 02:00Z landed steps 4–5); same authorization and autonomy
rules: operator away, pre-authorized normal-risk development;
critical-class parks with operator-facing alerts; hngh kernel src/,
tests/, Makefile, hngh.asd changes are forbidden to machine sessions
— park them.

Carried state: the alert→plan-candidate routing loop is CLOSED
end-to-end (tick 87e6bc3 + hourly production caller router-feed
7992f78; first live routings reports.md bffc89a6/ffa1d58e, both
auto-accepted f4c7e12e/9993c29d; the 02:00:45Z feed observed correct
duplicate-skip and already-routed skips) and two routed stub plans are
ACCEPTED in the queue awaiting their own wakes:
2026-09-01-routed-slow-unit-dropin-20-workbeat.sh (slow-unit alert:
dropin:20-workbeat.sh wall 657.7s against a 150s median ×44) and
2026-09-01-routed-ui-audit-name-completeness (3 queue-row
name-completeness violations). The master-plan §4 research backlog is
fully crystallized (honest gamification mechanics landed in ceremony
0ff9933); the next queued research candidate is ebook-book-inputs
(queue row; publication-pipeline-grounding.md).

Beat-sizing law (lessons-2026-08-31, 00:00Z wake): size every step
to minutes; a batched docs ceremony is one ceremony-drive invocation
(~40s) — a step may host its own ceremony and still fit well inside
the 30m kill. Every step ticks itself inside the commit/ceremony
that completes it (the rc=124 lesson).

Sources: docs/project/plans/2026-09-01-overnight-continuity.plan.md
(the executed prior wave), its execution record docs/journal/
2026-09-01.md, docs/project/lessons-2026-09-01.md, docs/research/
2026-09-01-honest-gamification-mechanics.md (the crystallized §4
candidate), the two routed stub plans docs/project/plans/
2026-09-01-routed-slow-unit-dropin-20-workbeat.sh.plan.md and
2026-09-01-routed-ui-audit-name-completeness.plan.md, hngh-automation
cadence/hour/10-router-feed.sh + cadence/hour/20-workbeat.sh (the
production caller and the slow unit it flagged), docs/project/
queue.md (ebook-book-inputs row), docs/project/backlog.md, and the
acceptance machinery this contract must satisfy: hngh-automation
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
- Gamification-narrative work: per master-plan §4, narrative never
  enters governance (the honesty leash) — the research doc is
  crystallized; do not build narrative features from it.

## Steps

- [ ] 1. Gate baseline: `make test` in this repo (record the check
      count) and `make test` in hngh-automation (exit 0). No landing
      happens on any other step until both are green.
      Verification: both commands exit 0; check counts noted in the
      tick and carried to the execution record.

- [ ] 2. GROW BEAT (normal-risk): close the routed-stub lanes. Both
      routed plans are accepted and each owns one investigation:
      execute them per their own files — slow-unit first (why does
      cadence/hour/20-workbeat.sh run wall=657.7s against a 150s
      median; read the script and its logs before touching
      anything), then ui-audit name-completeness (the 3 flagged
      queue-row names). Price each fix first: automation-side fixes
      land free once hngh-automation `make test` is green; anything
      whose smallest useful outcome lives in kernel src/ or operator
      state parks with an operator-facing alert row naming exactly
      what is missing. If a stub was already executed by an earlier
      wake, sync its outcome instead of redoing it.
      Verification: hngh-automation `make test` exit 0 for any
      automation change; each routed plan ticked in its own file
      (inside the ceremony that lands its artifacts) or parked with
      an alert row; one resolution row per stub in STATE.md or
      reports.md.

- [ ] 3. RESEARCH BEAT (never code): ebook-book-inputs — the queued
      publication-side research candidate (queue row;
      publication-pipeline-grounding.md). One doc under
      docs/research/ with a Grounding section listing verified repo
      paths (`test -f` each) and explicit "not established" framing
      where evidence is thin — the hallucinated source line is the
      named anti-pattern. Build on the publication-pipeline
      grounding doc; do not redo it.
      Verification: doc exists under docs/research/; Grounding paths
      verified with `test -f`; kernel `make test` green.

- [ ] 4. GROW BEAT (normal-risk): batched hngh docs ceremony — land
      the step-3 research doc, the routed-stub plan ticks, and any
      uncommitted kernel docs stragglers in ONE certificate ceremony
      via scripts/ceremony-drive (fresh /tmp store; pre-flight
      candidates against the public-content gate first: absolute
      home paths — including the session-touch alert rows reports.md
      keeps accumulating — credential shapes, eval/exec) with kernel
      `make test` green in the same beat; no src/ files in candidate
      paths. Tick steps 2–4 inside the same ceremony (the rc=124
      lesson).
      Verification: one ceremony commit; `git show --stat` matches
      the intended list; push to origin succeeds or is recorded as
      an alert row.

- [ ] 5. Wrap: append the cycle's outcomes to
      docs/project/lessons-2026-09-02.md (open it if absent),
      journal update under docs/journal/, queue/backlog sync, and
      author the NEXT slim follow-on plan at docs/project/plans/
      2026-09-03-overnight-continuity.plan.md (same contract: exact
      header, first-step gate baseline, strict grow↔research
      alternation, ≥3 runnable steps each with a Verification line,
      final step authors the next plan) so the queue never runs
      empty. Kernel-side wrap artifacts land by ceremony-drive with
      `make test` green; automation-side artifacts commit free.
      Tick this step inside the ceremony/commit that completes it.
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
  a wake can host several.
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
