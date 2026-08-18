(in-package :hngh.tests)

;;; Rung 4 read-only evidence adapter tests: fixed command set, closed
;;; request construction, fixture-backed gathering through an injected
;;; process transport, and inward dependency direction.

(defun read-text-fixture (relative)
  "Read a fixture file verbatim as a string (raw bytes, newlines kept)."
  (with-open-file (stream (cl-user::project-file relative)
                          :direction :input
                          :if-does-not-exist :error)
    (let ((buffer (make-string (file-length stream))))
      (subseq buffer 0 (read-sequence buffer stream)))))

(defun fixture-text (name)
  (read-text-fixture (format nil "tests/fixtures/evidence/~A" name)))

(defun make-request (&rest arguments)
  (apply (adapter-function "MAKE-EVIDENCE-REQUEST") arguments))

(defun make-ports (runner)
  (adapter-call "MAKE-EVIDENCE-PORTS" :run-process runner))

(defun gather-evidence (request ports)
  (adapter-call "GATHER-EVIDENCE" request ports))

(defun result-status (result)
  (adapter-call "EVIDENCE-RESULT-STATUS" result))

(defun result-facts (result)
  (adapter-call "EVIDENCE-RESULT-FACTS" result))

(defun result-manifest (result)
  (adapter-call "EVIDENCE-RESULT-MANIFEST" result))

(defun result-refusals (result)
  (adapter-call "EVIDENCE-RESULT-REFUSAL-LABELS" result))

(defun fact-kind (fact) (hngh.domain:evidence-fact-kind fact))
(defun fact-fingerprint (fact) (hngh.domain:evidence-fact-fingerprint fact))
(defun fact-state (fact) (hngh.domain:evidence-fact-state fact))

(defun request-command (request)
  (adapter-call "EVIDENCE-REQUEST-COMMAND" request))

(defun request-targets (request)
  (adapter-call "EVIDENCE-REQUEST-TARGETS" request))

(defun request-source-role (request)
  (adapter-call "EVIDENCE-REQUEST-SOURCE-ROLE" request))

(defun make-ports-fake (&key responses)
  (multiple-value-bind (runner reporter)
      (make-evidence-ports-fake :responses responses)
    (declare (ignore reporter))
    (make-ports runner)))

(defun one-ports-fake (responses)
  (make-ports-fake :responses responses))

;;; Fixed, enumerable command set ---------------------------------------

(check (equal '(:repository-revision :working-tree-status :file-sha256)
              (adapter-value "+EVIDENCE-COMMANDS+"))
       "evidence command set is fixed and enumerable")

