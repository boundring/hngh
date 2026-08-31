<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-08-31 — overnight continuity

Slim follow-on wave in the 24/7 continuous cycle so the plan queue
does not run out (foldback lesson 1: the plan queue is the throughput
governor — 40h+ of green gates produced nothing once no accepted plan
remained). Runs after the 2026-08-30 overnight-continuity plan
(executed 2026-08-31); same authorization and autonomy rules: operator
away, pre-authorized normal-risk development; critical-class parks
with operator-facing alerts; hngh kernel src/, tests/, Makefile,
hngh.asd changes are forbidden to machine sessions — park them.

Carried evidence: unread report-queue alerts grew 486 → 499 → 514
across the last three wakes (docs/records/2026-08-30-overnight-
continuity-plan.md, "Not established") — monotonic, never drained.
The alert→plan-candidate router tick is design-complete: the routing
doc's "Outcome tracking without kernel changes (2026-08-31)" section
is field-complete (six fields; fields 3–5 and the parked/refused rows
verified in running code; `routed-from`, `routed-at`, and the
duplicate-skip pair stated as Not established — contracts, not
behavior). Its implementation is this plan's first grow beat, on the
hngh-automation side where commits are free.

Foldback lesson from the 20:00Z → 21:00Z wake pair: the 20:00Z beat
died rc=124 at its 30m kill 14 seconds after its ceremony commit,
before ticking the plan file, and the 21:00Z wake had to re-derive
executed-but-unticked steps from the ledger. Every ceremony in this
plan ticks its steps inside the ceremony that completes them, and
every step's work sits well inside the 30m beat kill.

