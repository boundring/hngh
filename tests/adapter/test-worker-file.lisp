(in-package :hngh.tests)

;;;; The operator worker=FILE transport (src/main.lisp READ-WORKER-FILE).
;;;; These tests execute REAL subprocesses (/bin/true, /bin/false,
;;;; /bin/sleep) through the operator file's command -- that is the
;;;; feature. The adapter tests in test-worker.lisp stay fixture-backed;
;;;; only this file runs a real transport.

(defun worker-file-write (contents)
  "Write CONTENTS to a kept temp file; returns its namestring."
  (uiop:with-temporary-file (:pathname path :keep t)
    (with-open-file (stream path :direction :output :if-exists :supersede)
      (write-string contents stream))
    (namestring path)))

(defparameter +worker-file-valid+
  (concatenate 'string "command=/bin/true" '(#\Newline)
               "timeout-seconds=10"))

;; worker=FILE completes: /bin/true with the task label as argv[1]
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch
                 (list "run-worker" "run-1" "task=scout"
                       (format nil "worker=~A"
                               (worker-file-write +worker-file-valid+)))
                 :root root)))
    (check (= 0 (worker-exit result))
           "run-worker with a valid worker file completes")
    (check (worker-has "worker status=complete" result)
           "the file-transported worker run renders complete"))
  (uiop:delete-directory-tree root :validate t))

;; worker=FILE refuses on a nonzero exit: /bin/false
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch
                 (list "run-worker" "run-1" "task=scout"
                       (format nil "worker=~A"
                               (worker-file-write
                                (concatenate 'string
                                             "command=/bin/false" '(#\Newline)
                                             "timeout-seconds=10"))))
                 :root root)))
    (check (= 1 (worker-exit result))
           "a nonzero file-transport exit refuses")
    (check (worker-has "worker status=refused" result)
           "the refused file transport names worker status=refused"))
  (uiop:delete-directory-tree root :validate t))

;; worker=FILE that cannot be read is a malformed invocation (exit 2)
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch
                 (list "run-worker" "run-1" "task=scout"
                       "worker=/tmp/hngh-missing-worker.conf")
                 :root root)))
    (check (= 2 (worker-exit result))
           "a missing worker file is a malformed invocation")
    (check (worker-has "cannot read worker file" result)
           "the refusal names the unreadable worker file"))
  (uiop:delete-directory-tree root :validate t))

;; malformed worker files refuse (exit 2, malformed worker file)
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (dolist (bad (list
                ;; unknown key
                (concatenate 'string +worker-file-valid+ '(#\Newline) "foo=1")
                ;; duplicate key
                (concatenate 'string +worker-file-valid+ '(#\Newline)
                             "timeout-seconds=9")
                ;; missing timeout-seconds
                "command=/bin/true"
                ;; missing command
                "timeout-seconds=10"
                ;; non-integer timeout-seconds
                (concatenate 'string "command=/bin/true" '(#\Newline)
                             "timeout-seconds=abc")
                ;; non-positive timeout-seconds
                (concatenate 'string "command=/bin/true" '(#\Newline)
                             "timeout-seconds=0")))
    (let ((result (worker-dispatch
                   (list "run-worker" "run-1" "task=scout"
                         (format nil "worker=~A"
                                 (worker-file-write bad)))
                   :root root)))
      (check (= 2 (worker-exit result))
             (format nil "malformed worker file refuses: ~S"
                     (subseq bad 0 (min 40 (length bad)))))
      (check (worker-has "malformed worker file" result)
             "the refusal names the malformed worker file")))
  (uiop:delete-directory-tree root :validate t))

;; the worker file is validated BEFORE admission work: a valid file on an
;; unadmitted run still refuses with the missing admission (exit 1)
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (let ((result (worker-dispatch
                 (list "run-worker" "run-1" "task=scout"
                       (format nil "worker=~A"
                               (worker-file-write +worker-file-valid+)))
                 :root root)))
    (check (= 1 (worker-exit result))
           "a valid worker file still serves only an admitted run")
    (check (worker-has "not admitted for worker" result)
           "the refusal names the missing worker admission"))
  (uiop:delete-directory-tree root :validate t))

;; the timeout bound fires: /bin/sleep "3" with timeout-seconds=1 is
;; terminated and reports no exit code (a worker fault, exit 3)
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch
                 (list "run-worker" "run-1" "task=3"
                       (format nil "worker=~A"
                               (worker-file-write
                                (concatenate 'string
                                             "command=/bin/sleep" '(#\Newline)
                                             "timeout-seconds=1"))))
                 :root root)))
    (check (= 3 (worker-exit result))
           "an expired file-transport task faults")
    (check (worker-has "worker-fault" result)
           "the expired task names worker-fault"))
  (uiop:delete-directory-tree root :validate t))

;; a launch failure (nonexistent command) surfaces as a worker fault
(let ((root (worker-dispatch-root)))
  (worker-dispatch +worker-create-args+ :root root)
  (worker-dispatch '("admit-transport" "run-1" "worker" "repository")
                   :root root)
  (let ((result (worker-dispatch
                 (list "run-worker" "run-1" "task=scout"
                       (format nil "worker=~A"
                               (worker-file-write
                                (concatenate 'string
                                             "command=/nonexistent-hngh-worker-prog"
                                             '(#\Newline)
                                             "timeout-seconds=10"))))
                 :root root)))
    (check (= 3 (worker-exit result))
           "a failed launch faults through the adapter")
    (check (worker-has "worker-fault" result)
           "the launch failure names worker-fault"))
  (uiop:delete-directory-tree root :validate t))

;;; Direct parser checks: parse-worker-config refuses each malformed
;;; variant and returns the closed plist for a valid file.

(check (equal '(:timeout-seconds 10 :command "/bin/true")
              (hngh.main::parse-worker-config
               (concatenate 'string
                            "# comment" '(#\Newline)
                            "command=/bin/true" '(#\Newline)
                            '(#\Newline)
                            "timeout-seconds=10" '(#\Newline))))
       "parse-worker-config returns the plist for a valid file")
(dolist (bad (list "command=/bin/true"
                   "timeout-seconds=10"
                   (concatenate 'string "command=/bin/true" '(#\Newline) "foo=1")
                   (concatenate 'string +worker-file-valid+ '(#\Newline)
                                "command=/bin/false")
                   (concatenate 'string "command=/bin/true" '(#\Newline)
                                "timeout-seconds=abc")
                   (concatenate 'string "command=/bin/true" '(#\Newline)
                                "timeout-seconds=-5")
                   (concatenate 'string "command=/bin/true" '(#\Newline)
                                "timeout-seconds=0")
                   "command"
                   (concatenate 'string "command=/bin/true" '(#\Newline)
                                "command=")))
  (check (signals-error-p
          (lambda () (hngh.main::parse-worker-config bad)))
         (format nil "parse-worker-config refuses: ~S" bad)))
