# 2026-09-15 — rehearsal lane step 2: isolated-worktree gate rehearsal wired

Plan: docs/project/plans/2026-09-09-rehearsal-lane.plan.md step 2
(design docs/design/rehearsal-and-self-order.md). Automation-lane commit
72e0d7a6; this record plus the plan's execution note land through the
ceremony.

## Question

Can gate pre-validation run on a `git archive HEAD` copy so plan
acceptance stops contending with parallel delegated sessions, without
touching the working tree's mutations (red kernel/automation rc=2
flaps 2026-09-09 were load-correlated)?

## Evidence read

- 550e8ff5 (2026-09-14) landed automation/scripts/rehearse-gate.sh (87
  lines) and automation/tests/test-rehearse-gate.py (229 lines) inside
  the staged-index-sweep accident (lesson 2026-09-14T08:44:40Z), red:
  3 failures + 2 errors, reproduced 2026-09-15 pre-edit.
- scripts/accept-plans.py contained no ACCEPT_ISOLATED_GATE reference;
  automation/Makefile no rehearse line (grep-verified pre-edit).
- Working-tree sanity: all four surfaces clean, test reproduces exactly
  the briefed failure signature.

## Doctrine applied

Test-first repair order (plan ceremony, failing-test discipline);
fail-closed refusal; the 2026-09-13 step-1 precedent that the committed
test is the pinned contract, not the stale plan prose; staged-index
discipline (named files only, git diff --cached inspected first).

## Findings

1. Fixture repair: the committed stub Makefile wrote a RELATIVE
   `log/gatelog` inside the archive temp dir, which the script's EXIT
   trap destroys; assertions read the working tree. Repaired to an
   absolute path outside the archive; RehearseGate class 7/7 green
   (red-then-green proven against the unchanged script behavior).
2. The test pins REHEARSE_LOG as the script's breadcrumb seam; the
   script now defaults `--log` to `${REHEARSE_LOG:-}` (one line).
3. accept-plans.py opt-in: `ACCEPT_ISOLATED_GATE=1` routes both gate
   runs through scripts/rehearse-gate.sh (resolved script-adjacent, so
   sandbox HNGH_AUTOMATION_ROOTs work); red or rc=2 refuse blocks
   acceptance fail-closed with the tail in the alert row; the
   automation rehearsal is skipped when the kernel rehearsal is red.
   Off by default: direct runs preserved (pinned).
4. Suite: 10/10 green; wired into the automation Makefile; automation
   `make test` green (rc=0); kernel `make test` green in the working
   tree (rc=0, lisp suite).

## Verification blocker (evidence, not silence)

The plan's verification clause "an isolated rehearsal on this repo
exits 0 matching a green gate" is NOT met and the step-2 box stays
unticked. The rehearsal refused rc=2 fail-closed on this repo:

    2026-09-15T08:44:57Z | repo=<kernel-root> | gate=make test | rc=2

tail of the gate output reached tests/scripts/test-loop-history-guard
.py, whose `git log --format=%h%x09%s 1915713..HEAD` exits 128 in an
archive copy (no .git; `git archive HEAD` cannot carry history). This
is structural, not load: the kernel suite requires a git work tree in
cwd. Operator-item: add an out-of-repo seam to test-loop-history-guard
.py (kernel tests/ surface, forbidden in machine sessions today), then
re-run the rehearsal; per the design guardrail the refusal files
evidence and never suppresses the real action's governance — the direct
kernel gate ran full and green in the working tree for this slice.

## Recommended next line

Kernel session, after a mid-run machine docs-decision pass: grace the
loop-history guard with a git-absent seam (CLAUDE-docs declared miss is
NOT needed — the change is code-surface + candidate-certificate), tick
step-2's rehearsal clause, then run the first opt-in acceptance roll
(ACCEPT_ISOLATED_GATE=1 in cadence-params, one row) per plan step 3's
dependency on the dry-run store discipline.
