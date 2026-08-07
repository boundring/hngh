;;;; tests/unit/test-hngh-up.lisp — Tests for hngh-up AGENTS.md answerability (C3)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.hngh-up
  :description "Tests for hngh-up questionnaire answerability (C3)"
  :in :hngh)

(in-suite :hngh.hngh-up)

;;; --- Fixtures ---------------------------------------------------------------

(defun %hngh-up-tmp-root ()
  "Return a fresh temporary directory for building an AGENTS.md fixture."
  (merge-pathnames (format nil "hngh-hngh-up-test-~D/" (random 1000000))
                   (uiop:temporary-directory)))

(defun %write-agents-md-fixture (dir content)
  "Write CONTENT to DIR/AGENTS.md, creating DIR if needed. Returns the path."
  (let ((path (merge-pathnames "AGENTS.md" dir)))
    (ensure-directories-exist path)
    (with-open-file (stream path :direction :output :if-exists :supersede
                                 :if-does-not-exist :create)
      (write-string content stream))
    path))

(defun %merged-fixture (content)
  "Write CONTENT to a fresh tmp dir and return its merged-agents-md plist."
  (let ((dir (%hngh-up-tmp-root)))
    (unwind-protect
         (progn
           (%write-agents-md-fixture dir content)
           (hngh.plugins.agents-md:merge-agents-md
            (hngh.plugins.agents-md:discover-agents-md dir)))
      (ignore-errors (uiop:delete-directory-tree dir :validate t)))))

(defparameter %c3-rich-agents-md
  (let* ((yesterday (- (get-universal-time) 86400))
         (date-str
           (multiple-value-bind (sec min hour day mon year) (decode-universal-time yesterday)
             (declare (ignore sec min hour))
             (format nil "~4,'0D-~2,'0D-~2,'0D" year mon day))))
    (concatenate 'string
                 "# Fixture project

## Coordination contract (machine-wide)

- Shared memory: ~/.optmem/memo
- Summon a sibling agent headlessly: agent-call hermes|opencode

## Local-model & quota policy

Daily driver: unsloth/gemma-4-12b-it-qat-GGUF. Prefer local models for any
loop or automated work. Remote API spend < $1/day.

## Current state ("
                 date-str
                 ")

Tests green.

## Doc convention (D1)

Durable records carry green @ sha.
")))

(defparameter %c3-stale-agents-md
  "# Stale fixture

## Local-model & quota policy

Daily driver: unsloth/gemma-4-12b-it-qat-GGUF. Prefer local models.

## Current state (2020-01-01)

Ancient.
")

(defparameter %c3-mandate-agents-md
  "# Mandate-era fixture

## Local-model & quota policy

Primary driver: deepseek/deepseek-v4-flash-0731 via openrouter.
Remote API spend capped at $20/week (OpenRouter); free/local models are
fallbacks, not the daily driver.

## Current state (2026-08-05)

Tests green.

## Doc convention (D1)

Durable records carry green @ sha.
")

(defparameter %c3-bare-agents-md
  "# Bare fixture

## Unrelated section

No useful signals here.
")

;;; --- answer-from-agents-md --------------------------------------------------

(test hngh-up-c3-answers-squad-type-from-coordination
  "squad-type auto-answers :squad when AGENTS.md has a coordination section."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :squad-type (%merged-fixture %c3-rich-agents-md))
    (is (string= "squad" answer))
    (is (search "fireteam" reason))))

(test hngh-up-c3-answers-model-tier-local-only
  "model-tier auto-answers local-only when AGENTS.md prefers local models."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :model-tier (%merged-fixture %c3-rich-agents-md))
    (is (string= "local-only" answer))
    (is (search "local" reason))))

(test hngh-up-c3-answers-model-tier-budget-50-on-mandate-phrasing
  "model-tier auto-answers budget-50 when AGENTS.md names a remote primary driver (2026-08-05 mandate phrasing)."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :model-tier (%merged-fixture %c3-mandate-agents-md))
    (is (string= "budget-50" answer))
    (is (search "remote primary driver" reason))))

