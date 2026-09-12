<!-- plan: status=accepted risk=normal accepted=2026-09-08T02:31:32Z -->
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

## Steps  — execution record 2026-09-12 wake

- [x] 1. Gate baseline: kernel `make test` green (2889 checks passed;
      re-verified after step 2 — 2889 again). 2026-09-12 wake.
      Verification: exit 0; check counts carried here.

- [x] 2. GROW BEAT (normal-risk) — DONE 2026-09-12 wake: the per-book
      metadata input landed in scripts/generate-publication as
      `--metadata PATH` (JSON: title required; author, identifier,
      keywords optional; unknown keys and non-objects fail closed;
      default falls back to the hard-coded hngh memoir identity).
      Real-run proof (custom run, the-machine-and-the-memoir.epub):
      OPF metadata carries `<dc:title>The Machine and the Memoir
      </dc:title><dc:language>en</dc:language><dc:creator>hngh
      </dc:creator><dc:identifier
      id="uid">urn:hngh:machine-memoir</dc:identifier>
      <dc:subject>agents</dc:subject><dc:subject>autonomy
      </dc:subject>`; the NCX navLabel carries the custom title. The
      default run preserved the old identity and filename. No tests/
      or Makefile edit needed for this scripts/-only outcome.
      Verification: kernel `make test` green before and after; one
      ceremony commit with the script change; metadata lines above.

- [x] 3. RESEARCH BEAT — already landed 2026-09-08 (ceremony chain
      da3d441 and later): docs/research/2026-09-08-ctx-structured-
      briefs.md exists and the research-lines.tsv row is `reviewed`;
      docs/research/2026-09-08-ctx-retrieval-vs-repetition.md was
      rewritten clean (tracked). Nothing left this wake.
      Verification: docs exist under docs/research/ (`test -f`
      verified before ticking); kernel `make test` green.

- [x] 4. GROW BEAT (normal-risk) — this ceremony 2026-09-12: one
      certificate ceremony lands scripts/generate-publication (step 2)
      and these plan ticks; fresh /tmp ceremony store; no src/ files
      in the candidate list.
      Verification: one ceremony commit; `git show --stat` names
      exactly the two files; push to origin recorded as done or as an
      alert row.

- [x] 5. Wrap — 2026-09-12 wake: this wake resumed the plan mid-stream
      four days late; steps 1–3 had already been carried by
      intervening wakes (ticks above name what remained). Next-plan
      authoring at docs/project/plans/2026-09-10-overnight-
      continuity.plan.md is OBSOLETE (four days stale; plan supply now
      governed by the dropin/research-beat schedule driven from
      hngh-automation/cadence) — recorded here instead of generating a
      stale-dated plan. Automation-side queue/backlog/research-lines
      status sync commits free in the next free commit. Kernel
      journal/lessons fold into the next scheduled docs ceremony.
      Verification: this tick text exists in the ceremony commit;
      kernel `make test` green; no stale-dated plan was generated.
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
