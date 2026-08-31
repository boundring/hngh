<!-- plan: status=executed risk=normal accepted=2026-08-31T18:31:17Z -->
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

- [x] 1. Gate baseline: `make test` in this repo (record check count)
      and `make test` in hngh-automation (exit 0). No landing happens
      on any other step until both are green.
      Verification: both commands exit 0; check count noted in the
      execution record.
      Executed 2026-08-31T20:01Z: kernel 2,855 checks passed (exit 0,
      wall 35s); automation 10 tests OK + lint-identifiers clean
      (exit 0).

- [x] 2. RESEARCH BEAT (never code): crystallize ONE line from
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
      Executed 2026-08-31T20:19Z: docs/research/2026-08-31-buddy-
      summoned-not-nagging-menu-learning.md authored (top §4 backlog
      candidate; 13 repo paths test -f verified; 5 prior-art references
      visited; explicit Not established section — no menu implementation
      exists, scripts/osd-operative.qml has no menu code). No
      un-crystallized digest material existed: research-lines.tsv had
      all 22 lines crystallized, so the beat took the §4 candidate
      branch. Gate green (2855 checks) post-authoring.

- [x] 3. GROW BEAT (normal-risk): rotate ONE queue.md item that is
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
      Candidate disposition 2026-08-31T20:10Z: wake-mutation-lane parks
      (its smallest useful outcome is a `:wake-mutation` action in the
      mutation vocabulary — kernel src/, forbidden to machine sessions
      this session); dss-e-export parks (YAGNI-gated on an interop
      consumer that does not exist). Rotating publication-lines-contract
      instead: queued 2026-08-31, priced decision A
      (ebook-selection-manifest) in
      docs/research/2026-08-30-publication-pipeline-grounding.md §4,
      touches scripts/ + docs only. Rides with it: one-line fix to the
      hardcoded `rotated 2026-08-25` evidence date in
      scripts/rotate-queue (evidence-first; the only prior use was on
      that literal date).
      Executed 2026-08-31T20:27Z: rotation complete via scripts/
      rotate-queue --route auto (the first --route exercise ever — it
      exposed and the rotation carries fixes for two latent
      route-reviewer bugs: uiop:run-program returns values stdout,
      stderr, exit-code, and parse-namestring of HOME parses the user
      as a file name). Real model review: status complete, findings 0.
      Candidate 5be9d4c (content hash a569ab0d…) — queue.md row
      queued→done "rotated 2026-08-31" (honest date, fix working),
      generate-publication --chapters (decision A), rotate-queue fixes;
      pushed 0a209ba..5be9d4c; make test green post-commit (2855
      checks); verify-candidate pre-flight :passed.

- [x] 4. RESEARCH BEAT (never code): crystallize any SECOND accumulated
      line from the overnight research-beat materials, same Grounding
      contract as step 2. If nothing accumulated, this beat extends
      the evening plan's routing-table design (step 7) with the
      outcome-tracking fields hngh-automation can capture without
      kernel changes — docs only.
      Verification: doc exists with Grounding section of verified
      paths; `make test` green.
      Executed 2026-08-31T20:31Z: nothing accumulated (all digest lines
      crystallized), so this beat took the routing-table extension
      branch: +171 lines, section "Outcome tracking without kernel
      changes (2026-08-31)" in docs/research/2026-08-30-alert-to-work-
      routing-patterns-closing-the-self-observation-loop.md — six
      fields (routed-from, routed-at, first-attempt-at, closed-at,
      outcome class, duplicate-skip event), each grounded in verified
      automation call sites; contracts only, no router tick exists
      (stated as Not established).

- [x] 5. Batched docs ceremony: land all uncommitted research/docs
      artifacts from this plan (and any stragglers from the evening
      plan) in ONE certificate ceremony with `make test` green
      immediately before. No src/ files in candidate paths.
      Verification: one ceremony commit, git show --stat matches the
      intended list; `make test` green before issue-cert; push to
      origin succeeds or is recorded as an alert row.
      Executed 2026-08-31T20:30Z: ceremony 11de68c (candidate
      87373ae7…) landed exactly 9 docs files — this plan's step-2
      research doc (buddy-summoned-not-nagging-menu-learning) and
      step-4 routing-table outcome-tracking extension (171 lines),
      the six evening-plan research stragglers (gantt-legibility,
      web-search-reference-capture, self-funding-paths, tech-tree-UX,
      unattended-plan-authoring-safety, wiki-viewer-QoL), plus the
      plan-file step 1–4 notes. No src/ in candidate paths; make test
      green pre-cert (2,855 checks); main == origin/main (pushed).
      The 20:00Z beat hit its 30m kill (rc=124) 14s after the commit,
      before this tick — recorded here by the 21:00Z wake, whose
      lesson ("tick the step inside the ceremony that completes it")
      lands in lessons-2026-08-31.

- [x] 6. Wrap: append the night's outcomes to
      docs/project/lessons-2026-08-30.md (or open
      docs/project/lessons-2026-08-31.md after midnight UTC), journal
      update, queue/backlog sync, and author the NEXT slim follow-on
      plan (docs/project/plans/2026-08-31-overnight-continuity.plan.md,
      same contract) so the queue never runs empty — the plan is
      the machine's supply line.
      Verification: next-day plan file exists with status=proposed
      risk=normal and ≥ 3 runnable steps; journal and queue rows
      updated; `make test` green.
      Executed 2026-08-31T21:15Z by the 21:00Z wake: lessons
      appended to lessons-2026-08-31.md (tick-inside-ceremony
      lesson, beat sizing, alert-ledger 486→499→514 growth); journal
      2026-08-31.md rewritten with the honest day ledger (4 candidate
      commits + this wrap); queue synced — publication-lines-contract
      done (landed in step 3's 5be9d4c), operator-owned `## Next`
      pointer untouched, wake-mutation-lane and dss-e-export stay
      parked per the step-3 dispositions; execution record
      docs/records/2026-08-30-overnight-continuity-plan.md authored;
      next plan 2026-08-31-overnight-continuity.plan.md authored
      (status=proposed risk=normal accepted=-, 5 runnable steps each
      with a Verification line). All wraps, ticks, and the new plan
      land in this ceremony — the tick-inside-ceremony lesson,
      applied. Plan complete: status=executed.

## Verification summary

- Kernel gate `make test` green before every hngh ceremony; automation
  gate green before any plain commit; alternating grow↔research; every
  step ≤ ~60m wall with its own verification; critical-class parks.
- Plan-supply law: this plan exists so foldback lesson 1 cannot repeat;
  its final step authors the next plan.
