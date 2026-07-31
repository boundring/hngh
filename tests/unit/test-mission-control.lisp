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
