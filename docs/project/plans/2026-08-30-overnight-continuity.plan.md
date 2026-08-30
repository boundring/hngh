<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-08-30 — overnight continuity

Slim follow-on wave so the plan queue does not run out overnight
(foldback lesson 1: the plan queue is the throughput governor — 40h+ of
green gates produced nothing once no accepted plan remained). Runs
after the 2026-08-30 evening plan; same authorization and autonomy
rules as that plan (operator away, pre-authorized normal-risk
development; critical-class parks with operator-facing alerts; hngh
kernel src/, tests/, Makefile, hngh.asd changes forbidden to machine
sessions — park them).

Sources: docs/records/2026-08-30-lessons-and-foldback.md (all four
lessons; this plan is the lesson-1 response), docs/project/roadmap.md
Next 1–5, docs/project/queue.md rotation state and Scale section,
docs/project/backlog.md rows (night-agent plan authoring,
alert→plan-candidate routing, documentation-sync, ebook-longform,
public-surface, royalty-pipeline, funding-rails, node-lattice,
device-fleet, config-manager), docs/project/master-plan.md §4
alternation, docs/project/roguelike-agentic.md, the three 2026-08-30
research lines, and the operator's explainer suite
~/Projects/etc/20260830 (00…09 + README + CHANGELOG;
audited via 2026-08-30-lessons-and-foldback — framing material only).

Paced-cadence contract: beats ≤ ~60m wall, strict grow↔research
alternation, every step self-verifying and executable by a bounded
delegated session with no human present. If this plan executes to
empty, the final step authors the NEXT follow-on candidate list
(parked section below) so the queue refills.

Parked (follow-on candidates for the next plan's author):
- Any remaining evening-plan research docs still uncommitted → first
  batched docs ceremony here.
- Kernel-side stage-4 work (config-manager governed lanes, package
  inventory → governed update lanes): forbidden to machine sessions.
  Parks.
- Remote GLM budget leg: operator-only token file. Parks.
- Wake-mutation-lane rotation (queue Next): rotation-scale and
  certificate-ready only if a full session can be carved; otherwise
  stays with the machine's rotation mechanics.
- Alert→plan-candidate routing implementation: blocked until the
  routing-table design doc (evening plan step 7) is read and priced.

## Steps

- [ ] 1. Gate baseline: `make test` in this repo (record check count)
      and `make test` in hngh-automation (exit 0). No landing happens
      on any other step until both are green.
      Verification: both commands exit 0; check count noted in the
      execution record.

- [ ] 2. RESEARCH BEAT (never code): crystallize ONE line from
      docs/research/ accumulated per-beat material (hngh-automation
      digest/RESEARCH-BEAT-* material not yet crystallized), with a
      Grounding section listing verified repo paths and "not
      established" framing for thin evidence (the delegation-lane
      line's model; today's two hallucinated lines are the named
      anti-pattern). Candidates in master-plan §4 research-backlog
      order: buddy summoned-not-nagging menu learning, self-hosting
      prior art, honest gamification mechanics.
      Verification: doc exists under docs/research/; Grounding paths
      verified with `test -f`; `make test` green.

- [ ] 3. GROW BEAT (normal-risk): rotate ONE queue.md item that is
      rotation-scale and certificate-loop ready, via
      scripts/rotate-queue, committing its own candidate through the
      full governance loop (per queue.md Scheduling: real evidence →
      real model review → ten-principle verdict → certificate →
      mutation). Candidates grounded in queue.md: wake-mutation-lane
      (Next, backlog boundary proposal) or dss-e-export (backlog
      entry). If no item is rotation-scale and ceremony-ready, run
      `scripts/rotate-queue` anyway to advance the state honestly and
      record that no candidate met the bar.
      Verification: queue.md row transitions (queued → active → done)
      in the diff; the rotated item's candidate commit passes
      `make test`; or the honest no-candidate note is recorded.

- [ ] 4. RESEARCH BEAT (never code): crystallize any SECOND accumulated
      line from the overnight research-beat materials, same Grounding
      contract as step 2. If nothing accumulated, this beat extends
      the evening plan's routing-table design (step 7) with the
      outcome-tracking fields hngh-automation can capture without
      kernel changes — docs only.
      Verification: doc exists with Grounding section of verified
      paths; `make test` green.

- [ ] 5. Batched docs ceremony: land all uncommitted research/docs
      artifacts from this plan (and any stragglers from the evening
      plan) in ONE certificate ceremony with `make test` green
      immediately before. No src/ files in candidate paths.
      Verification: one ceremony commit, git show --stat matches the
      intended list; `make test` green before issue-cert; push to
      origin succeeds or is recorded as an alert row.

- [ ] 6. Wrap: append the night's outcomes to
      docs/project/lessons-2026-08-30.md (or open
      docs/project/lessons-2026-08-31.md after midnight UTC), journal
      update, queue/backlog sync, and author the NEXT slim follow-on
      plan (docs/project/plans/2026-08-31-overnight-continuity.plan.md,
      same contract) so the queue never runs empty — the plan is the
      machine's supply line.
      Verification: next-day plan file exists with status=proposed
      risk=normal and ≥ 3 runnable steps; journal and queue rows
      updated; `make test` green.

## Verification summary

- Kernel gate `make test` green before every hngh ceremony; automation
  gate green before any plain commit; alternating grow↔research; every
  step ≤ ~60m wall with its own verification; critical-class parks.
- Plan-supply law: this plan exists so foldback lesson 1 cannot repeat;
  its final step authors the next plan.
