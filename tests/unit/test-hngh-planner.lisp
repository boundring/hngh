;;;; tests/unit/test-hngh-planner.lisp — Tests for the C6 recursive planner
;;;;
;;;; Wave 0: the tolerant, section-aware roadmap parser. Fixture tests
;;;; exercise gap extraction from milestone sections + wave tables without
;;;; requiring a live roadmap file. The parser must degrade gracefully on
;;;; prose edits, table reordering, extra columns, and status variants.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.hngh-planner
  :description "Tests for the C6 recursive planner (roadmap parsing)"
  :in :hngh)

(in-suite :hngh.hngh-planner)

;;; --- Fixtures --------------------------------------------------------------

(defparameter *sample-roadmap*
  "# Project Roadmap

## Milestone 0 — Foundation (complete)

| Wave | Capabilities | Status |
|---|---|---|
| 1 | Boot | **Done** (494 tests) |

## Milestone 1 — The Harness (in progress)

| Wave | Capabilities | Status |
|---|---|---|
| 1 | Harness | **In progress** (batch 3) |

## Milestone 9 — Squad Autonomy (not started)

**Goal**: squads self-orient off per-directory AGENTS.md.

| Wave | Capabilities | Status |
|---|---|---|
| 1 | C1 AGENTS.md, C5 fragment journal | **Done** (494 tests) |
| 2 | C3 questionnaire, C2 resource-gate | **Done** |
| 3 | C4, C7, C10 | **In progress** (C7 done) |
| 4 | C6 planner cycle + signals layer | **In progress** |
| 5 | C8 benchmark-runner, C9 nightly cron | **Not started** |
"
  "A representative roadmap with summary + per-milestone wave tables, mixed
statuses (Done / In progress / Not started).")

(defparameter *blocked-roadmap*
  "## Milestone 5 — The Network (blocked)

| Wave | Capabilities | Status |
|---|---|---|
| 1 | Peer discovery | **Blocked** (needs mDNS) |
| 2 | Replication | Not started |
")

;;; --- Gap extraction --------------------------------------------------------

(test planner-gap-list-finds-unstarted-milestones
  (let ((gaps (hngh.plugins.hngh-planner:planner-gap-list *sample-roadmap*)))
    ;; M9 overall is 'not started' -> a gap, with its wave sub-statuses.
    (is (some (lambda (g) (and (equal (getf g :milestone) "M9")
                               (eql (getf g :status) :not-started)))
              gaps))
    ;; M1 is in progress -> present, flagged, not 'not started'.
    (let ((m1 (find "M1" gaps :key (lambda (g) (getf g :milestone)) :test #'equal)))
      (is-true m1)
      (is (eql (getf m1 :status) :in-progress)))
    ;; M0 is complete -> NOT a gap.
    (is (null (find "M0" gaps :key (lambda (g) (getf g :milestone)) :test #'equal)))))

(test planner-gap-list-surfaces-unstarted-waves
  (let ((m9 (find "M9" (hngh.plugins.hngh-planner:planner-gap-list *sample-roadmap*)
                  :key (lambda (g) (getf g :milestone)) :test #'equal)))
    (is-true m9)
    ;; Wave 5 = C8/C9 is "Not started" -> an actionable gap within M9.
    (is (some (lambda (w) (and (eql (getf w :wave) 5)
                               (eql (getf w :status) :not-started)))
              (getf m9 :waves)))))

(test planner-gap-list-marks-blocked
  (let ((gaps (hngh.plugins.hngh-planner:planner-gap-list *blocked-roadmap*)))
    (let ((m5 (find "M5" gaps :key (lambda (g) (getf g :milestone)) :test #'equal)))
      (is-true m5)
      (is-true (getf m5 :blocked))
      (is (some (lambda (w) (and (eql (getf w :wave) 1)
                                 (eql (getf w :status) :blocked)))
                (getf m5 :waves))))))

(test planner-gap-list-tolerates-prose-and-extra-columns
  ;; A wave table with an extra column and interleaved prose must still parse.
  (let ((text "## Milestone 3 — The Network (in progress)

Some prose with **Status**: relevant but the table is what matters.

| Wave | Capabilities | Dependencies | Status |
|---|---|---|---|
| 1 | Peer link | core | **Done** |
| 2 | Sync | peer | In progress |
| 3 | Share | sync | Not started |
"))
    (let ((gaps (hngh.plugins.hngh-planner:planner-gap-list text)))
      (let ((m3 (find "M3" gaps :key (lambda (g) (getf g :milestone)) :test #'equal)))
        (is-true m3)
        (is (= 3 (length (getf m3 :waves))))
        (is (some (lambda (w) (eql (getf w :status) :not-started))
                  (getf m3 :waves)))))))

(test planner-gap-list-empty-on-no-tables
  (is (null (hngh.plugins.hngh-planner:planner-gap-list "No tables here."))))

;;; --- Status classification ------------------------------------------------

(test planner-status-classify-variants
  (is (eql :not-started (hngh.plugins.hngh-planner:planner-status "Not started")))
  (is (eql :not-started (hngh.plugins.hngh-planner:planner-status "**Not started**")))
  (is (eql :in-progress (hngh.plugins.hngh-planner:planner-status "In progress")))
  (is (eql :in-progress (hngh.plugins.hngh-planner:planner-status "**In progress** (C7 done)")))
  (is (eql :done (hngh.plugins.hngh-planner:planner-status "**Done** (494 tests)")))
  (is (eql :done (hngh.plugins.hngh-planner:planner-status "Complete")))
  (is (eql :blocked (hngh.plugins.hngh-planner:planner-status "**Blocked** (needs mDNS)")))
  (is (eql :unknown (hngh.plugins.hngh-planner:planner-status "Random prose"))))

;;; --- Weighting + decomposition + emission (Wave 1) ------------------------

(test planner-weight-is-rule-based-and-tolerant
  (let* ((gap '(:milestone "M9" :title "Squad Autonomy" :status :in-progress
                :blocked nil :waves ((:wave 4 :status :in-progress))))
         (w (hngh.plugins.hngh-planner:planner-weight gap)))
    (is (numberp (getf w :priority)))
    (is (numberp (getf w :confidence)))
    (is (numberp (getf w :cost)))
    (is (numberp (getf w :score)))
    ;; M9 has a defined base priority.
    (is (= 70 (getf w :priority)))))

(test planner-weight-blocked-bumps-priority
  (let* ((gap '(:milestone "M3" :title "Network" :status :blocked
                :blocked t :waves ()))
         (w (hngh.plugins.hngh-planner:planner-weight gap)))
    ;; 60 base + 5 blocked bump.
    (is (= 65 (getf w :priority)))))

(test planner-decompose-fallback-emits-single-work-task
  (let ((specs (hngh.plugins.hngh-planner:planner-decompose
                '(:milestone "M9" :title "Squad Autonomy"))))
    (is (listp specs))
    (is (= 1 (length specs)))
    (let ((s (first specs)))
      (is (stringp (getf s :task)))
      (is (eql :work (getf s :type)))
      (is (eql :worker (getf s :role))))))

(test planner-decompose-hook-is-bounded-by-max-tasks
  (let ((hngh.plugins.hngh-planner::*decompose-notify*
          (lambda (gap ctx) (declare (ignore gap ctx))
            (loop for i from 1 to 20 collect
              (list :task (format nil "task ~D" i) :type :work :role :worker)))))
    (let ((specs (hngh.plugins.hngh-planner:planner-decompose
                  '(:milestone "M9" :title "Squad Autonomy")
                  :max-tasks 5)))
      (is (= 5 (length specs))))))

(test planner-emit-tasks-stamp-planner-source
  ;; Verify a decomposed spec carries the :planner source tag through
  ;; planner-emit-task composition (the emission path used by the loop).
  (let* ((gap '(:milestone "M9" :title "Squad Autonomy"))
         (spec (first (hngh.plugins.hngh-planner:planner-decompose gap))))
    (is (eql :planner hngh.plugins.hngh-planner:*planner-source-tag*))
    (is (stringp (getf spec :task)))))

;;; --- Closed loop (Wave 2) -------------------------------------------------

(defun %write-tmp-roadmap (tmp)
  "Write a representative roadmap under TMP and return TMP."
  (ensure-directories-exist (format nil "~A/docs/project/" tmp))
  (with-open-file (s (format nil "~A/docs/project/roadmap.md" tmp)
                     :direction :output :if-exists :supersede)
    (format s "## Milestone 9 — Squad Autonomy (in progress)

| Wave | Capabilities | Status |
|---|---|---|
| 4 | C6 planner | **In progress** |
| 5 | C8 benchmark | Not started |
")
    (format s "## Milestone 3 — The Network (in progress)

| Wave | Capabilities | Status |
|---|---|---|
| 1 | Peer link | **In progress** |
"))
  tmp)

(test planner-cycle-no-roadmap-fails-closed
  (with-aio-light (tmp)
    (let ((r (hngh.plugins.hngh-planner:planner-cycle tmp
                                                      :emit t)))
      (is (eql :no-roadmap (getf r :error)))
      (is (null (getf r :emitted))))))

(test planner-cycle-dry-run-submits-nothing
  (with-aio-light (tmp)
    (%write-tmp-roadmap tmp)
    (let ((r (hngh.plugins.hngh-planner:planner-cycle tmp
                                                      :dry-run t)))
      (is (null (getf r :emitted)))
      (is-true (getf r :dry-run))
      (is (>= (getf r :gaps) 1))
      ;; Queue is empty after dry-run.
      (is (null (hngh.plugins.ai-orchestrator:list-tasks))))))

(test planner-cycle-emits-when-open
  (with-aio-light (tmp)
    (%write-tmp-roadmap tmp)
    (let ((r (hngh.plugins.hngh-planner:planner-cycle tmp
                                                      :emit t)))
      (is (plusp (getf r :gaps)))
      ;; Emits at most max-emissions and returns ids.
      (is (plusp (length (getf r :emitted))))
      (is (= (length (getf r :emitted))
             (getf r :new)))
      ;; The queue now has planner-sourced tasks.
      (is (some (lambda (e)
                  (eql :planner (getf e :source)))
                (hngh.plugins.ai-orchestrator:list-tasks))))))

(test planner-cycle-dedups-reopen
  (with-aio-light (tmp)
    (%write-tmp-roadmap tmp)
    ;; First cycle emits.
    (hngh.plugins.hngh-planner:planner-cycle tmp :emit t)
    ;; Second cycle sees the same gaps already open -> dedup, no new emit.
    (let ((r (hngh.plugins.hngh-planner:planner-cycle tmp :emit t)))
      (is (zerop (length (getf r :emitted))))
      (is (>= (getf r :skipped-dupe) 1)))))

(test planner-cycle-refrains-when-paused
  (with-aio-light (tmp)
    (%write-tmp-roadmap tmp)
    (hngh.plugins.ai-orchestrator:pause-dispatch)
    (unwind-protect
         (let ((r (hngh.plugins.hngh-planner:planner-cycle tmp :emit t)))
           (is (null (getf r :emitted)))
           (is-true (getf r :paused)))
      (hngh.plugins.ai-orchestrator:resume-dispatch))))
