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
