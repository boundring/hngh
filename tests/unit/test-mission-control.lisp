;;;; tests/unit/test-mission-control.lisp — Tests for Mission Control (M6.1)
;;;;
;;;; Layout lifecycle tests use a fixture tmux executable and temporary state.
;;;; They never inspect or modify a live user tmux server.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.mission-control
  :description "Tests for Mission Control (M6.1)"
  :in :hngh)

(in-suite :hngh.mission-control)

;;; --- Helpers ---------------------------------------------------------------

(defparameter +fake-tmux-script+
  "#!/usr/bin/env bash
set -uo pipefail
cmd=\"${1:-}\"
{
  printf '%s' \"$cmd\"
  shift || true
  printf '\\t%s' \"$@\"
  printf '\\n'
} >> \"$MC_FIXTURE/calls\"
case \"$cmd\" in
  has-session)
    test -f \"$MC_FIXTURE/session\"
    ;;
  list-panes)
    test -f \"$MC_FIXTURE/panes\" && cat \"$MC_FIXTURE/panes\"
    ;;
  new-session)
    : > \"$MC_FIXTURE/session\"
    ;;
  split-window)
    if [[ \" $* \" == *\" -P \"* ]]; then printf '%%fixture\\n'; fi
    ;;
  kill-session)
    rm -f \"$MC_FIXTURE/session\"
    ;;
esac
")

(defun %write-test-file (path contents &key executable)
  "Write CONTENTS to PATH and optionally make it executable."
  (ensure-directories-exist path)
  (with-open-file (stream path :direction :output :if-exists :supersede
                               :if-does-not-exist :create)
    (write-string contents stream))
  (when executable
    (uiop:run-program (list "chmod" "+x" (namestring path))))
  path)

(defun %setup-mc-fixture (home &key panes session)
  "Create an isolated tmux executable and optional pane/session fixtures."
  (let ((tmux (merge-pathnames "bin/tmux" home))
        (fixture (merge-pathnames "fixture/" home))
        (state (merge-pathnames "state/" home)))
    (ensure-directories-exist state)
    (%write-test-file tmux +fake-tmux-script+ :executable t)
    (%write-test-file (merge-pathnames "calls" fixture) "")
    (when panes
      (%write-test-file (merge-pathnames "panes" fixture) panes))
    (when session
      (%write-test-file (merge-pathnames "session" fixture)
                        (format nil "running~%")))
    fixture))

(defun %mc-test-run (home &rest args)
  "Run mc with ARGS against HOME's fake tmux and state root."
  (let* ((out-str (make-string-output-stream))
         (err-str (make-string-output-stream))
         (path (format nil "~Abin:~A" (namestring home) (uiop:getenv "PATH")))
         (proc (sb-ext:run-program
                "env"
                (append (list "MC_SESSION=hngh-mc-test"
                              (format nil "MC_STATE_ROOT=~Astate" (namestring home))
                              (format nil "MC_FIXTURE=~Afixture" (namestring home))
                              (format nil "PATH=~A" path)
                              (namestring (hngh.plugins.mission-control::mc-path)))
                        args)
                :search t :wait t :output out-str :error err-str)))
    (values (get-output-stream-string out-str)
            (sb-ext:process-exit-code proc)
            (get-output-stream-string err-str))))

(defun %read-layout-file (home)
  "Read HOME's layout fixture with reader evaluation disabled."
  (with-open-file (stream (merge-pathnames "state/mc-layout.lisp" home)
                          :direction :input)
    (let ((*read-eval* nil))
      (read stream))))

(defun %fixture-calls (home)
  "Return fake tmux calls recorded under HOME."
  (uiop:read-file-lines (merge-pathnames "fixture/calls" home)))

(defun %count-call (name calls)
  "Count fixture CALLS whose first tab-separated field is NAME."
  (count-if (lambda (call)
              (and (>= (length call) (length name))
                   (string= name call :end2 (length name))
                   (or (= (length call) (length name))
                       (char= #\Tab (char call (length name))))))
            calls))

;;; --- Tests -----------------------------------------------------------------

(test mc-save-layout-produces-valid-plist
  "Saving fixture panes preserves count, geometry, cwd, and command strings."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (progn
           (%setup-mc-fixture
            home :session t
            :panes (format nil "0~C80~C40~C/tmp/project one~Csvc-dash~%1~C79~C40~C/tmp/project two~Cmake run~%"
                           #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab))
           (multiple-value-bind (out code err) (%mc-test-run home "save-layout")
             (declare (ignore out err))
             (is (zerop code)))
           (let* ((layout (%read-layout-file home))
                  (panes (getf layout :panes)))
             (is (= 2 (length panes)))
             (is (= 80 (getf (first panes) :width)))
             (is (= 40 (getf (second panes) :height)))
             (is (string= "/tmp/project one" (getf (first panes) :cwd)))
             (is (string= "make run" (getf (second panes) :cmd)))))
      (cleanup-tmp-home home))))

(test mc-restore-layout-recreates-count-and-sizes
  "Restore issues one creation per pane and requests the saved geometry."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (progn
           (%setup-mc-fixture home)
           (%write-test-file
            (merge-pathnames "state/mc-layout.lisp" home)
            (format nil "(:panes ((:index 0 :width 80 :height 40 :cwd \"/tmp/project one\" :cmd \"svc-dash\") (:index 1 :width 79 :height 40 :cwd \"/tmp/project two\" :cmd \"make run\")))~%"))
           (multiple-value-bind (out code err) (%mc-test-run home "restore-layout")
             (declare (ignore out))
             (is (zerop code) "restore-layout failed: ~A" err))
           (let ((calls (%fixture-calls home)))
             (is (= 1 (%count-call "new-session" calls)))
             (is (= 1 (%count-call "split-window" calls)))
             (is (= 2 (%count-call "resize-pane" calls)))
             (is (some (lambda (call)
                         (search (format nil "-x~C80~C-y~C40" #\Tab #\Tab #\Tab)
                                 call))
                       calls))
             (is (some (lambda (call)
                         (search (format nil "-x~C79~C-y~C40" #\Tab #\Tab #\Tab)
                                 call))
                       calls))
             (is (some (lambda (call) (search "/tmp/project two" call)) calls))))
      (cleanup-tmp-home home))))

(test mc-start-missing-layout-uses-tiled-fallback
  "Missing state warns and starts the original four-pane tiled layout."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (progn
           (%setup-mc-fixture home)
           (multiple-value-bind (out code err) (%mc-test-run home "start")
             (declare (ignore out))
             (is (zerop code))
             (is (search "no saved layout" err)))
           (let ((calls (%fixture-calls home)))
             (is (= 1 (%count-call "new-session" calls)))
             (is (= 3 (%count-call "split-window" calls)))
             (is (= 1 (%count-call "select-layout" calls)))))
      (cleanup-tmp-home home))))

(test mc-start-malformed-layout-fails-closed
  "Malformed state warns and starts tiled without executing saved data."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (progn
           (%setup-mc-fixture home)
           (%write-test-file (merge-pathnames "state/mc-layout.lisp" home)
                             (format nil "#.(error \"must not run\")~%"))
           (multiple-value-bind (out code err) (%mc-test-run home "start")
             (declare (ignore out))
             (is (zerop code))
             (is (search "malformed layout" err)))
           (let ((calls (%fixture-calls home)))
             (is (= 1 (%count-call "new-session" calls)))
             (is (= 3 (%count-call "split-window" calls)))))
      (cleanup-tmp-home home))))

(test mc-stop-start-roundtrip-preserves-cwd
  "Stop saves before teardown and the next start restores cwd with spaces."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (progn
           (%setup-mc-fixture
            home :session t
            :panes (format nil "0~C80~C40~C/tmp/round trip one~Cbash~%1~C79~C40~C/tmp/round trip two~Cwatch~%"
                           #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab))
           (multiple-value-bind (out code err) (%mc-test-run home "stop")
             (declare (ignore out err))
             (is (zerop code)))
           (let ((calls (%fixture-calls home)))
             (is (< (position-if (lambda (call) (search "list-panes" call)) calls)
                    (position-if (lambda (call) (search "kill-session" call)) calls))))
           (%write-test-file (merge-pathnames "fixture/calls" home) "")
           (multiple-value-bind (out code err) (%mc-test-run home "start")
             (declare (ignore out err))
             (is (zerop code)))
           (let ((calls (%fixture-calls home)))
             (is (some (lambda (call) (search "/tmp/round trip one" call)) calls))
             (is (some (lambda (call) (search "/tmp/round trip two" call)) calls))))
      (cleanup-tmp-home home))))

(test session-layout-fixtures-validate-geometry-tolerance
  "Lisp layout helpers accept two-cell drift and reject larger drift."
  (let ((saved '(:panes ((:index 0 :width 80 :height 40 :cwd "/tmp/a" :cmd "bash")
                         (:index 1 :width 79 :height 40 :cwd "/tmp/b" :cmd "watch"))))
        (near '(:panes ((:index 0 :width 78 :height 42 :cwd "/tmp/a" :cmd "bash")
                        (:index 1 :width 80 :height 39 :cwd "/tmp/b" :cmd "watch"))))
        (far '(:panes ((:index 0 :width 76 :height 40 :cwd "/tmp/a" :cmd "bash")
                       (:index 1 :width 79 :height 40 :cwd "/tmp/b" :cmd "watch")))))
    (is (hngh.plugins.mission-control::layout-geometry-within-tolerance-p saved near))
    (is (not (hngh.plugins.mission-control::layout-geometry-within-tolerance-p saved far)))))

