;;;; src/adapter/run-gather.lisp
;;;; Real candidate evidence: runs scripts/verify-candidate.py in the
;;;; candidate repository through an injectable process transport,
;;;; parses its closed report, and completes repository identity and
;;;; per-file content hashes. Fails closed: a non-zero exit, a refused
;;;; report, or malformed output yields no evidence.

(in-package #:hngh.adapters.run-gather)

(defun process-run-at (cwd argv)
  "Run ARGV with CWD as the process directory. Returns (values
exit-code stdout stderr); never signals."
  (uiop:run-program argv
                    :directory cwd
                    :output :string :error-output :string
                    :ignore-error-status t))

(defun trimmed (text)
  (string-right-trim '(#\Newline #\Return) text))

(defun hex-digit-p (char)
  (find char "0123456789abcdef"))

(defun revision-p (text)
  (and (<= 40 (length text) 64)
       (every #'hex-digit-p text)))

(defun hex64-p (text)
  (and (= 64 (length text)) (every #'hex-digit-p text)))

(defstruct (candidate-gather-ports (:constructor %make-candidate-gather-ports))
  (process-run nil :type (or null function)))

(defun make-candidate-gather-ports (&key process-run)
  "The real candidate-evidence transport. PROCESS-RUN is called as
(PROCESS-RUN CWD ARGV) and must return (values exit-code stdout
stderr). NIL falls back to real subprocesses."
  (unless (or (null process-run) (functionp process-run))
    (error "process-run must be a function"))
  (%make-candidate-gather-ports :process-run process-run))

(defun %process-run (ports)
  (or (and ports (candidate-gather-ports-process-run ports)) #'process-run-at))

(defun %sha256-file-hex (run cwd path)
  "sha256 of PATH's bytes through python3; NIL when unavailable."
  (multiple-value-bind (exit stdout stderr)
      (funcall run cwd
               (list "python3" "-c"
                     "import hashlib,sys;print(hashlib.sha256(open(sys.argv[1],'rb').read()).hexdigest())"
                     (uiop:native-namestring path)))
    (declare (ignorable stderr))
    (when (and exit (zerop exit) stdout)
      (let ((hex (trimmed stdout)))
        (and (hex64-p hex) hex)))))

(defun %first-line (text)
  (let ((end (position #\Newline text)))
    (if end (subseq text 0 end) text)))

(defun %refused-line (stdout stderr)
  "The first ':refused ...' label in STDOUT or STDERR, sans the prefix."
  (let ((text (concatenate 'string (or stdout "") (or stderr ""))))
    (loop for line in (uiop:split-string text :separator '(#\Newline))
          for cleaned = (string-right-trim '(#\Return) line)
          for at = (search ":refused" cleaned)
          when at
            do (let ((rest (subseq cleaned (+ at (length ":refused")))))
                 (when (plusp (length (string-trim '(#\Space #\Tab) rest)))
                   (return-from %refused-line
                     (string-trim '(#\Space #\Tab) rest))))
          finally (return nil))))

(defun %repository-identity (cwd run)
  "The origin remote URL, else the absolute git dir; NIL when git is
unavailable."
  (multiple-value-bind (exit stdout stderr)
      (funcall run cwd '("git" "remote" "get-url" "origin"))
    (declare (ignorable stderr))
    (when (and exit (zerop exit))
      (let ((url (%first-line (or stdout ""))))
        (when (plusp (length (string-trim '(#\Space) url)))
          (return-from %repository-identity url))))
    (multiple-value-bind (exit2 stdout2 stderr2)
        (funcall run cwd '("git" "rev-parse" "--absolute-git-dir"))
      (declare (ignorable stderr2))
      (when (and exit2 (zerop exit2))
        (let ((dir (%first-line (or stdout2 ""))))
          (when (plusp (length (trimmed dir)))
            (return-from %repository-identity (trimmed dir))))))
    nil))

(defun %manifest-text (candidate-paths)
  "One sorted candidate path per line."
  (format nil "~{~A~%~}" (sort (copy-list candidate-paths) #'string<)))

(defun parse-candidate-report (text)
  "Parse the closed report of scripts/verify-candidate.py. A report is
accepted only when it terminates with ':passed' and carries a
base-revision and a 64-hex candidate-hash. Returns (:base-revision
:working-tree-dirty :working-tree-staged :working-tree-untracked
:parenthesis-guard :candidate-hash :manifest) or NIL."
  (let ((passed nil) (refused nil)
        (base nil) (hash nil)
        (dirty nil) (staged nil) (untracked nil) (parens nil)
        (manifest '()))
    (dolist (line (uiop:split-string text :separator '(#\Newline)))
      (when (and line (plusp (length (string-trim '(#\Space) line))))
        (let ((colon (position #\: line)))
          (cond
            ((null colon) nil)
            ((zerop colon)
             (let ((marker (string-trim '(#\Space) (subseq line 1))))
               (cond ((string= marker "passed") (setf passed t))
                     ((string= marker "refused") (setf refused t))
                     (t nil))))
            ((plusp colon)
             (let ((key (string-trim '(#\Space) (subseq line 0 colon)))
                   (value (string-trim '(#\Space) (subseq line (1+ colon)))))
               (cond ((string= key "base-revision") (when (revision-p value) (setf base value)))
                     ((string= key "candidate-hash") (when (hex64-p value) (setf hash value)))
                     ((string= key "working-tree-dirty") (setf dirty (string= value "yes")))
                     ((string= key "working-tree-staged") (setf staged (string= value "yes")))
                     ((string= key "working-tree-untracked") (setf untracked (string= value "yes")))
                     ((string= key "parenthesis-guard") (setf parens (string= value "passed")))
                     ((string= key "manifest") (push value manifest)))))))))
    (when (and passed (not refused) base hash)
      (list :base-revision base
            :working-tree-dirty dirty
            :working-tree-staged staged
            :working-tree-untracked untracked
            :parenthesis-guard parens
            :candidate-hash hash
            :manifest (nreverse manifest)))))

(defun run-candidate-evidence (candidate-paths cwd &optional ports)
  "Gather genuine candidate evidence for CANDIDATE-PATHS under CWD
through PORTS (a candidate-gather-ports or NIL for real subprocesses).
Returns (values evidence refusal-label): EVIDENCE is (:repository-identity
:base-revision :candidate-paths :content-hash :evidence-hashes
:working-tree-state :source-manifest). Refuses (NIL label) on
subprocess failure, a refused report, or malformed output."
  (unless (and (listp candidate-paths) (every #'stringp candidate-paths)
               candidate-paths)
    (return-from run-candidate-evidence (values nil "malformed candidate paths")))
  (let* ((run (%process-run ports))
         (cwd (or (and cwd (uiop:ensure-directory-pathname cwd)) (uiop:getcwd))))
    (handler-case
        (let ((manifest (uiop:with-temporary-file (:pathname path :keep t)
                          (with-open-file (stream path :direction :output
                                                  :if-exists :supersede)
                            (write-string (%manifest-text candidate-paths) stream))
                          path)))
          (unwind-protect
               (multiple-value-bind (exit stdout stderr)
                   (funcall run cwd
                            (list "python3" "scripts/verify-candidate.py"
                                  "--manifest" (uiop:native-namestring manifest)))
                 (cond
                   ((and exit (zerop exit))
                    (let ((report (parse-candidate-report
                                   (concatenate 'string (or stdout "") (or stderr "")))))
                      (unless report
                        (return-from run-candidate-evidence
                          (values nil "malformed candidate evidence")))
                      (let ((identity (%repository-identity cwd run)))
                        (unless identity
                          (return-from run-candidate-evidence
                            (values nil "unavailable repository identity")))
                        (let ((hash (getf report :candidate-hash)))
                          (dolist (path (getf report :manifest))
                            (unless (%sha256-file-hex run cwd
                                                      (merge-pathnames path cwd))
                              (return-from run-candidate-evidence
                                (values nil "unavailable file hash"))))
                          (values
                           (list :repository-identity identity
                                 :base-revision (getf report :base-revision)
                                 :candidate-paths (sort (copy-list (getf report :manifest)) #'string<)
                                 :content-hash hash
                                 :evidence-hashes (list hash)
                                 :working-tree-state
                                 (list :dirty (getf report :working-tree-dirty)
                                       :staged (getf report :working-tree-staged)
                                       :untracked (getf report :working-tree-untracked))
                                 :source-manifest
                                 (mapcar (lambda (path)
                                           (hngh.domain:make-source-manifest-entry
                                            :relative-path path
                                            :content-hash
                                            (%sha256-file-hex run cwd (merge-pathnames path cwd))
                                            :source-role "candidate"))
                                         (getf report :manifest)))
                           nil)))))
                   (t (values nil (or (%refused-line stdout stderr)
                                      "verify-candidate failed")))))
            (ignore-errors (delete-file manifest))))
      (error ()
        (values nil "verify-candidate failed")))))