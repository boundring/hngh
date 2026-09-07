<!-- plan: status=executed risk=normal accepted=2026-09-01T12:01:27Z routed-from=review:hngh:P1-docs-project-plans-2026-08- -->
# 2026-09-01 — routed candidate

Routed by scripts/router-tick.py from alert identity `review:hngh:P1-docs-project-plans-2026-08-`
at 2026-09-01T10:00:45Z. Alert text: review P0/P1 (hngh): P1: `docs/project/plans/2026-08-31-overnight-continuity.plan.md` step 5 execution note is truncated mid-sentence ("plan supply r"), indicating a failed write or buffer overflow during the plan tick.

## Steps

- [x] Fix the review finding in docs/automation with a named verification
      Verification: the finding's own check passes; `make test` green
      Executed 2026-09-07T06:39Z (this wake — the cycle's delegated
      session for the step): the finding was a phantom from the
      review pipeline, not a defect in this repo. The cited step-5
      note was never truncated: it completes at HEAD ("...plan
      supply refilled before the wake ends", landed by ceremony
      commit 0ff9933, the wrap that ticked the 2026-08-31 plan) and
      no truncated state of that note was ever committed. Root
      cause, reproduced exactly: rebuilding the 2026-09-01T09:06:53Z
      review packet (git log --stat -p over the trailing 36h,
      capped `head -c 60000`) cuts on the "r" of "refilled" —
      hngh-automation cadence/day/04-review-prep.sh byte-capped its
      evidence packet with an unmarked head -c, so the review model
      saw a diff ending mid-sentence and filed it as a failed write.
      The 2026-08-28 twin (alert 622e68f0, "is an un",
      docs/design/logs-page-spec.md) reproduces identically at the
      same cap. Fix: hngh-automation 0e837e8 (free commit) —
      marked_cut() in lib/common.sh appends an explicit
      "[truncated at N bytes]" marker whenever a cut happens, wired
      into every model-facing evidence cut (review-prep 60000,
      ux-review 6000, research-beat 8000/4000, night-research 6000,
      source_block, plan-draft backlog/lines, launch-context torch
      block) plus one review-prep prompt line naming the marker as
      the packet cap; contract test tests/test-marked-cut.sh, five
      fatal cases with a verified negative control (the pre-fix
      bug fails it). Class sweep clean: no execution-note block in
      any plan file of either repo ends mid-word; the two remaining
      "plan supply r" hits are this finding's own citations (the
      archived alert row and this plan's header). The still-open
      routed review plans of 2026-09-02/03/04/06 may carry phantoms
      of the same class — reproduce the packet cut before editing
      any file they name. Verify met: the finding's own check
      passes — the step-5 note reads complete and "plan supply r"
      exists only inside the citations; automation `make test`
      green (bash -n all scripts, all test files incl.
      test-marked-cut.sh, identifier lint); kernel `make test`
      green immediately before issue-cert. This tick lands in the
      ceremony that completes it (the rc=124 lesson).
