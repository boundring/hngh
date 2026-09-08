<!-- plan: status=proposed risk=normal accepted=- -->
# 2026-09-09 — overnight continuity

Slim follow-on wave in the 24/7 continuous cycle so the plan queue
does not run out (foldback lesson 1: the plan queue is the throughput
governor). Runs after the 2026-09-02-overnight-continuity plan
(executed 2026-09-08T00:30Z–01:00Z in one wake: steps 1–4 in ceremony
da3d441, step-5 wrap in the same wake's wrap ceremony); same
authorization and autonomy rules: operator away, pre-authorized
normal-risk development; critical-class parks with operator-facing
alerts; hngh kernel src/, tests/, Makefile, hngh.asd changes are
forbidden to machine sessions — park them.

Carried state: the ebook-book-inputs research candidate is
crystallized (docs/research/2026-09-08-ebook-book-inputs.md, ceremony
da3d441) and its priced decision names the next grow beat: the
per-book metadata input for scripts/generate-publication (selection
`--chapters` already landed; metadata is the smallest fully-missing
input). The next queued research line is ctx-structured-briefs
(research-lines.tsv, planned; builds on the crystallized
ctx-compaction-strategies and ctx-retrieval-vs-repetition lines —
per-beat digests live in hngh-automation
digest/RESEARCH-BEAT-2026-09-07-ctx-compaction-strategies.md and
digest/RESEARCH-BEAT-2026-09-08-ctx-retrieval-vs-repetition.md).
Two open items ride as context, not steps: the kernel research
artifact 2026-09-08-ctx-retrieval-vs-repetition.md is
transcript-corrupted and awaits rewrite by its owning line (do not
land it as-is), and the slow-unit alert for dropin:33-research-beat.sh
(wall=147.7s median=0.0s) is with the router, which owns alert
routing.

Beat-sizing law (lessons-2026-08-31, 00:00Z wake): size every step
to minutes; a batched docs ceremony is one ceremony-drive invocation
(~40s) — a step may host its own ceremony and still fit well inside
the 30m kill. Every step ticks itself inside the commit/ceremony
that completes it (the rc=124 lesson). A step priced above one
wake's budget (the metadata input is 30–45m class) may land across
two wakes: implement + verify in one, ceremony in the next — the
plan file's tick text carries the state.

## Parked

What the next author must NOT do:

- hngh kernel src/, tests/, Makefile, hngh.asd — forbidden to machine
  sessions (hard session guardrail). Any item whose smallest useful
  outcome lives there parks with an operator-facing alert. This
  includes tests/scripts/ — a grow beat lands its script change and
  parks the test edit with an alert row naming exactly the file and
  what the test must assert.
- wake-mutation-lane (queue ## Next): smallest useful outcome is a
  `:wake-mutation` kernel mutation-vocabulary action — kernel src/.
  Parks.
- dss-e-export: YAGNI until an interop consumer exists. Parks.
- key-rotation-freshness, credential/provider/systemd state, secrets:
  operator-owned. Parks.
- Remote GLM budget leg: operator-only token file. Parks.
- Routed-outcome dashboard panels: operator decision. Parks.
- Gamification-narrative work: per master-plan §4, narrative never
  enters governance — do not build narrative features.
- Concurrent-lane files: the automation-subtree-import lane was live
  in the kernel tree on 2026-09-08 (systemd unit edits in flight).
  Ceremony manifests are explicit file lists; never add another
  lane's in-flight files to a manifest.

## Steps

- [ ] 1. Gate baseline: `make test` in this repo (record the check
      count) and `make test` in hngh-automation (exit 0). No landing
      happens on any other step until both are green.
      Verification: both commands exit 0; check counts noted in the
      tick and carried to the execution record.

- [ ] 2. GROW BEAT (normal-risk): carry the ebook-book-inputs priced
      decision — the per-book metadata input for
      scripts/generate-publication (option B first per
      docs/research/2026-09-08-ebook-book-inputs.md: an inputtable
      title/author/identifier/keywords set replacing the hard-coded
      OPF/NCX metadata). Implement in scripts/ only; prove with a
      real `generate-publication --ebook` run showing the input
      honored (run it, capture the OPF/NCX lines in the tick). If
      the smallest useful outcome requires a tests/ or Makefile
      edit, land the script change and park the test edit with an
      operator-facing alert row naming the file and the assertion.
      If the prior wake already implemented it, verify + land only.
      Verification: kernel `make test` green; one ceremony commit
      with the script change (or the step parked with an alert row);
      a real run's metadata lines quoted in the tick.

- [ ] 3. RESEARCH BEAT (never code): ctx-structured-briefs — which
      structured brief fields measurably cut reorientation tokens
      after a session death, and which fields are noise
      (research-lines.tsv row). One doc under docs/research/ with a
      Grounding section listing verified repo paths (`test -f` each)
      and explicit "not established" framing where evidence is thin
      — the hallucinated source line is the named anti-pattern.
      Build on the crystallized ctx-compaction-strategies and
      ctx-retrieval-vs-repetition material (hngh-automation digest
      beats); do not redo them. While in the lane: if the corrupted
      kernel artifact docs/research/
      2026-09-08-ctx-retrieval-vs-repetition.md is still untracked,
      rewrite it clean from its digest material in the same beat (it
      is this lane's own subject).
      Verification: doc exists under docs/research/; Grounding paths
      verified with `test -f`; kernel `make test` green.

- [ ] 4. GROW BEAT (normal-risk): batched hngh docs ceremony — land
      the step-3 research doc (and the rewritten ctx artifact, if
      rewritten), the routed-stub plan ticks, and any uncommitted
      kernel docs stragglers in ONE certificate ceremony via
      scripts/ceremony-drive (fresh /tmp store; pre-flight candidates
      against the public-content gate first — the 2026-09-08 wake
      found two historical reports.md rows tripping the gate: a
      credential-shaped "name-token: word" row and an absolute
      /home path; pre-flight renders rows gate-safe, ~/-form for
      paths, and breaks token:value shapes) with kernel `make test`
      green in the same beat; no src/ files in candidate paths.
      Tick steps 2–4 inside the same ceremony (the rc=124 lesson).
      Verification: one ceremony commit; `git show --stat` matches
      the intended list; push to origin succeeds or is recorded as
      an alert row.

- [ ] 5. Wrap: append the cycle's outcomes to
      docs/project/lessons-2026-09-09.md (open it if absent),
      journal update under docs/journal/, queue/backlog sync
      (ebook-book-inputs row and ctx research-line status), and
      author the NEXT slim follow-on plan at docs/project/plans/
      2026-09-10-overnight-continuity.plan.md (same contract: exact
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
  a wake can host several; steps priced above one wake may land
  across two wakes with the tick text carrying the state.
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
remote GLM token file; concurrent-lane in-flight files). Beats are
killed at 30m — keep each wake's work well inside that. If a step is
blocked, write the blocker into this plan file as an alert row and
move on to the next step; never idle waiting for a human.