(test hngh-up-c3-answers-continue-policy-fresh
  "continue-policy auto-answers token-aware for a fresh current-state date."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :continue-policy (%merged-fixture %c3-rich-agents-md))
    (is (string= "token-aware" answer))
    (is (search "fresh" reason))))

(test hngh-up-c3-answers-continue-policy-stale
  "continue-policy auto-answers manual for a stale current-state date."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :continue-policy (%merged-fixture %c3-stale-agents-md))
    (is (string= "manual" answer))
    (is (search "stale" reason))))

(test hngh-up-c3-answers-journal-detail
  "journal-detail auto-answers standard when a doc-convention section exists."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :journal-detail (%merged-fixture %c3-rich-agents-md))
    (is (string= "standard" answer))
    (is (search "doc-convention" reason))))

(test hngh-up-c3-at-least-three-of-four-answered
  "A rich AGENTS.md auto-answers at least 3 of the 4 answerable questions."
  (let* ((merged (%merged-fixture %c3-rich-agents-md))
         (answered
           (loop for q in '(:squad-type :model-tier :continue-policy :journal-detail)
                 for (a r) = (multiple-value-list
                               (hngh.plugins.hngh-up:answer-from-agents-md q merged))
                 when a count it)))
    (is (>= answered 3))
    (is (<= answered 4))))

(test hngh-up-c3-bare-agents-md-answers-nothing
  "An AGENTS.md with none of the relevant sections answers nothing."
  (let ((merged (%merged-fixture %c3-bare-agents-md)))
    (dolist (q '(:squad-type :model-tier :continue-policy :journal-detail))
      (multiple-value-bind (answer reason)
          (hngh.plugins.hngh-up:answer-from-agents-md q merged)
        (declare (ignore reason))
        (is (null answer))))))

(test hngh-up-c3-unknown-question-returns-nil
  "Unhandled question IDs return nil (never crash the questionnaire)."
  (multiple-value-bind (answer reason)
      (hngh.plugins.hngh-up:answer-from-agents-md
       :strategy-name (%merged-fixture %c3-rich-agents-md))
    (declare (ignore reason))
    (is (null answer))))

;;; --- C7 PM-first-prompt generator ------------------------------------------

(defun %c7-tmp-project ()
  "Create a fresh synthetic project dir with AGENTS.md, a plan file, and a roadmap stub.
Returns the directory pathname."
  (let ((dir (merge-pathnames
              (format nil "hngh-c7-test-~D/" (random 1000000))
              (uiop:temporary-directory))))
    (ensure-directories-exist dir)
    (ensure-directories-exist (merge-pathnames ".hermes/plans/" dir))
    (ensure-directories-exist (merge-pathnames "docs/project/" dir))
    (ensure-directories-exist (merge-pathnames "docs/design/" dir))
    (%write-agents-md-fixture
     dir
     "# Test project

## Coordination contract (machine-wide)

- Shared memory: ~/.optmem/memo
- Summon a sibling agent headlessly: agent-call hermes|opencode

## Local-model & quota policy

Daily driver: unsloth/gemma-4-12b-it-qat-GGUF. Prefer local models.

## Current state (2026-08-03)

Tests green.

## Repo notes

Common Lisp (SBCL) project. Build: make build. Test: make test.
")
    (with-open-file (s (merge-pathnames
                        ".hermes/plans/2026-08-03_test-plan.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "# Test Plan

This is the first line of the test plan.
" s))
    (with-open-file (s (merge-pathnames
                        "docs/design/test-design.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "# Test Design

A design doc for testing.
" s))
    (with-open-file (s (merge-pathnames
                        "docs/project/roadmap.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string
       "# Hngh Roadmap

**Status**: M1 Batches 0-5 complete. M9 in progress.
**Last updated**: 2026-08-03
" s))
    dir))

(defun %c7-cleanup (dir)
  "Remove a synthetic project directory."
  (ignore-errors (uiop:delete-directory-tree dir :validate t)))

(test hngh-up-c7-prompt-contains-orientation-directive
  "The generated PM prompt starts with an orientation directive."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "Look around" prompt))
           (is (search "AGENTS.md" prompt))
           (is (search "OptMem" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-context-summary
  "The generated PM prompt contains a context summary with repo path,
AGENTS.md sections, plans, and design docs."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (let ((lc (string-downcase prompt)))
             (is (search "context" lc))
             (is (search "repo" lc))
             (is (search "coordination contract" lc))
             (is (search "local-model" lc))
             (is (search "test plan" lc))
             (is (search "test-design" lc))))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-roadmap-status
  "The generated PM prompt contains the roadmap status line."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "Roadmap" prompt))
           (is (search "M1 Batches" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-intent
  "The generated PM prompt contains the squad intent (goal string)."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review all plugins for quality"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "Intent" prompt))
           (is (search "review all plugins for quality" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-lifetime-policy
  "The generated PM prompt contains the lifetime policy section."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "Lifetime" prompt))
           (is (search "ephemeral" (string-downcase prompt))))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-lifetime-continual
  "The lifetime policy reflects :continual when specified."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "monitor queue"
                        :cwd dir :lifetime :continual
                        :squad-name "test-squad")))
           (is (search "continual" (string-downcase prompt))))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-lifetime-purpose-bounded
  "The lifetime policy reflects :purpose-bounded when specified."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "implement feature X"
                        :cwd dir :lifetime :purpose-bounded
                        :squad-name "test-squad")))
           (is (search "purpose-bounded" (string-downcase prompt))))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-coordination-protocol
  "The generated PM prompt contains the coordination protocol section."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "Coordination" prompt))
           (is (search "AGENTS.md" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-squad-name
  "The generated PM prompt contains the squad name."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "my-squad")))
           (is (search "my-squad" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-optmem-section
  "The generated PM prompt has an OptMem notes section (even if empty)."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "OptMem" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-contains-system-context
  "The generated PM prompt has a system context section with GPU/VRAM info."
  (let ((dir (%c7-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "test-squad")))
           (is (search "System" prompt))
           (is (search "GPU" prompt)))
      (%c7-cleanup dir))))