Sources: docs/project/plans/2026-08-30-overnight-continuity.plan.md
(the executed prior wave; this plan copies its structure), its
execution record docs/records/2026-08-30-overnight-continuity-plan.md
(the alert-count growth), docs/project/queue.md (rotation rows:
publication-lines-contract done "rotated 2026-08-31"; wake-mutation-
lane and dss-e-export still parked; the operator-owned ## Next
pointer; ## Scale; ## ETA), docs/project/backlog.md (night-agent plan
authoring, alert→plan-candidate routing, router-side re-arm pre-check,
documentation-sync, ebook-longform, public-surface, royalty-pipeline,
funding-rails, node-lattice, device-fleet, config-manager),
docs/project/roadmap.md (Now + consolidated route), docs/project/
master-plan.md §4 (research↔design alternation law and the research
backlog), docs/research/2026-08-30-alert-to-work-routing-patterns-
closing-the-self-observation-loop.md (especially "Outcome tracking
without kernel changes (2026-08-31)"), docs/project/lessons-2026-08-30.md
and docs/records/2026-08-30-lessons-and-foldback.md (foldback
lessons), and the acceptance machinery this contract must satisfy:
~/Projects/etc/hngh-automation/scripts/accept-plans.py and
~/Projects/etc/hngh-automation/tests/test-plan-acceptance.py.

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
- wake-mutation-lane (queue ## Next): its smallest useful outcome is a
  `:wake-mutation` action in the kernel mutation vocabulary — kernel
  src/. Parks.
- dss-e-export: YAGNI until an interop consumer exists. Parks.
- Remote GLM budget leg: operator-only token file. Parks.
- systemd unit state, provider/credential config, secrets:
  operator-owned. Parks.
- Routed-outcome dashboard panels (routing doc "Not established"
  item): whether panels are wanted is an operator decision. Parks.
- buddy-summoned-not-nagging, handoff-brief-schema,
  steer-vs-die-threshold: already crystallized in docs/research/ —
  do not redo them.

## Steps

- [ ] 1. Gate baseline: `make test` in this repo (record the check
      count) and `make test` in hngh-automation (exit 0). No landing
      happens on any other step until both are green.
      Verification: both commands exit 0; check counts noted in the
      execution record.

- [ ] 2. GROW BEAT (normal-risk, hngh-automation only — commits there
      are free, no ceremony): implement the alert→plan-candidate
      router tick priced by the routing doc's "Outcome tracking
      without kernel changes (2026-08-31)" section. Minimum scope
      inside one beat: (a) the router-side pre-check before any
      `report-queue --add` — consult plan state with the same two
      greps the selector uses (status=accepted front-matter; an
      unchecked `- [ ]` step); when the identity's named step is
      closed, skip the add and file exactly one observable pair: a
      STATE.md breadcrumb `router | duplicate-skip | <identity> step
      already closed` plus a deduped alert row with identity
      `router:dup-skip:<identity>` (window 86400) — this demonstrates
      router-rearm-precheck's parked "one closed-step re-fire is
      demonstrably skipped" requirement; (b) when filing a routed
      candidate, tag `routed-from=<identity>` in the plan front-matter
      (both parsers tolerate a trailing attribute: accept-plans.py:32-33,
      jobs/plan-feed.py:21-22) and file the `routed-at` reports.md row
      with identity `router:routed:<slug>[:<step-N>]`; (c) a
      regression test in hngh-automation tests/ covering the skip
      decision and the tagged front-matter. If the full tick does not
      fit the beat, land (a) and record the remainder honestly.
      Verification: `make test` in hngh-automation exit 0 including
      the new test; a tagged fixture plan round-trips through
      `accept-plans.py` (DRY_RUN=1) and `jobs/plan-feed.py` without
      parse error — closing the doc's Not-established round-trip item;
      the duplicate-skip pair (breadcrumb + alert row) is observable
      after a simulated closed-step re-fire.

- [ ] 3. RESEARCH BEAT (never code): crystallize the next master-plan
      §4 research-backlog candidate in order — self-hosting prior art
      (buddy summoned-not-nagging was crystallized 2026-08-31,
      handoff-brief-schema and steer-vs-die-threshold 2026-08-30; do
      not redo them). One doc under docs/research/ with a Grounding
      section listing verified repo paths (`test -f` each) and
      explicit "not established" framing where evidence is thin — the
      hallucinated source line is the named anti-pattern from the
      2026-08-30 lessons. If self-hosting prior art is already
      crystallized by execution time, take honest gamification
      mechanics (next uncrystallized §4 candidate) instead.
      Verification: doc exists under docs/research/; Grounding paths
      verified with `test -f`; kernel `make test` green.

- [ ] 4. GROW BEAT (normal-risk): batched hngh docs ceremony — land
      the step-3 research doc (plus any uncommitted kernel docs
      stragglers) in ONE certificate ceremony through the full
      governance loop (real evidence → real model review →
      ten-principle verdict → certificate → mutation) with kernel
      `make test` green immediately before issue-cert; no src/ files
      in candidate paths. Tick steps 2–4 in this plan file inside the
      ceremony that completes them (the rc=124 lesson). Automation-
      side artifacts from step 2 are already committed free and ride
      no ceremony.
      Verification: one ceremony commit; `git show --stat` matches the
      intended list; `make test` green before issue-cert; plan-file
      ticks for steps 2–4 present in the same ceremony; push to origin
      succeeds or is recorded as an alert row.

- [ ] 5. Wrap: append the cycle's outcomes to
      docs/project/lessons-2026-08-31.md (open it if absent), journal
      update under docs/journal/, queue/backlog sync (including noting
      step 2's duplicate-skip demonstration against the
      router-rearm-precheck row), and author the NEXT slim follow-on
      plan at docs/project/plans/2026-09-01-overnight-continuity.plan.md
      (same contract: exact header, first-step gate baseline, strict
      grow↔research alternation, ≥3 runnable steps each with a
      Verification line, final step authors the next plan) so the
      queue never runs empty — the plan is the machine's supply line.
      Kernel-side wrap artifacts land by certificate ceremony with
      `make test` green; automation-side artifacts commit free. Tick
      this step inside the ceremony/commit that completes it.
      Verification: next-day plan file exists with
      status=proposed risk=normal accepted=- and ≥3 runnable steps
      each with a Verification line; lessons and journal files exist;
      queue rows updated; `make test` green.

## Verification summary

- Kernel gate `make test` green before every hngh ceremony;
  automation gate green before any plain commit; strict grow↔research
  alternation; every step ≤ ~60m wall with its own Verification line;
  critical-class parks; every completing ceremony ticks its steps
  inside the same ceremony (the rc=124 lesson).
- Plan-supply law: this plan exists so foldback lesson 1 cannot
  repeat; its final step authors the next plan.

## Autonomy rule

Governance is the only barrier: certificates and green gates, never
human approval. No step waits for an operator. hngh-automation
commits are free — plain git commit once its `make test` is green.
hngh landings happen ONLY through the certificate ceremony with kernel
`make test` green immediately before issue-cert. The Parked list above
is absolute for machine sessions (kernel src/, tests/, Makefile,
hngh.asd; wake-mutation-lane; dss-e-export; the remote GLM token file;
systemd/provider/credential state and secrets). Beats are killed at
30m — keep each wake's work well inside that. If a step is blocked,
write the blocker into this plan file as an alert row and move on to
the next step; never idle waiting for a human.
