# H-A3: Pause/Resume & Stale Lease Recovery — Specification & Design Record

**Date**: 2026-08-02
**Author**: Opencode (Sisyphus)
**Project**: `hngh` (`~/Projects/etc/hngh`)
**Depends on**: H-A2 (`next-eligible-task` pure function)
**Status**: Design Ready for Implementation (`LOCAL-IMPLEMENT`)

---

## 1. Objective

`H-A3` extends the task queue lifecycle management with two critical capabilities:
1. **Pause/Resume Control**: Ability to pause queue dispatch (e.g. during maintenance or human inspection) and resume cleanly.
2. **Stale Lease Recovery**: Deterministic recovery for tasks stuck in `:running` status when an executing process crashes, times out, or loses its lease.

---

## 2. API Contract

### 2.1 Pause / Resume State Functions

```lisp
(defun pause-task-queue (state-store &optional reason)
  "Set queue pause flag in STATE-STORE with optional REASON string.")

(defun resume-task-queue (state-store)
  "Clear queue pause flag in STATE-STORE.")

(defun task-queue-paused-p (state-store)
  "Return (values PAUSED-P REASON) from STATE-STORE.")
```

### 2.2 Pure Stale Lease Recovery Function

```lisp
(defun recover-stale-leases (queue now &key (lease-timeout 300))
  "Pure function: inspect QUEUE for :running tasks whose :lease-until is < NOW.

For each stale task:
  - If (:attempt entry) < (:max-attempts entry):
      Set :status to :queued
      Increment :attempt by 1
      Set :lease-until to NIL
      Set :last-recovered-at to NOW
  - If (:attempt entry) >= (:max-attempts entry):
      Set :status to :failed
      Set :error to 'Stale lease expired; max attempts exceeded'
      Set :finished-at to NOW

Returns 3 values:
  1. NEW-QUEUE (copy of queue with stale entries updated)
  2. RECOVERED-COUNT (integer)
  3. FAILED-COUNT (integer)"
)
```

---

## 3. Integration with Task Driver

In `task-driver-tick`:
1. Check `(task-queue-paused-p state-store)` — if paused, log debug message and return `NIL`.
2. Call `(recover-stale-leases queue now)` and persist any recovered/failed entries before invoking `next-eligible-task`.
3. Dispatch eligible task if present.

---

## 4. Verification Plan

Unit tests in `tests/unit/test-task-driver.lisp`:
- `test-pause-resume-queue-state`
- `test-recover-stale-lease-requeues-when-attempts-remain`
- `test-recover-stale-lease-fails-when-max-attempts-reached`
- `test-recover-stale-lease-leaves-valid-running-task-untouched`
- `test-recover-stale-lease-is-pure`
