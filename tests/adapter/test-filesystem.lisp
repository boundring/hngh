(in-package #:hngh.tests)

;;; Rung 8: restricted local record transport. The adapter composes plist
;;; lines under an operator-named root only; it never infers a default store,
;;; resolves ~, or reads the environment. Records survive re-composition,
;;; duplicate identity refuses, unsafe identifiers refuse, and a broken root
;;; is a transport fault. The adapter imports nothing beyond Common Lisp.

(defun fresh-fs-root ()
  "A unique, existing directory under the process temp root."
  (let* ((base (uiop:with-temporary-file (:pathname p :keep t)
                 (delete-file p)
                 p))
         (root (uiop:ensure-directory-pathname base)))
    (ensure-directories-exist root)
    root))

(defun signals-store-refusal-p (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (hngh.adapters.filesystem:store-refusal () t)
    (error () nil)))

(defun signals-transport-fault-p (thunk)
  (handler-case
      (progn (funcall thunk) nil)
    (hngh.adapters.filesystem:transport-fault () t)
    (error () nil)))

(defun fs-record-line (id kind &key transport scope)
  "A canonical plist line in the shape main.lisp composes."
  (let ((line (list :identifier id
                    :kind kind
                    :run (list :identifier id)
                    :receipt (list :kind kind :facts '("fact")))))
    (if transport
        (append line (list :transport transport :scope (or scope "repository")))
        line)))

;;; Record, replay, re-composition ------------------------------------------

(let* ((root (fresh-fs-root))
       (store (hngh.adapters.filesystem:make-filesystem-store :root root))
       (line (fs-record-line "run-1" :creation)))
  (check (eq :recorded (hngh.adapters.filesystem:store-record-run store line))
         "filesystem store records a fresh line")
  (check (= 1 (length (hngh.adapters.filesystem:store-entries store)))
         "filesystem store replays one entry")
  (check (equal line (first (hngh.adapters.filesystem:store-entries store)))
         "filesystem store replays the exact line")
  (let ((recomposed (hngh.adapters.filesystem:make-filesystem-store :root root)))
    (check (= 1 (length (hngh.adapters.filesystem:store-entries recomposed)))
           "filesystem records survive re-composition"))
  (check (null (hngh.adapters.filesystem:store-entries
                (hngh.adapters.filesystem:make-filesystem-store
                 :root (fresh-fs-root))))
         "a fresh store has no entries")
  (uiop:delete-directory-tree root :validate t))

;;; Plist-line storage: one record, one line --------------------------------

(let* ((root (fresh-fs-root))
       (store (hngh.adapters.filesystem:make-filesystem-store :root root)))
  (hngh.adapters.filesystem:store-record-run store (fs-record-line "run-1" :creation))
  (hngh.adapters.filesystem:store-record-run store (fs-record-line "run-1" :start))
  (let* ((file (first (directory (merge-pathnames "*.*" root))))
         (lines 0))
    (check (not (null file)) "filesystem store keeps a record file in the root")
    (with-open-file (stream file)
      (loop for line = (read-line stream nil)
            while line do (incf lines)))
    (check (= 2 lines) "filesystem store appends one line per record"))
  (uiop:delete-directory-tree root :validate t))

;;; Duplicate identity refuses ----------------------------------------------

(let* ((root (fresh-fs-root))
       (store (hngh.adapters.filesystem:make-filesystem-store :root root))
       (creation (fs-record-line "run-1" :creation)))
  (hngh.adapters.filesystem:store-record-run store creation)
  (check (eq :conflict (hngh.adapters.filesystem:store-record-run store creation))
         "duplicate identifier+kind refuses")
  (check (eq :recorded (hngh.adapters.filesystem:store-record-run
                        store (fs-record-line "run-1" :start)))
         "a distinct stage kind records")
  (check (eq :recorded (hngh.adapters.filesystem:store-record-run
                        store (fs-record-line "run-2" :creation)))
         "a distinct identifier records")
  (check (eq :recorded (hngh.adapters.filesystem:store-record-run
                        store (fs-record-line "run-1" :admission)))
         "an armed-stage admission receipt records")
  (check (eq :recorded (hngh.adapters.filesystem:store-record-run
                        store (fs-record-line "run-2" :admission
                                              :transport "filesystem")))
         "an admitted transport for a fresh run records")
  (check (eq :conflict (hngh.adapters.filesystem:store-record-run
                        store (fs-record-line "run-2" :admission
                                              :transport "filesystem")))
         "duplicate (run, transport) admission refuses")
  (check (eq :conflict (hngh.adapters.filesystem:store-record-run
                        store (fs-record-line "run-2" :admission
                                              :transport "filesystem"
                                              :scope "docs")))
         "admission with another scope still conflicts on (run, transport)")
  (uiop:delete-directory-tree root :validate t))

;;; Unsafe identifiers and malformed lines refuse ----------------------------

(let* ((root (fresh-fs-root))
       (store (hngh.adapters.filesystem:make-filesystem-store :root root)))
  (check (signals-store-refusal-p
          (lambda ()
            (hngh.adapters.filesystem:store-record-run
             store (fs-record-line "/etc/passwd" :creation))))
         "an absolute identifier refuses")
  (check (signals-store-refusal-p
          (lambda ()
            (hngh.adapters.filesystem:store-record-run
             store (fs-record-line "../escape" :creation))))
         "an identifier escaping the root refuses")
  (check (signals-store-refusal-p
          (lambda ()
            (hngh.adapters.filesystem:store-record-run
             store '(:kind :creation))))
         "a line without an identifier refuses")
  (check (signals-store-refusal-p
          (lambda ()
            (hngh.adapters.filesystem:store-record-run
             store '(:identifier "run-1" :kind "creation"))))
         "a line without a keyword kind refuses")
  (check (signals-store-refusal-p
          (lambda ()
            (hngh.adapters.filesystem:store-record-run
             store '(:identifier "run-1" :kind :creation :extra))))
         "a non-plist line refuses")
  (uiop:delete-directory-tree root :validate t))

;;; Transport faults ----------------------------------------------------------

(check (signals-transport-fault-p
        (lambda ()
          (hngh.adapters.filesystem:make-filesystem-store
           :root "/nonexistent-hngh-root-xyz/")))
       "a missing root is a transport fault")

(let ((file (uiop:with-temporary-file (:pathname p :keep t) p)))
  (check (signals-transport-fault-p
          (lambda ()
            (hngh.adapters.filesystem:make-filesystem-store :root file)))
         "a root that is a file is a transport fault"))

(let* ((root (fresh-fs-root))
       (store (hngh.adapters.filesystem:make-filesystem-store :root root)))
  (uiop:delete-directory-tree root :validate t)
  (check (signals-transport-fault-p
          (lambda ()
            (hngh.adapters.filesystem:store-record-run
             store (fs-record-line "run-1" :creation))))
         "recording into a deleted root is a transport fault"))

(let* ((root (fresh-fs-root))
       (store (hngh.adapters.filesystem:make-filesystem-store :root root)))
  (hngh.adapters.filesystem:store-record-run store (fs-record-line "run-1" :creation))
  (let ((file (first (directory (merge-pathnames "*.*" root)))))
    (with-open-file (stream file :direction :output :if-exists :append
                            :if-does-not-exist :create)
      (write-string ")" stream))
    (check (signals-transport-fault-p
            (lambda () (hngh.adapters.filesystem:store-entries store)))
           "a corrupt store line is a transport fault")
    (uiop:delete-directory-tree root :validate t)))

;;; Purity --------------------------------------------------------------------

(check (equal (list (package-name (find-package :cl)))
              (mapcar #'package-name
                      (package-use-list
                       (find-package :hngh.adapters.filesystem))))
       "filesystem adapter imports only Common Lisp")