(in-package #:hngh.adapters.evidence)

;;; Rung 4: read-only evidence adapter. The adapter gathers fixed local
;;; evidence (repository revision, working-tree status, file content
;;; hashes) through an injected process transport and maps the results to
;;; domain evidence facts and source manifest entries with closed states.
;;; All subprocess access sits behind the transport callback; the real
;;; transport is `process-run`, supplied explicitly at composition. The
;;; adapter never decides policy: it only records what the fixed commands
;;; report, and it fails closed on anything unknown, malformed, duplicate,
;;; or unauthorized. No caller-supplied command string is ever executed.

(defparameter +evidence-commands+
  '(:repository-revision :working-tree-status :file-sha256)
  "The fixed, enumerable read-only evidence command set. A request names
one command; the adapter resolves the exact argv itself.")

;;; Paths -------------------------------------------------------------------

(defun path-components (path)
  (loop with components = '()
        for start = 0 then (1+ end)
        for end = (or (position #\/ path :start start) (length path))
        do (push (subseq path start end) components)
        while (< end (length path))
        finally (return (nreverse components))))

(defun validate-evidence-path (path)
  (unless (and (stringp path)
               (plusp (length path))
               (not (find #\\ path)))
    (error "evidence path must be a nonempty relative string"))
  (let ((first-char (char path 0)))
    (when (or (char= first-char #\-) (char= first-char #\/)
              (char= first-char #\~))
      (error "evidence path must not be absolute, home-relative, or an option")))
  (loop for char across path
        when (or (char< char #\Space) (char= char (code-char 127)))
          do (error "evidence path must not contain control characters"))
  (dolist (component (path-components path))
    (when (member component '("" "." "..") :test #'string=)
      (error "evidence path must be a plain relative path without dot components")))
  path)

;;; Request ----------------------------------------------------------

(defstruct (evidence-request
            (:constructor %make-evidence-request
                (command targets source-role))
            (:conc-name %evidence-request-))
  (command nil :read-only t)
  (targets nil :read-only t)
  (source-role nil :read-only t))

(defun evidence-request-command (request)
  (%evidence-request-command request))

(defun evidence-request-targets (request)
  (copy-list (%evidence-request-targets request)))

(defun evidence-request-source-role (request)
  (let ((role (%evidence-request-source-role request)))
    (if role (copy-seq role) nil)))

(defun make-evidence-request (&key command (targets nil) (source-role nil))
  (unless (member command +evidence-commands+)
    (error "unknown evidence command: ~S" command))
  (if (eq command :file-sha256)
      (progn
        (unless (and (listp targets)
                     targets
                     (every #'validate-evidence-path targets))
          (error "evidence targets must be a nonempty list of relative paths"))
        (unless (= (length targets)
                   (length (remove-duplicates targets :test #'string=)))
          (error "evidence targets must be duplicate free"))
        (unless (and (stringp source-role) (plusp (length source-role)))
          (error "source role must be a nonempty string"))
        (%make-evidence-request command (copy-list targets)
                                (copy-seq source-role)))
      (progn
        (when targets
          (error "evidence targets are only admitted for :file-sha256"))
        (when source-role
          (error "source role is only admitted for :file-sha256"))
        (%make-evidence-request command nil nil))))

;;; Transport port ---------------------------------------------------

(defstruct (evidence-ports
            (:constructor %make-evidence-ports (run-process))
            (:conc-name %evidence-ports-))
  (run-process nil :read-only t))

(defun make-evidence-ports (&key run-process)
  (unless (functionp run-process)
    (error "evidence ports require a run-process callback"))
  (%make-evidence-ports run-process))

(defun transport-response (ports argv)
  "Invoke the transport callback. Returns (values t exit-code stdout stderr)
or (values nil nil nil nil) for a thrown error or a malformed return."
  (handler-case
      (multiple-value-bind (exit-code stdout stderr)
          (funcall (%evidence-ports-run-process ports) argv)
        (if (and (integerp exit-code)
                 (not (minusp exit-code))
                 (stringp stdout)
                 (stringp stderr))
            (values t exit-code stdout stderr)
            (values nil nil nil nil)))
    (error () (values nil nil nil nil))))

;;; Result -----------------------------------------------------------

(defstruct (evidence-result
            (:constructor %make-evidence-result
                (status facts manifest refusal-labels))
            (:conc-name %evidence-result-))
  (status nil :read-only t)
  (facts nil :read-only t)
  (manifest nil :read-only t)
  (refusal-labels nil :read-only t))

(defun evidence-result-status (result)
  (%evidence-result-status result))

(defun evidence-result-facts (result)
  (copy-list (%evidence-result-facts result)))

(defun evidence-result-manifest (result)
  (copy-list (%evidence-result-manifest result)))

(defun evidence-result-refusal-labels (result)
  (copy-list (%evidence-result-refusal-labels result)))

(defun complete-evidence (facts manifest)
  (%make-evidence-result :complete facts manifest nil))

(defun refused-evidence (labels)
  (%make-evidence-result :refused nil nil labels))

;;; Parsing helpers --------------------------------------------------

(defun trimmed (text)
  (string-right-trim '(#\Newline #\Return) text))

(defun hex-digit-p (char)
  (find char "0123456789abcdef"))

(defun revision-p (text)
  (and (<= 40 (length text) 64)
       (every #'hex-digit-p text)))

(defun porcelain-line-p (line)
  (and (>= (length line) 4)
       (every (lambda (char) (find char " MADRCU?"))
              (list (char line 0) (char line 1)))
       (char= (char line 2) #\Space)))

(defun split-sequence (text delimiter)
  (loop for start = 0 then (1+ end)
        for end = (or (position delimiter text :start start) (length text))
        collect (subseq text start end)
        while (< end (length text))))

(defun porcelain-lines (text)
  (remove "" (split-sequence text #\Newline) :test #'string=))

(defun hex64-p (text)
  (and (= 64 (length text)) (every #'hex-digit-p text)))

(defun sha256-line-p (line target)
  (and (>= (length line) 66)
       (hex64-p (subseq line 0 64))
       (string= "  " line :start2 64 :end2 66)
       (string= target line :start2 66)))

(defun hash-digest-of (line)
  (subseq line 0 64))

(defun file-absent-error-p (stderr)
  (or (search "No such file" stderr)
      (search "cannot open" stderr)))

;;; Command gathering -------------------------------------------------

(defun fact-with (kind fingerprint state)
  (hngh.domain:make-evidence-fact
   :kind kind :fingerprint fingerprint :state state))

(defun gather-repository-revision (request ports)
  (declare (ignore request))
  (multiple-value-bind (ok exit-code stdout stderr)
      (transport-response ports '("git" "rev-parse" "HEAD"))
    (declare (ignore stderr))
    (cond
      ((not ok) (refused-evidence '("transport-fault")))
      ((not (zerop exit-code))
       (complete-evidence
        (list (fact-with :repository-revision "unavailable" :unverifiable))
        nil))
      (t (let ((revision (trimmed stdout)))
           (if (revision-p revision)
               (complete-evidence
                (list (fact-with :repository-revision revision :current))
                nil)
               (refused-evidence '("malformed-output"))))))))

(defun gather-working-tree-status (request ports)
  (declare (ignore request))
  (multiple-value-bind (ok exit-code stdout stderr)
      (transport-response
       ports '("git" "status" "--porcelain=v1" "--untracked-files=all"))
    (declare (ignore stderr))
    (cond
      ((not ok) (refused-evidence '("transport-fault")))
      ((not (zerop exit-code))
       (complete-evidence
        (list (fact-with :working-tree-status "unavailable" :unverifiable))
        nil))
      (t (unless (every #'porcelain-line-p (porcelain-lines stdout))
           (return-from gather-working-tree-status
             (refused-evidence '("malformed-output"))))
         (let ((text (trimmed stdout)))
           (complete-evidence
            (list (fact-with :working-tree-status
                             (if (zerop (length text)) "clean" text)
                             :current))
            nil))))))

(defun gather-file-hashes (request ports)
  (let ((facts '())
        (manifest '()))
    (dolist (target (evidence-request-targets request))
      (multiple-value-bind (ok exit-code stdout stderr)
          (transport-response ports (list "sha256sum" target))
        (cond
          ((not ok)
           (return-from gather-file-hashes
             (refused-evidence '("transport-fault"))))
          ((not (zerop exit-code))
           (push (if (file-absent-error-p stderr)
                     (fact-with :content-hash target :missing)
                     (fact-with :content-hash target :unverifiable))
                 facts))
          (t (let ((line (trimmed stdout)))
               (unless (sha256-line-p line target)
                 (return-from gather-file-hashes
                   (refused-evidence '("malformed-output"))))
               (let ((digest (hash-digest-of line)))
                 (push (fact-with :content-hash digest :current) facts)
                 (push (hngh.domain:make-source-manifest-entry
                        :relative-path target
                        :content-hash digest
                        :source-role (evidence-request-source-role request))
                       manifest)))))))
    (complete-evidence (nreverse facts) (nreverse manifest))))

;;; Entry point ------------------------------------------------------

(defun gather-evidence (request ports)
  (unless (evidence-request-p request)
    (error "gather-evidence requires an evidence request"))
  (unless (evidence-ports-p ports)
    (error "gather-evidence requires evidence ports"))
  (let ((command (evidence-request-command request)))
    (unless (member command +evidence-commands+)
      (error "unknown evidence command: ~S" command))
    (case command
      (:repository-revision (gather-repository-revision request ports))
      (:working-tree-status (gather-working-tree-status request ports))
      (:file-sha256 (gather-file-hashes request ports)))))

;;; Real transport ---------------------------------------------------

(defun process-run (argv)
  "Run ARGV as a read-only subprocess and return (values exit-code stdout
stderr). Signals on launch failure; the gatherer turns that into a closed
transport refusal."
  (multiple-value-bind (stdout stderr exit-code)
      (uiop:run-program argv :output :string :error-output :string
                        :ignore-error-status t)
    (values exit-code stdout stderr)))