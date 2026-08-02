;;;; tests/unit/test-mission-control.lisp — Tests for Mission Control (M6.1)
;;;;
;;;; Live tmux integration on a throwaway session (MC_SESSION=hngh-mc-test).
;;;; Skips cleanly when tmux or the mc script is unavailable.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.mission-control
  :description "Tests for Mission Control (M6.1)"
  :in :hngh)

(in-suite :hngh.mission-control)

;;; --- Helpers ---------------------------------------------------------------

(defun mc-test-available-p ()
  "T when the mc script and a working tmux are present."
  (and (probe-file (hngh.plugins.mission-control::mc-path))
       (ignore-errors
         (let ((proc (sb-ext:run-program "tmux" '("-V") :search t :wait t
                                         :output nil :error nil)))
           (zerop (sb-ext:process-exit-code proc))))))

(defun %mc-test-run (&rest args)
  "Run mc with ARGS against the throwaway session. Returns (values output exit-code)."
  (let* ((out-str (make-string-output-stream))
         (proc (sb-ext:run-program
                "env"
                (append (list "MC_SESSION=hngh-mc-test"
                              (namestring (hngh.plugins.mission-control::mc-path)))
                        args)
                :search t :wait t :output out-str :error nil)))
    (values (get-output-stream-string out-str)
            (sb-ext:process-exit-code proc))))

(defun %mc-test-cleanup ()
  "Kill the throwaway session if it exists."
  (ignore-errors
    (sb-ext:run-program "tmux" '("kill-session" "-t" "hngh-mc-test")
                        :search t :wait t :output nil :error nil)))

(defun %count-lines (string)
  "Count lines in STRING."
  (if (or (null string) (zerop (length string)))
      0
      (1+ (count #\Newline (string-right-trim '(#\Newline) string)))))

;;; --- Tests -----------------------------------------------------------------

(test mc-session-lifecycle
  "mc start creates a 4+ pane session; add adds one; stop removes the session."
  (if (not (mc-test-available-p))
      (skip "tmux or mc script not available")
      (progn
        (%mc-test-cleanup)
        (unwind-protect
             (progn
               (multiple-value-bind (out code) (%mc-test-run "start")
                 (declare (ignore out))
                 (is (zerop code)))
               (is (hngh.plugins.mission-control::session-alive-p "hngh-mc-test"))
               (multiple-value-bind (out code) (%mc-test-run "status")
                 (is (zerop code))
                 (is (>= (%count-lines out) 4)
                     "expected at least 4 panes, got: ~A" out))
               (multiple-value-bind (out code) (%mc-test-run "add" "echo test-pane")
                 (declare (ignore out))
                 (is (zerop code)))
               (multiple-value-bind (out code) (%mc-test-run "status")
                 (is (zerop code))
                 (is (>= (%count-lines out) 5)
                     "expected at least 5 panes after add, got: ~A" out)))
          (%mc-test-cleanup))
        (multiple-value-bind (out code) (%mc-test-run "stop")
          (declare (ignore out))
          (is (zerop code)))
        (is (not (hngh.plugins.mission-control::session-alive-p "hngh-mc-test"))))))

(test squad-registry-loads-local-definitions
  "The data registry is readable without evaluating executable forms."
  (let* ((root (asdf:system-source-directory :hngh))
         (registry (hngh.plugins.mission-control:read-squad-registry
                    (merge-pathnames "data/squads.lisp" root)))
         (names (mapcar (lambda (definition) (getf definition :name)) registry)))
    (is (= 2 (length registry)))
    (is (member "day-queue" names :test #'string=))
    (is (member "night-ralph" names :test #'string=))
    (is (every (lambda (definition)
                 (every (lambda (role)
                          (hngh.plugins.mission-control::local-model-p
                           (getf role :model)))
                        (getf definition :roles)))
               registry))))

(test squad-lifecycle-persists-continuation-and-forwards
  "Squad lifecycle is testable without launching an external harness."
  (let* ((home (make-tmp-home))
         (root (asdf:system-source-directory :hngh))
         (registry (merge-pathnames "data/squads.lisp" root))
         (calls '())
         (starting-status nil)
         (hngh.plugins.mission-control::*squad-command-runner*
           (lambda (program args)
             (push (list program args) calls)
             (unless (string= program "tmux")
               (setf starting-status
                     (getf (hngh.plugins.mission-control::read-squad-state
                            (hngh.plugins.mission-control::squad-state-path
                             "day-queue" home))
                           :status)))
             (if (and (string= program "tmux")
                      (string= (first args) "list-panes"))
                (values 0 (format nil "%1~%%2~%") "")
                 (values 0 "started" "")))))
    (unwind-protect
         (progn
           (let ((state (hngh.plugins.mission-control:squad-up
                         "day-queue"
                         :registry-path registry
                         :hngh-home home)))
             (is (eq :starting starting-status))
             (is (eq :running (getf state :status)))
             (is (eq :hngh (getf state :ownership)))
             (is (not (null (probe-file (getf state :forward-prompt-path))))))
           (multiple-value-bind (state pane-count)
               (hngh.plugins.mission-control:squad-forward-prompt
                "day-queue" "resume from the shared queue"
                :hngh-home home)
             (is (= 2 pane-count))
             (is (= 1 (getf state :forward-count)))
             (is (search "resume from the shared queue"
                         (uiop:read-file-string
                          (getf state :forward-prompt-path)))))
           (let ((state (hngh.plugins.mission-control:squad-down
                         "day-queue" :hngh-home home)))
             (is (eq :stopped (getf state :status))))
           (is (>= (length calls) 5)))
      (cleanup-tmp-home home))))

(test squad-launch-failure-persists-failed-state
  "A launcher failure leaves readable failed ownership evidence."
  (let* ((home (make-tmp-home))
         (root (asdf:system-source-directory :hngh))
         (registry (merge-pathnames "data/squads.lisp" root))
         (failure-runner
           (lambda (program args)
             (declare (ignore program args))
             (values 17 "" "launcher unavailable")))
         (hngh.plugins.mission-control::*squad-command-runner* failure-runner))
    (unwind-protect
         (progn
           (signals simple-error
             (hngh.plugins.mission-control:squad-up
              "day-queue" :registry-path registry :hngh-home home))
           (let ((state (hngh.plugins.mission-control::read-squad-state
                         (hngh.plugins.mission-control::squad-state-path
                          "day-queue" home))))
             (is (eq :failed (getf state :status)))
             (is (search "launcher unavailable" (getf state :error)))
             (signals simple-error
               (hngh.plugins.mission-control:squad-down
                "day-queue" :hngh-home home))))
      (cleanup-tmp-home home))))

(test squad-state-publish-preserves-prior-state-on-rename-failure
  "Atomic publication does not destroy the prior readable state."
  (let* ((home (make-tmp-home))
         (path (merge-pathnames "squads/state.lisp" home)))
    (unwind-protect
         (progn
           (hngh.plugins.mission-control::write-squad-state
            path '(:status :old))
           (let ((hngh.plugins.mission-control::*squad-state-rename-function*
                   (lambda (source target)
                     (declare (ignore source target))
                     (error "injected rename failure"))))
             (signals simple-error
               (hngh.plugins.mission-control::write-squad-state
                path '(:status :new))))
           (is (eq :old
                   (getf (hngh.plugins.mission-control::read-squad-state path)
                         :status))))
      (cleanup-tmp-home home))))