(test hngh-up-c7-prompt-no-agents-md-still-works
  "generate-pm-prompt does not crash when there is no AGENTS.md."
  (let ((dir (merge-pathnames
              (format nil "hngh-c7-noagents-~D/" (random 1000000))
              (uiop:temporary-directory))))
    (ensure-directories-exist dir)
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up::generate-pm-prompt
                        "do something"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "bare-squad")))
           (is (search "Intent" prompt))
           (is (search "do something" prompt)))
      (%c7-cleanup dir))))

;;; --- W5 prompt matrix (D5) -------------------------------------------------

(defun %d5-tmp-project ()
  "Create a fresh synthetic project for prompt matrix tests.
Extends %c7-tmp-project with a Makefile, a second plan, and design stubs.
Returns the directory pathname."
  (let ((dir (%c7-tmp-project)))
    ;; Add Makefile
    (with-open-file (s (merge-pathnames "Makefile" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "build:\n\techo built\ntest:\n\techo tested\n" s))
    ;; Add second plan
    (with-open-file (s (merge-pathnames
                        ".hermes/plans/2026-08-03_second-plan.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "# Second Plan\n\nAnother plan for testing.\n" s))
    ;; Add design stubs
    (with-open-file (s (merge-pathnames
                        "docs/design/beans-aesthetic.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "# Beans Aesthetic\n\nBean vocabulary per role.\n" s))
    (with-open-file (s (merge-pathnames
                        "docs/design/model-pareto.md" dir)
                       :direction :output :if-exists :supersede
                       :if-does-not-exist :create)
      (write-string "# Model Pareto\n\nPer-role fallback chains.\n" s))
    dir))

(test d5-dimension-selection
  "Dimension selection functions return correct values from context."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let ((dims (hngh.plugins.hngh-up:make-prompt-dimensions
                      :role :coder
                      :scenario :task-assign
                      :strategy :feature-sprint
                      :resources :budget-50
                      :squad-count 3
                      :roles-active '(:pm :designer :coder)
                      :lifetime :ephemeral
                      :directory (hngh.plugins.hngh-up::select-directory dir)
                      :system (hngh.plugins.hngh-up::select-system)
                      :purpose "implement the watcher plugin")))
           (is (eq (hngh.plugins.hngh-up:prompt-dimensions-role dims) :coder))
           (is (eq (hngh.plugins.hngh-up:prompt-dimensions-scenario dims) :task-assign))
           (is (eq (hngh.plugins.hngh-up:prompt-dimensions-strategy dims) :feature-sprint))
           (is (= (hngh.plugins.hngh-up:prompt-dimensions-squad-count dims) 3))
           (is (equal (hngh.plugins.hngh-up:prompt-dimensions-roles-active dims) '(:pm :designer :coder)))
           (is (string= (hngh.plugins.hngh-up:prompt-dimensions-purpose dims) "implement the watcher plugin")))
      (%c7-cleanup dir))))

(test d5-skeleton-selection
  "get-skeleton returns the correct template for each role×scenario pair."
  ;; All 36 combinations return non-NIL
  (dolist (role '(:pm :designer :coder :artist :accountant :worker))
    (dolist (scenario '(:startup :task-assign :status-check :review :shutdown :unblock))
      (let ((skeleton (hngh.plugins.hngh-up:get-skeleton role scenario)))
        (is (not (null skeleton))
            "No skeleton for ~A×~A" role scenario)
        (when skeleton
          ;; Skeleton contains at least one {{slot}} placeholder
          (is (search "{{" skeleton)
              "Skeleton for ~A×~A has no slots" role scenario)))))
  ;; PM startup skeleton contains the orientation directive
  (is (search "Orientation" (hngh.plugins.hngh-up:get-skeleton :pm :startup)))
  ;; Coder task-assign skeleton contains task-id slot
  (is (search "{{task-id}}" (hngh.plugins.hngh-up:get-skeleton :coder :task-assign)))
  ;; Review skeleton contains review-criteria slot
  (is (search "{{review-criteria}}" (hngh.plugins.hngh-up:get-skeleton :coder :review)))
  ;; Shutdown skeleton contains fragment-journal slot
  (is (search "{{fragment-journal}}" (hngh.plugins.hngh-up:get-skeleton :pm :shutdown)))
  ;; Unblock skeleton contains blocker-description slot
  (is (search "{{blocker-description}}" (hngh.plugins.hngh-up:get-skeleton :coder :unblock))))

(test d5-bone-filling
  "fill-bones replaces all {{slot}} placeholders with deterministic values."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (hngh.plugins.hngh-up:make-prompt-dimensions
                       :role :pm
                       :scenario :startup
                       :strategy :duo-review
                       :resources :local-only
                       :squad-count 1
                       :roles-active '(:pm)
                       :lifetime :ephemeral
                       :directory (hngh.plugins.hngh-up::select-directory dir)
                       :system (hngh.plugins.hngh-up::select-system)
                       :purpose "review plugins"))
                (skeleton (hngh.plugins.hngh-up:get-skeleton :pm :startup))
                (filled (hngh.plugins.hngh-up:fill-bones skeleton dims nil "test-squad")))
           ;; No unfilled {{slot}} placeholders remain
           (is (not (search "{{" filled))
               "Unfilled slots remain: ~A" filled)
           ;; Role name appears
           (is (search "pm" filled))
           ;; Squad name appears
           (is (search "test-squad" filled))
           ;; Goal appears
           (is (search "review plugins" filled))
           ;; Lifetime policy appears
           (is (search "ephemeral" (string-downcase filled)))
           ;; System context appears (GPU/VRAM)
           (is (search "GPU" filled)))
      (%c7-cleanup dir))))

(test d5-bone-filling-with-task-spec
  "fill-bones uses task-spec values when provided."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((task-spec (list :id "w2" :title "File watcher plugin"
                                 :files (list "src/plugins/file-watcher.lisp")
                                 :acceptance "make test green"
                                 :preconditions "config-watcher exists"))
                (dims (hngh.plugins.hngh-up:make-prompt-dimensions
                       :role :coder
                       :scenario :task-assign
                       :strategy :feature-sprint
                       :resources :budget-50
                       :squad-count 3
                       :roles-active '(:pm :designer :coder)
                       :lifetime :ephemeral
                       :directory (hngh.plugins.hngh-up::select-directory dir)
                       :system (hngh.plugins.hngh-up::select-system)
                       :purpose "implement file watcher"))
                (skeleton (hngh.plugins.hngh-up:get-skeleton :coder :task-assign))
                (filled (hngh.plugins.hngh-up:fill-bones skeleton dims task-spec "test-squad")))
           (is (not (search "{{" filled)))
           (is (search "w2" filled))
           (is (search "File watcher plugin" filled))
           (is (search "file-watcher.lisp" filled))
           (is (search "make test green" filled)))
      (%c7-cleanup dir))))