(dolist (command '(:repository-revision :working-tree-status))
  (let ((request (make-request :command command)))
    (check (eql command (request-command request))
           "request preserves its fixed command")
    (check (null (request-targets request))
           "non-hash commands admit no evidence targets")
    (check (null (request-source-role request))
           "non-hash commands admit no source role")))

(let ((request (make-request :command :file-sha256
                             :targets '("src/a.lisp" "src/b.lisp")
                             :source-role "source")))
  (check (eql :file-sha256 (request-command request))
         "hash request preserves its fixed command")
  (check (equal '("src/a.lisp" "src/b.lisp") (request-targets request))
         "hash request preserves its target list")
  (check (equal "source" (request-source-role request))
         "hash request preserves its source role"))

;;; Unknown commands fail closed ---------------------------------------------

(dolist (command '(nil :unlisted :git-commit "git" :push))
  (check (signals-error-p (lambda () (make-request :command command)))
         "an unknown evidence command refuses construction"))

;;; Unauthorized targets fail closed -----------------------------------------

(dolist (path (list "/etc/passwd"
                    "../escape"
                    "src/../../escape.lisp"
                    "-n"
                    "-"
                    "~/.ssh/id_rsa"
                    "src/./x.lisp"
                    "src//x.lisp"
                    "src/x.lisp/"
                    "src\\x.lisp"
                    (format nil "src/~Cx.lisp" #\Newline)))
  (check (signals-error-p
          (lambda ()
            (make-request :command :file-sha256
                          :targets (list path) :source-role "source")))
         "an escaping or option-like evidence path refuses closed"))

;;; Duplicate evidence fails closed ------------------------------------------

(check (signals-error-p
        (lambda ()
          (make-request :command :file-sha256
                        :targets '("src/a.lisp" "src/a.lisp")
                        :source-role "source")))
       "duplicate evidence targets refuse closed")

;;; Malformed request fields fail closed -------------------------------------

(dolist (arguments (list '()
                         (list :command :file-sha256)
                         (list :command :file-sha256 :targets nil
                               :source-role "source")
                         (list :command :file-sha256 :targets '()
                               :source-role "source")
                         (list :command :file-sha256 :targets "src/a.lisp"
                               :source-role "source")
                         (list :command :file-sha256 :targets '(42)
                               :source-role "source")
                         (list :command :file-sha256
                               :targets '("src/a.lisp"))
                         (list :command :file-sha256
                               :targets '("src/a.lisp")
                               :source-role "")
                         (list :command :file-sha256
                               :targets '("src/a.lisp")
                               :source-role 42)
                         (list :command :repository-revision
                               :targets '("src/a.lisp"))
                         (list :command :repository-revision
                               :source-role "source")))
  (check (signals-error-p
          (lambda () (apply #'make-request arguments)))
         "malformed evidence requests fail closed"))

;;; Ports construction --------------------------------------------------------

(check (signals-error-p (lambda () (make-ports nil)))
       "evidence ports require a run-process callback")
(check (signals-error-p (lambda () (make-ports "not a function")))
       "evidence ports reject a non-function callback")

;;; Gather refuses wrong-typed inputs ----------------------------------------

(let ((runner (make-ports (lambda (argv)
                            (declare (ignore argv))
                            (values 0 "ok" "")))))
  (check (signals-error-p (lambda () (gather-evidence nil runner)))
         "gather-evidence requires an evidence request")
  (check (signals-error-p
          (lambda ()
            (gather-evidence (make-request :command :repository-revision) nil)))
         "gather-evidence requires evidence ports"))

;;; :repository-revision ------------------------------------------------------

(let* ((revision (string-right-trim '(#\Newline)
                                     (fixture-text "rev-parse-valid.txt")))
       (result (gather-evidence
                (make-request :command :repository-revision)
                (make-ports-fake
                 :responses (list (list :return 0
                                        (fixture-text "rev-parse-valid.txt")
                                        ""))))))
  (check (eq :complete (result-status result))
         "revision gathering completes")
  (check (null (result-refusals result))
         "complete revision result carries no refusal labels")
  (check (null (result-manifest result))
         "revision gathering carries no source manifest")
  (let ((facts (result-facts result)))
    (check (= 1 (length facts))
           "revision gathering produces exactly one fact")
    (check (eql :repository-revision (fact-kind (first facts)))
           "revision fact carries the repository-revision kind")
    (check (equal revision (fact-fingerprint (first facts)))
           "revision fact fingerprint is the revision")
    (check (eql :current (fact-state (first facts)))
           "revision fact is current")))

(let ((result (gather-evidence
               (make-request :command :repository-revision)
               (one-ports-fake
                (list (list :return 1 "not a repository"
                            "fatal: not a git repository"))))))
  (check (eq :complete (result-status result))
         "revision failure still completes the bundle")
  (let ((facts (result-facts result)))
    (check (eql :unverifiable (fact-state (first facts)))
           "failed revision evidence is unverifiable")
    (check (equal "unavailable" (fact-fingerprint (first facts)))
           "failed revision evidence carries a stable fingerprint")))

(dolist (text (list (fixture-text "rev-parse-malformed.txt")
                    "ABCDEFABCDEFABCDEFABCDEFABCDEFABCDEFABCDEF"))
  (let ((result (gather-evidence
                 (make-request :command :repository-revision)
                 (one-ports-fake
                  (list (list :return 0 text ""))))))
    (check (eq :refused (result-status result))
           "malformed revision output fails closed with a refusal")
    (check (equal '("malformed-output") (result-refusals result))
           "malformed revision output names the closed refusal")
    (check (null (result-facts result))
           "refused revision bundle carries no facts")
    (check (null (result-manifest result))
           "refused revision bundle carries no manifest")))

;;; :working-tree-status -----------------------------------------------------

(let* ((status (string-right-trim '(#\Newline)
                                   (fixture-text "status-dirty.txt")))
       (result (gather-evidence
                (make-request :command :working-tree-status)
                (one-ports-fake
                 (list (list :return 0
                             (fixture-text "status-dirty.txt")
                             ""))))))
  (check (eq :complete (result-status result))
         "dirty status fixture completes")
  (let ((facts (result-facts result)))
    (check (= 1 (length facts))
           "status gathering produces exactly one fact")
    (check (eql :working-tree-status (fact-kind (first facts)))
           "status fact carries the working-tree-status kind")
    (check (equal status (fact-fingerprint (first facts)))
           "status fingerprint is the canonical porcelain output")
    (check (eql :current (fact-state (first facts)))
           "status fact is current")))

(let ((result (gather-evidence
               (make-request :command :working-tree-status)
               (one-ports-fake
                (list (list :return 0
                            (fixture-text "status-clean.txt")
                            ""))))))
  (check (equal "clean" (fact-fingerprint (first (result-facts result))))
         "empty status output carries the clean fingerprint")
  (check (eql :current (fact-state (first (result-facts result))))
         "clean tree evidence is current"))

(let ((result (gather-evidence
               (make-request :command :working-tree-status)
               (one-ports-fake
                (list (list :return 0
                            (fixture-text "status-malformed.txt")
                            ""))))))
  (check (eq :refused (result-status result))
         "malformed status line refuses the bundle")
  (check (equal '("malformed-output") (result-refusals result))
         "malformed status names the closed refusal"))

;;; :file-sha256 --------------------------------------------------------

(let* ((target "src/a.lisp")
       (digest (subseq (fixture-text "sha256-valid.txt") 0 64))
       (result (gather-evidence
                (make-request :command :file-sha256
                              :targets (list target)
                              :source-role "source")
                (one-ports-fake
                 (list (list :return 0
                             (fixture-text "sha256-valid.txt")
                             ""))))))
  (check (eq :complete (result-status result))
         "hash fixture completes")
  (let ((facts (result-facts result)))
    (check (= 1 (length facts))
           "hash gathering produces one fact")
    (check (eql :content-hash (fact-kind (first facts)))
           "hash fact carries the content-hash kind")
    (check (equal digest (fact-fingerprint (first facts)))
           "hash fact fingerprint is the digest")
    (check (eql :current (fact-state (first facts)))
           "hash fact is current"))
  (let ((manifest (result-manifest result)))
    (check (= 1 (length manifest))
           "hash gathering produces one manifest entry")
    (check (equal target
                  (hngh.domain:source-manifest-entry-relative-path
                   (first manifest)))
           "manifest entry names the hashed path")
    (check (equal digest
                (hngh.domain:source-manifest-entry-content-hash
                 (first manifest)))
           "manifest entry carries the digest")
    (check (equal "source"
                (hngh.domain:source-manifest-entry-source-role
                 (first manifest)))
           "manifest entry carries the source role")))

(let* ((result (gather-evidence
                (make-request :command :file-sha256
                              :targets '("src/a.lisp" "src/b.lisp")
                              :source-role "test")
                (one-ports-fake
                 (list (list :return 0 (fixture-text "sha256-valid.txt") "")
                       (list :return 0
                             (format nil "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb  src/b.lisp~%")
                             ""))))))
  (check (eq :complete (result-status result))
         "multi-target hash gathering completes")
  (check (= 2 (length (result-facts result)))
         "one fact per hashed target")
  (check (= 2 (length (result-manifest result)))
         "one manifest entry per hashed target")
  (check (equal '("src/a.lisp" "src/b.lisp")
                (mapcar #'hngh.domain:source-manifest-entry-relative-path
                        (result-manifest result)))
         "manifest entries keep target order")
  (check (every (lambda (entry)
                  (equal "test"
                         (hngh.domain:source-manifest-entry-source-role entry)))
                (result-manifest result))
         "manifest entries carry the request role"))

(let ((result (gather-evidence
               (make-request :command :file-sha256
                             :targets '("nope.txt")
                             :source-role "source")
               (one-ports-fake
                (list (list :return 1 ""
                            "sha256sum: nope.txt: No such file or directory"))))))
  (check (eq :complete (result-status result))
         "missing file still completes the bundle")
  (check (eql :missing (fact-state (first (result-facts result))))
         "missing file evidence is recorded as missing")
  (check (equal "nope.txt" (fact-fingerprint (first (result-facts result))))
         "missing file fact keeps its target identity")
  (check (null (result-manifest result))
         "missing file produces no manifest entry"))

(let ((result (gather-evidence
               (make-request :command :file-sha256
                             :targets '("locked.txt")
                             :source-role "source")
               (one-ports-fake
                (list (list :return 1 ""
                            "sha256sum: locked.txt: Permission denied"))))))
  (check (eql :unverifiable (fact-state (first (result-facts result))))
         "unreadable file evidence is unverifiable"))

(let ((result (gather-evidence
               (make-request :command :file-sha256
                             :targets '("src/a.lisp")
                             :source-role "source")
               (one-ports-fake
                (list (list :return 0
                            (fixture-text "sha256-malformed.txt")
                            ""))))))
  (check (eq :refused (result-status result))
         "malformed hash output fails closed")
  (check (equal '("malformed-output") (result-refusals result))
         "malformed hash output names the closed refusal"))

(let* ((valid (fixture-text "sha256-valid.txt"))
       (malformed (fixture-text "sha256-malformed.txt"))
       (result (gather-evidence
                (make-request :command :file-sha256
                              :targets '("src/a.lisp" "src/b.lisp")
                              :source-role "source")
                (one-ports-fake
                 (list (list :return 0 valid "")
                       (list :return 0 malformed ""))))))
  (check (eq :refused (result-status result))
         "any malformed target output refuses the whole bundle")
  (check (null (result-facts result))
         "refused bundle carries no partial facts")
  (check (null (result-manifest result))
         "refused bundle carries no partial manifest"))

;;; Transport faults ---------------------------------------------------------

(let ((result (gather-evidence
               (make-request :command :repository-revision)
               (one-ports-fake
                (list (list :error "injected transport explosion"))))))
  (check (eq :refused (result-status result))
         "a thrown transport fault fails closed")
  (check (equal '("transport-fault") (result-refusals result))
         "thrown transport faults name the closed refusal"))

(dolist (runner (list (lambda (argv)
                        (declare (ignore argv))
                        (values "0" "out" "err"))
                      (lambda (argv)
                        (declare (ignore argv))
                        (values 0 "out"))))
  (let ((result (gather-evidence (make-request :command :repository-revision)
                                 (make-ports runner))))
    (check (eq :refused (result-status result))
           "a malformed transport return fails closed")
    (check (equal '("transport-fault") (result-refusals result))
           "malformed transport returns name the transport refusal")))

;;; Defensive copies -----------------------------------------------------

(let ((request (make-request :command :file-sha256
                             :targets '("src/a.lisp")
                             :source-role "source")))
  (let ((targets (request-targets request)))
    (setf (first targets) "replaced")
    (check (equal '("src/a.lisp") (request-targets request))
           "request targets are defensive copies")))

(let ((result (gather-evidence
               (make-request :command :file-sha256
                             :targets '("src/a.lisp")
                             :source-role "source")
               (one-ports-fake
                (list (list :return 0
                            (fixture-text "sha256-valid.txt")
                            ""))))))
  (let ((facts (result-facts result)))
    (setf (first facts) nil)
    (check (= 1 (length (result-facts result)))
           "result facts are defensive copies")))

(let ((result (gather-evidence
               (make-request :command :repository-revision)
               (one-ports-fake
                (list (list :return 0
                            (fixture-text "rev-parse-malformed.txt")
                            ""))))))
  (let ((refusals (result-refusals result)))
    (setf (first refusals) "replaced")
    (check (equal '("malformed-output") (result-refusals result))
           "result refusals are defensive copies")))

;;; The concrete transport is exported, never executed in tests -----------

(check (fboundp (adapter-symbol "PROCESS-RUN"))
       "the real process transport is exported for composition")

;;; Dependency direction -------------------------------------------------

(defun source-text (relative)
  (with-open-file (stream (cl-user::project-file relative)
                          :direction :input :if-does-not-exist :error)
    (let ((buffer (make-string (file-length stream))))
      (subseq buffer 0 (read-sequence buffer stream)))))

(defun inward-source-clean-p (directory)
  (loop for file in (directory (merge-pathnames "*.lisp" directory))
        for text = (source-text file)
        always (and (not (search "hngh.adapters" text))
                    (not (search "hngh.presentation" text)))))

(check (inward-source-clean-p (cl-user::project-file "src/domain/"))
       "domain sources never import an adapter or presentation package")
(check (inward-source-clean-p (cl-user::project-file "src/application/"))
       "application sources never import an adapter or presentation package")

(let ((adapter-text (source-text "src/adapter/evidence.lisp")))
  (check (not (search "hngh.application" adapter-text))
         "adapter never references the application package")
  (check (not (search "hngh.presentation" adapter-text))
         "adapter never references the presentation package"))