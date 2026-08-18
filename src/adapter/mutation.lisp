(in-package #:hngh.adapters.mutation)

;;; Rung 5: one-action mutation executor. Every value needed for admission is
;;; supplied as immutable evidence and rechecked before the fixed command is
;;; sent to the injected process transport. This adapter never invokes a
;;; shell, chooses policy, or supplies a default transport.

(defparameter +mutation-actions+
  '(:none :prepare-candidate :stage :commit :push))

;;; Evidence ---------------------------------------------------------------

(defstruct (mutation-evidence
            (:constructor %make-mutation-evidence
                (repository-identity base-revision candidate-paths content-hash
                 evidence-hashes principle-verdicts review-findings source-manifest
                 policy-profile now))
            (:conc-name %mutation-evidence-))
  (repository-identity nil :read-only t)
  (base-revision nil :read-only t)
  (candidate-paths nil :read-only t)
  (content-hash nil :read-only t)
  (evidence-hashes nil :read-only t)
  (principle-verdicts nil :read-only t)
  (review-findings nil :read-only t)
  (source-manifest nil :read-only t)
  (policy-profile nil :read-only t)
  (now nil :read-only t))

(defun mutation-evidence-repository-identity (evidence)
  (copy-seq (%mutation-evidence-repository-identity evidence)))

(defun mutation-evidence-base-revision (evidence)
  (copy-seq (%mutation-evidence-base-revision evidence)))

(defun mutation-evidence-candidate-paths (evidence)
  (mapcar #'copy-seq (%mutation-evidence-candidate-paths evidence)))

(defun mutation-evidence-content-hash (evidence)
  (copy-seq (%mutation-evidence-content-hash evidence)))

(defun mutation-evidence-evidence-hashes (evidence)
  (mapcar #'copy-seq (%mutation-evidence-evidence-hashes evidence)))

(defun mutation-evidence-principle-verdicts (evidence)
  (copy-list (%mutation-evidence-principle-verdicts evidence)))

(defun mutation-evidence-review-findings (evidence)
  (mapcar #'copy-seq (%mutation-evidence-review-findings evidence)))

(defun mutation-evidence-source-manifest (evidence)
  (copy-list (%mutation-evidence-source-manifest evidence)))

(defun mutation-evidence-policy-profile (evidence)
  (copy-seq (%mutation-evidence-policy-profile evidence)))

(defun mutation-evidence-now (evidence)
  (copy-seq (%mutation-evidence-now evidence)))

(defun nonempty-string-p (value)
  (and (stringp value) (plusp (length value))))

(defun duplicate-free-strings-p (values)
  (= (length values)
     (length (remove-duplicates values :test #'string=))))

(defun ensure-optional-string (value name)
  (unless (or (null value) (nonempty-string-p value))
    (error "~A must be a nonempty string when supplied" name))
  (and value (copy-seq value)))

(defun ensure-string-list (value name)
  (unless (and (listp value) (every #'nonempty-string-p value)
               (duplicate-free-strings-p value))
    (error "~A must be a duplicate-free list of nonempty strings" name))
  (mapcar #'copy-seq value))

(defun path-components (path)
  (loop with components = '()
        for start = 0 then (1+ end)
        for end = (or (position #\/ path :start start) (length path))
        do (push (subseq path start end) components)
        while (< end (length path))
        finally (return (nreverse components))))

(defun safe-relative-path-p (path)
  (and (nonempty-string-p path)
       (not (find #\\ path))
       (let ((first-char (char path 0)))
         (not (or (char= first-char #\-)
                  (char= first-char #\/)
                  (char= first-char #\~))))
       (notany (lambda (char)
                 (or (char< char #\Space) (char= char (code-char 127))))
               path)
       (notany (lambda (component)
                 (member component '("" "." "..") :test #'string=))
               (path-components path))))

(defun ensure-path-list (value name)
  (let ((paths (ensure-string-list value name)))
    (unless (every #'safe-relative-path-p paths)
      (error "~A must contain only safe repository-relative paths" name))
    paths))

(defun ensure-manifest-list (value)
  (unless (and (listp value)
               (every #'hngh.domain:source-manifest-entry-p value))
    (error "Source manifest must be a list of source manifest entries"))
  (dolist (entry value)
    (unless (safe-relative-path-p
             (hngh.domain:source-manifest-entry-relative-path entry))
      (error "Source manifest contains an unsafe path")))
  (unless (= (length value)
             (length (remove-duplicates
                      value :test #'string=
                      :key #'hngh.domain:source-manifest-entry-relative-path)))
    (error "Source manifest must be duplicate free"))
  (copy-list value))

(defun make-mutation-evidence
    (&key repository-identity base-revision candidate-paths content-hash
       evidence-hashes principle-verdicts review-findings source-manifest
       policy-profile now)
  (%make-mutation-evidence
   (ensure-optional-string repository-identity "repository identity")
   (ensure-optional-string base-revision "base revision")
   (ensure-path-list candidate-paths "candidate paths")
   (ensure-optional-string content-hash "content hash")
   (ensure-string-list evidence-hashes "evidence hashes")
   (progn
     (unless (and (listp principle-verdicts)
                  (every #'hngh.domain:policy-verdict-p principle-verdicts)
                  (= (length principle-verdicts)
                     (length (remove-duplicates principle-verdicts :test #'eq))))
       (error "Principle verdicts must be a duplicate-free list of policy verdicts"))
     (copy-list principle-verdicts))
   (ensure-string-list review-findings "review findings")
   (ensure-manifest-list source-manifest)
   (ensure-optional-string policy-profile "policy profile")
   (ensure-optional-string now "current time")))

;;; Transport ---------------------------------------------------------------

(defstruct (mutation-ports
            (:constructor %make-mutation-ports (run-process gather-evidence))
            (:conc-name %mutation-ports-))
  (run-process nil :read-only t)
  (gather-evidence nil :read-only t))

(defun make-mutation-ports (&key run-process gather-evidence)
  (unless (functionp run-process)
    (error "mutation ports require a run-process callback"))
  (when (and gather-evidence (not (functionp gather-evidence)))
    (error "mutation gather-evidence must be a function when supplied"))
  (%make-mutation-ports run-process gather-evidence))

;;; Result ------------------------------------------------------------------

(defstruct (mutation-result
            (:constructor %make-mutation-result
                (status action command refusal-labels exit-code stdout stderr))
            (:conc-name %mutation-result-))
  (status nil :read-only t)
  (action nil :read-only t)
  (command nil :read-only t)
  (refusal-labels nil :read-only t)
  (exit-code nil :read-only t)
  (stdout nil :read-only t)
  (stderr nil :read-only t))

(defun mutation-result-status (result)
  (%mutation-result-status result))

(defun mutation-result-action (result)
  (%mutation-result-action result))

(defun copy-command (command)
  (if command
      (mapcar (lambda (argument)
                (if (stringp argument) (copy-seq argument) argument))
              command)
      nil))

(defun mutation-result-command (result)
  (copy-command (%mutation-result-command result)))

(defun mutation-result-refusal-labels (result)
  (mapcar #'copy-seq (%mutation-result-refusal-labels result)))

(defun mutation-result-exit-code (result)
  (%mutation-result-exit-code result))

(defun mutation-result-stdout (result)
  (and (%mutation-result-stdout result)
       (copy-seq (%mutation-result-stdout result))))

(defun mutation-result-stderr (result)
  (and (%mutation-result-stderr result)
       (copy-seq (%mutation-result-stderr result))))

(defun make-result (status &key action command labels exit-code stdout stderr)
  (%make-mutation-result
   status action
   (copy-command command)
   (if labels (mapcar #'copy-seq labels) nil)
   exit-code
   (and stdout (copy-seq stdout))
   (and stderr (copy-seq stderr))))

;;; Comparisons -------------------------------------------------------------

(defun source-manifest-signature (manifest)
  (mapcar (lambda (entry)
            (list (hngh.domain:source-manifest-entry-relative-path entry)
                  (hngh.domain:source-manifest-entry-content-hash entry)
                  (hngh.domain:source-manifest-entry-source-role entry)))
          manifest))

(defun principle-result-signature (result)
  (list (hngh.domain:principle-result-principle result)
        (hngh.domain:principle-result-state result)
        (hngh.domain:principle-result-evidence-fingerprints result)))

(defun verdict-signature (verdict)
  (list (hngh.domain:policy-verdict-state verdict)
        (mapcar #'principle-result-signature
                (hngh.domain:policy-verdict-principle-results verdict))
        (hngh.domain:policy-verdict-reason-labels verdict)))

(defun verdict-list-signature (verdicts)
  (mapcar #'verdict-signature verdicts))

(defun admitted-verdicts-p (verdicts)
  (and (listp verdicts)
       verdicts
       (every (lambda (verdict)
                (and (hngh.domain:policy-verdict-p verdict)
                     (eql :admitted (hngh.domain:policy-verdict-state verdict))
                     (let ((results
                             (hngh.domain:policy-verdict-principle-results
                              verdict)))
                       (and results
                            (every (lambda (result)
                                    (eql :passed
                                         (hngh.domain:principle-result-state
                                          result)))
                                  results)))))
              verdicts)))

(defun digits-in-range-p (value start end)
  (loop for index from start below end
        always (digit-char-p (char value index))))

(defun valid-utc-timestamp-p (value)
  (and (stringp value)
       (let ((length (length value)))
         (and (>= length 20)
              (char= (char value 4) #\-)
              (char= (char value 7) #\-)
              (char= (char value 10) #\T)
              (char= (char value 13) #\:)
              (char= (char value 16) #\:)
              (char= (char value (1- length)) #\Z)
              (digits-in-range-p value 0 4)
              (digits-in-range-p value 5 7)
              (digits-in-range-p value 8 10)
              (digits-in-range-p value 11 13)
              (digits-in-range-p value 14 16)
              (or (= length 20)
                  (and (> length 21)
                       (char= (char value 19) #\.)
                       (digits-in-range-p value 20 (1- length))))))))

(defun mismatch-labels (certificate evidence)
  (let ((labels '()))
    (unless (string= (hngh.domain:candidate-certificate-repository-identity
                      certificate)
                     (or (mutation-evidence-repository-identity evidence) ""))
      (push "repository-identity-mismatch" labels))
    (unless (string= (hngh.domain:candidate-certificate-base-revision certificate)
                     (or (mutation-evidence-base-revision evidence) ""))
      (push "base-revision-mismatch" labels))
    (let ((certificate-paths
            (hngh.domain:candidate-certificate-candidate-paths certificate))
          (evidence-paths (mutation-evidence-candidate-paths evidence)))
      (unless (equal certificate-paths evidence-paths)
        (push "candidate-paths-mismatch" labels))
      (unless (every #'safe-relative-path-p evidence-paths)
        (push "unsafe-candidate-path" labels)))
    (unless (string= (hngh.domain:candidate-certificate-content-hash certificate)
                     (or (mutation-evidence-content-hash evidence) ""))
      (push "content-hash-mismatch" labels))
    (unless (equal (hngh.domain:candidate-certificate-evidence-hashes certificate)
                  (mutation-evidence-evidence-hashes evidence))
      (push "evidence-hashes-mismatch" labels))
    (unless (equal (verdict-list-signature
                    (hngh.domain:candidate-certificate-principle-verdicts
                     certificate))
                   (verdict-list-signature
                    (mutation-evidence-principle-verdicts evidence)))
      (push "principle-verdicts-mismatch" labels))
    (unless (equal (hngh.domain:candidate-certificate-review-findings certificate)
                   (mutation-evidence-review-findings evidence))
      (push "review-findings-mismatch" labels))
    (unless (equal (source-manifest-signature
                    (hngh.domain:candidate-certificate-source-manifest
                     certificate))
                   (source-manifest-signature
                    (mutation-evidence-source-manifest evidence)))
      (push "source-manifest-mismatch" labels))
    (unless (string= (hngh.domain:candidate-certificate-policy-profile certificate)
                     (or (mutation-evidence-policy-profile evidence) ""))
      (push "policy-profile-mismatch" labels))
    (nreverse labels)))

(defun certificate-refusal-labels (certificate evidence)
  (let ((labels '())
        (expiry (hngh.domain:candidate-certificate-expiry certificate))
        (now (and (mutation-evidence-p evidence)
                  (mutation-evidence-now evidence)))
        (certificate-verdicts
          (hngh.domain:candidate-certificate-principle-verdicts certificate))
        (evidence-verdicts
          (and (mutation-evidence-p evidence)
               (mutation-evidence-principle-verdicts evidence))))
    (unless (and (valid-utc-timestamp-p expiry)
                 (valid-utc-timestamp-p now))
      (push "malformed-expiry" labels))
    (when (and (valid-utc-timestamp-p expiry)
               (valid-utc-timestamp-p now)
               (or (string< expiry now) (string= expiry now)))
      (push "expired-certificate" labels))
    (unless (admitted-verdicts-p certificate-verdicts)
      (push "unadmitted-certificate-verdict" labels))
    (unless (admitted-verdicts-p evidence-verdicts)
      (push "missing-principle-verdict" labels))
    (dolist (path (hngh.domain:candidate-certificate-candidate-paths certificate))
      (unless (safe-relative-path-p path)
        (pushnew "unsafe-candidate-path" labels :test #'string=)))
    (nreverse labels)))

(defun transport-response (ports command)
  (handler-case
      (multiple-value-bind (exit-code stdout stderr)
          (funcall (%mutation-ports-run-process ports) command)
        (if (and (integerp exit-code)
                 (not (minusp exit-code))
                 (stringp stdout)
                 (stringp stderr))
            (values t exit-code stdout stderr)
            (values nil nil nil nil)))
    (error () (values nil nil nil nil))))

(defun command-for (certificate)
  (let ((paths (hngh.domain:candidate-certificate-candidate-paths certificate))
        (action (hngh.domain:candidate-certificate-action certificate)))
    (case action
      ((:prepare-candidate :stage)
       (append '("git" "add" "--") paths))
      (:commit
       (append (list "git" "commit" "--message"
                     (format nil "hngh: candidate ~A"
                             (hngh.domain:candidate-certificate-content-hash
                              certificate))
                     "--")
               paths))
      (:push '("git" "push" "origin" "HEAD"))
      (otherwise nil))))

(defun gather-fresh-evidence (certificate ports)
  (let ((gather-evidence (%mutation-ports-gather-evidence ports)))
    (if (functionp gather-evidence)
        (handler-case
            (let ((evidence (funcall gather-evidence certificate)))
              (if (mutation-evidence-p evidence)
                  (values evidence nil)
                  (values nil "malformed-evidence")))
          (error () (values nil "evidence-gather-fault")))
        (values nil "missing-fresh-evidence"))))

;;; Execution ---------------------------------------------------------------

(defun execute-checked-mutation (certificate evidence ports)
  (let ((refusals (certificate-refusal-labels certificate evidence)))
    (if refusals
        (make-result :refused
                     :action (hngh.domain:candidate-certificate-action certificate)
                     :labels refusals)
        (let ((mismatches (mismatch-labels certificate evidence)))
          (if mismatches
              (make-result
               :mismatch
               :action (hngh.domain:candidate-certificate-action certificate)
               :labels mismatches)
              (let ((command (command-for certificate))
                    (action
                      (hngh.domain:candidate-certificate-action certificate)))
                (if (null command)
                    (make-result :refused :action action
                                 :labels '("unsupported-action"))
                    (multiple-value-bind (ok exit-code stdout stderr)
                        (transport-response ports command)
                      (cond
                        ((not ok)
                         (make-result :transport-fault :action action
                                      :command command
                                      :labels '("transport-fault")))
                        ((zerop exit-code)
                         (make-result :executed :action action :command command
                                      :exit-code exit-code :stdout stdout
                                      :stderr stderr))
                        (t
                         (make-result :command-failed :action action
                                      :command command
                                      :labels '("command-failed")
                                      :exit-code exit-code :stdout stdout
                                      :stderr stderr)))))))))))

(defun execute-mutation (certificate fresh-evidence ports &key action)
  "Recheck CERTIFICATE against FRESH-EVIDENCE, then issue one fixed command.
FRESH-EVIDENCE may be NIL only when PORTS supplies a gather-evidence callback.
The optional ACTION is an explicit requested action and must equal the action
bound to CERTIFICATE; it cannot broaden that authority. Every refusal returns a
closed MUTATION-RESULT and performs no mutation transport call."
  (handler-case
      (cond
        ((not (hngh.domain:candidate-certificate-p certificate))
         (make-result :refused :labels '("malformed-input")))
        ((and action (not (member action +mutation-actions+)))
         (make-result :refused :action action
                      :labels '("unsupported-action")))
        ((and action
              (not (eql action
                        (hngh.domain:candidate-certificate-action certificate))))
         (make-result
          :refused
          :action (hngh.domain:candidate-certificate-action certificate)
          :labels '("unauthorized-action")))
        ((eql :none (hngh.domain:candidate-certificate-action certificate))
         (make-result :refused :action :none :labels '("no-op-action")))
        ((not (mutation-ports-p ports))
         (make-result
          :transport-fault
          :action (hngh.domain:candidate-certificate-action certificate)
          :labels '("transport-fault")))
        (t
         (multiple-value-bind (evidence gather-label)
             (if fresh-evidence
                 (values fresh-evidence nil)
                 (gather-fresh-evidence certificate ports))
           (cond
             (gather-label
              (make-result
               :refused
               :action (hngh.domain:candidate-certificate-action certificate)
               :labels (list gather-label)))
             ((not (mutation-evidence-p evidence))
              (make-result
               :refused
               :action (hngh.domain:candidate-certificate-action certificate)
               :labels '("malformed-evidence")))
             (t (execute-checked-mutation certificate evidence ports))))))
    (error ()
      (make-result :refused :labels '("malformed-input")))))
