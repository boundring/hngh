(in-package :hngh.tests)

;;; Real candidate-evidence adapter: closed-report parsing and
;;; fail-closed gathering through an injectable process transport.

(defparameter +gr-base+ "0123456789abcdef0123456789abcdef01234567")
(defparameter +gr-hash+ (make-string 64 :initial-element #\a))

(defun gr-call (symbol &rest args)
  "Call a run-gather package function by symbol name, tolerating a
non-exported symbol."
  (apply (symbol-function
          (find-symbol symbol "HNGH.ADAPTERS.RUN-GATHER"))
         args))

(defun gr-report (&key (base +gr-base+) (hash +gr-hash+)
                   (manifest '("candidate.lisp" "src/other.lisp"))
                   (refused nil))
  (format nil "base-revision:~A~%candidate-hash:~A~%working-tree-dirty:yes~%working-tree-staged:no~%working-tree-untracked:no~%parenthesis-guard:passed~%~{manifest:~A~%~}~A~%"
          base hash manifest (if refused ":refused" ":passed")))

(defun gr-parser (text)
  (gr-call "PARSE-CANDIDATE-REPORT" text))

(defun gr-ports (&optional (out (gr-report)) (exit 0) (err ""))
  "A fixture process transport: git identity, sha256 digests, and the
given verify-candidate output."
  (gr-call "MAKE-CANDIDATE-GATHER-PORTS"
           :process-run
           (lambda (cwd argv)
             (declare (ignore cwd))
             (cond ((string= (first argv) "git")
                    (values 0 (format nil "https://example.invalid/repo~%") ""))
                   ((and (third argv) (search "hashlib" (third argv)))
                    (values 0 (format nil "~A~%" +gr-hash+) ""))
                   (t (values exit out err))))))

;;; Closed report parsing -----------------------------------------------------

(let ((report (gr-parser (gr-report))))
  (check (listp report) "a passed closed report parses")
  (check (string= +gr-base+ (getf report :base-revision))
         "report carries the base revision")
  (check (string= +gr-hash+ (getf report :candidate-hash))
         "report carries the candidate hash")
  (check (eq t (getf report :working-tree-dirty))
         "dirty flag parses")
  (check (eq nil (getf report :working-tree-staged))
         "staged flag parses")
  (check (equal '("candidate.lisp" "src/other.lisp")
                (getf report :manifest))
         "manifest paths parse in order"))

(dolist (text (list ""
                    (gr-report :refused t)
                    (gr-report :hash "not-hex")
                    "garbage"))
  (check (null (gr-parser text))
         "a refused, un-terminated, or malformed report parses to NIL"))

;;; Fail-closed gathering -----------------------------------------------------

(multiple-value-bind (evidence label)
    (gr-call "RUN-CANDIDATE-EVIDENCE" nil "/tmp" (gr-ports))
  (check (null evidence) "nil candidate paths refuse")
  (check (string= "malformed candidate paths" label)
         "nil candidate paths name the refusal"))

(multiple-value-bind (evidence label)
    (gr-call "RUN-CANDIDATE-EVIDENCE" '("candidate.lisp") "/tmp"
             (gr-ports (format nil ":refused verify-candidate broken~%") 1))
  (check (null evidence) "a refused report refuses evidence")
  (check (string= "verify-candidate broken" label)
         "the refused report label surfaces"))

(multiple-value-bind (evidence label)
    (gr-call "RUN-CANDIDATE-EVIDENCE" '("candidate.lisp") "/tmp"
             (gr-ports "garbage"))
  (check (null evidence) "malformed verify output refuses evidence")
  (check (string= "malformed candidate evidence" label)
         "malformed output names the closed refusal"))

(multiple-value-bind (evidence label)
    (gr-call "RUN-CANDIDATE-EVIDENCE" '("candidate.lisp") "/tmp"
             (gr-ports "" 1))
  (check (null evidence) "a failed verify run refuses evidence")
  (check (string= "verify-candidate failed" label)
         "verify failure names the closed refusal"))

;;; Genuine evidence assembly -------------------------------------------------

(let ((evidence
        (gr-call "RUN-CANDIDATE-EVIDENCE" '("src/other.lisp" "candidate.lisp")
                 "/tmp" (gr-ports))))
  (check (listp evidence) "real evidence gathers through fake ports")
  (check (string= "https://example.invalid/repo"
                  (getf evidence :repository-identity))
         "repository identity is the origin remote")
  (check (string= +gr-base+ (getf evidence :base-revision))
         "evidence names the base revision")
  (check (equal '("candidate.lisp" "src/other.lisp")
                (getf evidence :candidate-paths))
         "candidate paths are sorted")
  (check (string= +gr-hash+ (getf evidence :content-hash))
         "evidence carries the candidate content hash")
  (check (equal (list +gr-hash+) (getf evidence :evidence-hashes))
         "evidence hashes list the candidate hash")
  (check (equal '(:dirty t :staged nil :untracked nil)
                (getf evidence :working-tree-state))
         "evidence carries the working tree state")
  (check (= 2 (length (getf evidence :source-manifest)))
         "evidence carries one manifest entry per candidate")
  (check (string= "candidate"
                  (hngh.domain:source-manifest-entry-source-role
                   (first (getf evidence :source-manifest))))
         "manifest entries carry the candidate role"))