(test d5-flesh-skip-when-local
  "Flesh pass is skipped when the assigned model is local (gemma-4-12b)."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (hngh.plugins.hngh-up:make-prompt-dimensions
                       :role :worker
                       :scenario :startup
                       :strategy :nightly-audit
                       :resources :local-only
                       :squad-count 1
                       :roles-active '(:worker)
                       :lifetime :continual
                       :directory (hngh.plugins.hngh-up::select-directory dir)
                       :system (list :gpu-count 1 :vram-total-mb 24576 :vram-free-mb 16384)
                       :purpose "batch tasks"))
                (model (hngh.plugins.hngh-up:select-role-model :worker dims)))
           ;; Worker with local-only resources gets local model
           (is (getf model :local-p))
           ;; should-flesh-p returns NIL for local model
           (is (null (hngh.plugins.hngh-up:should-flesh-p dims (getf model :name) 1.00 0.001)))
           ;; generate-prompt returns the pre-flesh prompt (no flesh)
           (let ((prompt (hngh.plugins.hngh-up:generate-prompt dims :squad-name "test-squad"
                                                               :budget-remaining 1.00)))
             (is (search "Worker" prompt))
             (is (search "batch tasks" prompt))))
      (%c7-cleanup dir))))

(test d5-flesh-skip-when-no-budget
  "Flesh pass is skipped when budget-remaining is NIL or below estimated cost."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (hngh.plugins.hngh-up:make-prompt-dimensions
                       :role :coder
                       :scenario :startup
                       :strategy :feature-sprint
                       :resources :budget-50
                       :squad-count 3
                       :roles-active '(:pm :designer :coder)
                       :lifetime :ephemeral
                       :directory (hngh.plugins.hngh-up::select-directory dir)
                       :system (hngh.plugins.hngh-up::select-system)
                       :purpose "implement watcher")))
           ;; Budget NIL → no flesh
           (is (null (hngh.plugins.hngh-up:should-flesh-p dims "deepseek-v4-flash" nil 0.001)))
           ;; Budget 0 → no flesh
           (is (null (hngh.plugins.hngh-up:should-flesh-p dims "deepseek-v4-flash" 0 0.001)))
           ;; Budget sufficient → flesh
           (is (hngh.plugins.hngh-up:should-flesh-p dims "deepseek-v4-flash" 1.00 0.001)))
      (%c7-cleanup dir))))