(test session-layout-save-restore-uses-isolated-state
  "Lisp save and restore use data-only state and mocked tmux commands."
  (let* ((home (make-tmp-home))
         (calls '())
         (hngh.plugins.mission-control::*squad-command-runner*
           (lambda (program args)
             (push (list program args) calls)
             (if (and (string= program "tmux")
                      (string= (first args) "list-panes"))
                 (values 0
                         (format nil "0~C80~C40~C/tmp/lisp one~Cbash~%1~C79~C40~C/tmp/lisp two~Cwatch~%"
                                 #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab)
                         "")
                 (values 0 (format nil "%fixture~%") "")))))
    (unwind-protect
         (progn
           (let ((layout (hngh.plugins.mission-control::save-session-layout
                          :session "fixture" :hngh-home home)))
             (is (= 2 (length (getf layout :panes)))))
           (multiple-value-bind (restored reason)
               (hngh.plugins.mission-control::restore-session-layout
                :session "fixture" :hngh-home home)
             (is (not (null restored)))
             (is (eq :restored reason)))
           (is (some (lambda (call)
                       (member "/tmp/lisp two" (second call) :test #'string=))
                     calls)))
      (cleanup-tmp-home home))))

(test session-layout-missing-and-malformed-fail-closed
  "Lisp restore does not call tmux for absent or non-data layout state."
  (let* ((home (make-tmp-home))
         (calls '())
         (hngh.plugins.mission-control::*squad-command-runner*
           (lambda (program args)
             (push (list program args) calls)
             (values 0 "" ""))))
    (unwind-protect
         (progn
           (multiple-value-bind (restored reason)
               (hngh.plugins.mission-control::restore-session-layout
                :session "fixture" :hngh-home home)
             (is (not restored))
             (is (eq :missing reason)))
           (%write-test-file (merge-pathnames "state/mc-layout.lisp" home)
                             (format nil "#.(error \"must not run\")~%"))
           (multiple-value-bind (restored reason)
               (hngh.plugins.mission-control::restore-session-layout
                :session "fixture" :hngh-home home)
             (is (not restored))
             (is (eq :malformed reason)))
           (is (null calls)))
      (cleanup-tmp-home home))))

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

(test session-tree-registration-and-children
  "Register, query children, and unregister sessions in the session tree."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (progn
           ;; Initial tree is empty
           (is (null (hngh.plugins.mission-control::read-session-tree :hngh-home home)))
           
           ;; Register parent and children
           (hngh.plugins.mission-control::register-session "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session "child-1" :parent "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session "child-2" :parent "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session "other" :hngh-home home)

           (let ((tree (hngh.plugins.mission-control::read-session-tree :hngh-home home)))
             (is (not (null tree)))
             (is (= 4 (length (getf tree :sessions)))))

           (let ((children (hngh.plugins.mission-control::session-children "parent" :hngh-home home)))
             (is (= 2 (length children)))
             (is (not (null (find "child-1" children :key (lambda (s) (getf s :name)) :test #'string=))))
             (is (not (null (find "child-2" children :key (lambda (s) (getf s :name)) :test #'string=)))))

           ;; Unregister child-1
           (hngh.plugins.mission-control::unregister-session "child-1" :hngh-home home)
           (let ((children (hngh.plugins.mission-control::session-children "parent" :hngh-home home)))
             (is (= 1 (length children)))
             (is (string= "child-2" (getf (first children) :name)))))
      (cleanup-tmp-home home))))


;;; --- Session restart (Task 83 lifecycle seam) -----------------------------

(defun %restart-runner (home &key alive-panes alive-names)
  "Fake *squad-command-runner* for restart tests: ALIVE-NAMES are session names reported alive by has-session; ALIVE-PANES is the list-panes fixture text (or NIL to fail saves)."
  (lambda (program args)
    (cond
      ((and (string= program "tmux")
            (string= (first args) "has-session"))
       (if (member (third args) alive-names :test #'string=)
           (values 0 "" "")
           (values 1 "" "")))
      ((and (string= program "tmux")
            (string= (first args) "list-panes"))
       (if alive-panes
           (values 0 alive-panes "")
           (values 1 "" "tmux list-panes failed")))
      ((string= program "tmux")
       (values 0 "" ""))
      (t
       (values 0 "started" "")))))

(defun %control-calls (runner-calls)
  "Return start/stop entries from a recorded runner call log (reverse order)."
  (remove-if-not (lambda (entry)
                   (let ((args (second entry)))
                     (and args (member (first args) '("start" "stop") :test #'string=))))
                 runner-calls))

(defun %has-session-targets (runner-calls)
  "Return the session names checked by has-session in call-log order."
  (mapcar (lambda (entry) (third (second entry)))
          (remove-if-not (lambda (entry)
                          (and (string= (first entry) "tmux")
                               (string= (first (second entry)) "has-session")))
                        runner-calls)))

(test restart-session-signals-when-not-alive
  "Restarting a session that is not running signals an actionable error."
  (let ((home (make-tmp-home)))
    (unwind-protect
         (signals simple-error
           (let ((hngh.plugins.mission-control::*squad-command-runner*
                   (%restart-runner home :alive-names nil)))
             (hngh.plugins.mission-control::restart-session
              :session "fixture" :hngh-home home)))
      (cleanup-tmp-home home))))

(test restart-session-saves-stops-starts-restores
  "Restarting a live session saves layout, stops, starts, and restores it."
  (let* ((home (make-tmp-home))
         (calls '())
         (panes (format nil "0~C80~C40~C/tmp/project one~Csvc-dash~%1~C79~C40~C/tmp/project two~Cmake run~%"
                        #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab #\Tab))
         (runner (lambda (program args)
                    (push (list program args) calls)
                    (funcall (%restart-runner home
                                             :alive-panes panes
                                             :alive-names '("fixture"))
                             program args))))
    (unwind-protect
         (progn
           (multiple-value-bind (ok saved)
               (let ((hngh.plugins.mission-control::*squad-command-runner* runner))
                 (hngh.plugins.mission-control::restart-session
                  :session "fixture" :hngh-home home))
             (is-true ok)
             (is (not (null saved))))
           ;; Layout was persisted to the state root
           (is (probe-file (merge-pathnames "state/mc-layout.lisp" home)))
           ;; Calls log is newest-first, so start (latest) precedes stop (earliest)
           (let ((controls (%control-calls calls)))
             (is (string= "start" (first (second (first controls)))))
             (is (string= "stop" (first (second (first (last controls))))))))
      (cleanup-tmp-home home))))

(test restart-session-proceeds-without-saved-layout
  "A failed layout save does not abort the restart; it falls back to tiled."
  (let* ((home (make-tmp-home))
         (calls '())
         (runner (lambda (program args)
                    (push (list program args) calls)
                    (funcall (%restart-runner home
                                             :alive-names '("fixture")
                                             :alive-panes nil)
                             program args))))
    (unwind-protect
         (progn
           (multiple-value-bind (ok saved)
               (let ((hngh.plugins.mission-control::*squad-command-runner* runner))
                 (hngh.plugins.mission-control::restart-session
                  :session "fixture" :hngh-home home))
             (is-true ok)
             (is (null saved)))
           ;; Stop/start still ran even though layout save failed
           (let ((controls (%control-calls calls)))
             (is (= 2 (length controls))))
           (is (not (probe-file (merge-pathnames "state/mc-layout.lisp" home)))))
      (cleanup-tmp-home home))))

(test cascade-restart-restarts-parent-before-children
  "Cascade restart restarts the named session, then each registered child."
  (let* ((home (make-tmp-home))
         (calls '())
         (panes (format nil "0~C80~C40~C/tmp/project one~Csvc-dash~%"
                        #\Tab #\Tab #\Tab #\Tab))
         (runner (lambda (program args)
                    (push (list program args) calls)
                    (funcall (%restart-runner home
                                             :alive-panes panes
                                             :alive-names '("parent" "child-a" "child-b"))
                             program args))))
    (unwind-protect
         (progn
           (hngh.plugins.mission-control::register-session
            "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session
            "child-a" :parent "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session
            "child-b" :parent "parent" :hngh-home home)
           (multiple-value-bind (ok children)
               (let ((hngh.plugins.mission-control::*squad-command-runner* runner))
                 (hngh.plugins.mission-control::cascade-restart
                  "parent" :hngh-home home))
             (is-true ok)
             (is (= 2 (length children))))
           ;; Every session was alive-checked; parent was checked first (log is newest-first)
           (let ((targets (%has-session-targets calls)))
             (is (string= "parent" (first (last targets))))
             (is (member "child-a" targets :test #'string=))
             (is (member "child-b" targets :test #'string=))))
      (cleanup-tmp-home home))))

(test cascade-restart-tolerates-child-failure
  "A child that is not alive is logged and does not abort the cascade."
  (let* ((home (make-tmp-home))
         (calls '())
         (panes (format nil "0~C80~C40~C/tmp/project one~Csvc-dash~%"
                        #\Tab #\Tab #\Tab #\Tab))
         (runner (lambda (program args)
                    (push (list program args) calls)
                    (funcall (%restart-runner home
                                             :alive-panes panes
                                             :alive-names '("parent" "child-b"))
                             program args))))
    (unwind-protect
         (progn
           (hngh.plugins.mission-control::register-session
            "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session
            "child-a" :parent "parent" :hngh-home home)
           (hngh.plugins.mission-control::register-session
            "child-b" :parent "parent" :hngh-home home)
           ;; child-a reports not-alive; the cascade must continue to child-b
           (multiple-value-bind (ok children)
               (let ((hngh.plugins.mission-control::*squad-command-runner* runner))
                 (hngh.plugins.mission-control::cascade-restart
                  "parent" :hngh-home home))
             (is-true ok)
             (is (= 2 (length children))))
           (let ((targets (%has-session-targets calls)))
             (is (string= "parent" (first (last targets))))
             (is (member "child-a" targets :test #'string=))
             (is (member "child-b" targets :test #'string=))))
      (cleanup-tmp-home home))))
