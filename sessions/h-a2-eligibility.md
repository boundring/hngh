# H-A2: Pure Eligibility Selection — Session & Design Record

**Date**: 2026-08-02
**Author**: Opencode (Sisyphus)
**Worktree**: ~~`/home/bricker/Projects/etc/.worktrees/hngh-day-queue-a2`~~ (abandoned; landed on lane-a3)
**Branch**: ~~`lane-hngh-day-queue-a2`~~ `lane-hngh-day-queue-a3` (commit 829f4db, merged to main as part of a3)
**Status**: Implementation Complete & Tested; merged to main (983/983 green)

---

## 1. Overview

`H-A2` delivers the pure function `next-eligible-task` in `src/plugins/ai-orchestrator.lisp`.
It determines which task in the queue is eligible for dispatch based on dependencies, submission timestamp, lease expiration, authority policy, and maintenance state.

---

## 2. API Contract

```lisp
(defun next-eligible-task (queue now maintenance-state)
  ...)
```

### Parameters
- `queue`: List of v2 task plists.
- `now`: Universal time (integer).
- `maintenance-state`: Keyword (`:clear`, `:maintenance-pending`, `:maintenance-active`, `:unknown`).

### Return Values
1. `eligible-task` (plist or `NIL`): The oldest eligible task (sorted by `:submitted-at`, then `:id`).
2. `blocked-tasks` (list of plists): Copy of queued tasks whose dependencies have terminally failed (`:failed` or `:cancelled`), with `:status` set to `:blocked` and a descriptive `:blocked-reason`.

---

## 3. Eligibility Criteria Rules

A task is eligible if ALL of the following hold:
1. `:status` is `:queued`.
2. All task IDs in `:depends-on` refer to tasks in the queue with `:status :done`.
3. `:not-before` is `NIL` or `<= now`.
4. No task in the queue is `:running` with an unexpired `:lease-until` timestamp (or `NIL` lease).
5. `:authority` is NOT `:proposed`. If `:authority` is `:approval`, `:approval-at` must be a positive integer `<= now`.
6. Maintenance check:
   - `:clear` → allows all tasks.
   - `:maintenance-active` → blocks all tasks.
   - `:maintenance-pending` / `:unknown` → allows ordinary tasks, blocks tasks with `:requires-stable-system T`.

---

## 4. Test Evidence

Unit tests in `tests/unit/test-task-driver.lisp` (14 new tests):
- `eligibility-returns-nil-on-empty`
- `eligibility-selects-oldest-queued`
- `eligibility-selects-oldest-by-id-when-same-submitted-at`
- `eligibility-skips-non-queued`
- `eligibility-gates-on-dependencies`
- `eligibility-missing-dependency-id-blocks`
- `eligibility-blocks-on-failed-dependency`
- `eligibility-blocks-on-cancelled-dependency`
- `eligibility-respects-not-before`
- `eligibility-one-at-a-time-running-lease`
- `eligibility-running-without-lease-blocks`
- `eligibility-rejects-proposed-authority`
- `eligibility-requires-approval-at-for-approval-authority`
- `eligibility-maintenance-active-blocks-all`
- `eligibility-stable-system-gated-by-maintenance`
- `eligibility-only-stable-system-task-under-maintenance-pending`

**Full Test Suite**: `Did 901 checks. Pass: 901 (100%). Fail: 0.`