(test d5-model-selection-per-role
  "select-role-model returns the correct primary model for each role."
  ;; PM gets glm-5.2 (frontier)
  (let ((model (hngh.plugins.hngh-up:select-role-model :pm
                                   (hngh.plugins.hngh-up:make-prompt-dimensions
                                    :role :pm :scenario :startup
                                    :strategy :duo-review :resources :budget-200
                                    :squad-count 2 :roles-active '(:pm :coder)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "review"))))
    (is (search "glm-5.2" (getf model :name))))
  ;; Coder gets deepseek-v4-flash (cheapest capable)
  (let ((model (hngh.plugins.hngh-up:select-role-model :coder
                                   (hngh.plugins.hngh-up:make-prompt-dimensions
                                    :role :coder :scenario :startup
                                    :strategy :feature-sprint :resources :budget-200
                                    :squad-count 3 :roles-active '(:pm :coder :worker)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "implement"))))
    (is (search "deepseek-v4-flash" (getf model :name))))
  ;; Artist never gets local model — chain head is deepseek-v4-flash-0731
  ;; per the D-040 synced chain (prompt-matrix.md §7.3, no glm-5.2 for artist)
  (let ((model (hngh.plugins.hngh-up:select-role-model :artist
                                   (hngh.plugins.hngh-up:make-prompt-dimensions
                                    :role :artist :scenario :startup
                                    :strategy :design-fork :resources :budget-200
                                    :squad-count 2 :roles-active '(:pm :artist)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "design"))))
    (is (not (getf model :local-p)))
    (is (search "deepseek-v4-flash" (getf model :name)))))

(test d5-model-fallback-chain
  "Fallback chain degrades correctly when primary is unavailable."
  ;; When budget is 0, remote models fail budget gate, chain falls to local
  (let ((model (hngh.plugins.hngh-up:select-role-model :worker
                                   (hngh.plugins.hngh-up:make-prompt-dimensions
                                    :role :worker :scenario :shutdown
                                    :strategy :nightly-audit :resources :local-only
                                    :squad-count 1 :roles-active '(:worker)
                                    :lifetime :continual
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 16384)
                                    :purpose "shutdown"))))
    ;; Worker shutdown allows local model
    (is (getf model :local-p))))

(test d5-prompt-cache
  "Same dimension combo returns cached prompt (no second flesh pass)."
  (hngh.plugins.hngh-up:cache-clear)
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let* ((dims (hngh.plugins.hngh-up:make-prompt-dimensions
                       :role :pm :scenario :startup
                       :strategy :duo-review :resources :budget-50
                       :squad-count 1 :roles-active '(:pm)
                       :lifetime :ephemeral
                       :directory (hngh.plugins.hngh-up::select-directory dir)
                       :system (hngh.plugins.hngh-up::select-system)
                       :purpose "test caching"))
                (prompt1 (hngh.plugins.hngh-up:generate-prompt dims :squad-name "cache-test"
                                                               :budget-remaining nil))  ; no flesh
                (prompt2 (hngh.plugins.hngh-up:generate-prompt dims :squad-name "cache-test"
                                                               :budget-remaining nil)))
           ;; Both calls return the same prompt
           (is (string= prompt1 prompt2)))
      (hngh.plugins.hngh-up:cache-clear)
      (%c7-cleanup dir))))

(test d5-generate-pm-prompt-backward-compat
  "generate-pm-prompt still works and delegates to generate-prompt."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let ((prompt (hngh.plugins.hngh-up:generate-pm-prompt
                        "review plugins"
                        :cwd dir :lifetime :ephemeral
                        :squad-name "compat-test")))
           (is (search "Orientation" prompt))
           (is (search "review plugins" prompt))
           (is (search "compat-test" prompt))
           (is (search "Lifetime" prompt)))
      (%c7-cleanup dir))))

(test d5-all-skeletons-fill
  "Every skeleton in the library fills without leaving unfilled slots or crashing."
  (let ((dir (%d5-tmp-project)))
    (unwind-protect
         (let ((dims (hngh.plugins.hngh-up:make-prompt-dimensions
                       :role :pm :scenario :startup
                       :strategy :duo-review :resources :budget-50
                       :squad-count 3 :roles-active '(:pm :designer :coder)
                       :lifetime :ephemeral
                       :directory (hngh.plugins.hngh-up::select-directory dir)
                       :system (hngh.plugins.hngh-up::select-system)
                       :purpose "test all skeletons")))
           (dolist (role '(:pm :designer :coder :artist :accountant :worker))
             (setf (hngh.plugins.hngh-up:prompt-dimensions-role dims) role)
             (dolist (scenario '(:startup :task-assign :status-check
                                 :review :shutdown :unblock))
               (setf (hngh.plugins.hngh-up:prompt-dimensions-scenario dims) scenario)
               (let* ((skeleton (hngh.plugins.hngh-up:get-skeleton role scenario))
                      (filled (hngh.plugins.hngh-up:fill-bones skeleton dims nil "all-skeletons-test")))
                 (is (not (null filled))
                     "Skeleton ~A×~A filled to NIL" role scenario)
                 (is (not (search "{{" filled))
                     "Skeleton ~A×~A has unfilled slots: ~A"
                     role scenario filled)))))
      (%c7-cleanup dir))))

(test d5-free-tier-distributed
  "Free-tier entries in every role chain are distributed across vendors
and use live OpenRouter catalog IDs (2026-08-06 refresh)."
  (let ((chains hngh.plugins.hngh-up::*per-role-fallback-chains*))
    (dolist (role '(:pm :designer :coder :artist :accountant :worker))
      (let* ((chain (second (assoc role chains)))
             (free-entries (remove-if-not (lambda (m)
                                            (and (not (getf m :local-p))
                                                 (zerop (getf m :input-cost))))
                                          chain))
             ;; Vendor = the org prefix of the catalog ID (nvidia/, google/, ...)
             (vendors (remove-duplicates
                       (mapcar (lambda (m)
                                 (subseq (getf m :name) 0
                                         (position #\/ (getf m :name))))
                               free-entries))))
        ;; Every role has at least one free model
        (is (not (null free-entries))
            "~A has no free-tier fallback" role)
        ;; Free tier spans at least two vendors (distributed, not single-vendor)
        (is (>= (length vendors) 2)
            "~A free tier is single-vendor: ~A" role vendors)
        ;; No stale short IDs — every free entry is a full catalog ID
        (dolist (m free-entries)
          (is (search ":free" (getf m :name))
              "~A free entry ~A lacks :free suffix" role (getf m :name))
          (is (not (search "nemotron-3-ultra:free" (getf m :name)))
              "~A uses stale nemotron-3-ultra:free ID" role)
          (is (not (search "nemotron-super:free" (getf m :name)))
              "~A uses stale nemotron-super:free ID" role)
          (is (not (search "nemotron-nano:free" (getf m :name)))
              "~A uses stale nemotron-nano:free ID" role))))))

(test d5-local-workhorse-agentworld
  "Qwen-AgentWorld-35B is the primary local fallback (fast when loaded),
and the VRAM table knows it (classified local, not remote)."
  (let ((model (hngh.plugins.hngh-up:select-role-model :coder
                                   (hngh.plugins.hngh-up:make-prompt-dimensions
                                    :role :coder :scenario :shutdown
                                    :strategy :feature-sprint :resources :local-only
                                    :squad-count 1 :roles-active '(:coder)
                                    :lifetime :ephemeral
                                    :directory (list :cwd (uiop:getcwd))
                                    :system (list :vram-free-mb 24576)
                                    :purpose "shutdown"))))
    (is (getf model :local-p))
    (is (search "Qwen-AgentWorld" (getf model :name)))))
