;;;; tests/unit/test-threat-detection.lisp — Tests for Threat Detection (A7)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.threat-detection
  :description "Tests for Procedural Threat Detection (A7) — L1 static + L3 runtime"
  :in :hngh)

(in-suite :hngh.threat-detection)

;;; --- Helpers ---

(defun valid-manifest ()
  "Return a valid manifest plist for testing."
  '(:name "test-plugin"
    :version "0.1.0"
    :trust-tier :first-party
    :language :cl
    :capabilities
    (:filesystem
     (:read ("/etc/pacman.d/")
      :write ("~/.config/hngh/test-plugin/"))
     :network
     (:hosts ("api.github.com"))
     :subprocess
     (:allowed ("git" "pacman"))
     :dbus
     (:system ("org.hngh.System")))
    :lifecycle
    (:load "test-plugin:init"
     :unload "test-plugin:cleanup")))

(defun ai-generated-manifest ()
  "Return an AI-generated manifest with required :review section."
  '(:name "ai-plugin"
    :version "0.2.0"
    :trust-tier :ai-generated
    :language :cl
    :review
    (:source "ai-generated"
     :generator "opencode"
     :prompt-hash "sha256:abc123")
    :capabilities
    (:filesystem
     (:write ("~/.config/hngh/ai-plugin/")))))

(defun make-tmp-lisp-file (content &optional (prefix "hngh-test-code"))
  "Write CONTENT to a temp .lisp file and return the pathname."
  (let* ((tmp-dir (uiop:temporary-directory))
         (path (merge-pathnames (format nil "~A-~D.lisp" prefix (random 1000000))
                                tmp-dir)))
    (with-open-file (stream path :direction :output
                                 :if-exists :supersede)
      (write-string content stream))
    path))

;;; --- L1: Manifest Analysis ---

(test analyze-manifest-valid-passes
  "A well-formed manifest passes L1 analysis."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest (valid-manifest))))
    (is (equal :pass (hngh.core.threat-detection:l1-verdict-result verdict)))
    (is (member :manifest-schema (hngh.core.threat-detection:l1-verdict-checks-run verdict)))
    (is (member :capability-validation (hngh.core.threat-detection:l1-verdict-checks-run verdict)))
    (is (member :pattern-db (hngh.core.threat-detection:l1-verdict-checks-run verdict)))
    (is (member :trust-tier-rules (hngh.core.threat-detection:l1-verdict-checks-run verdict)))
    (is (null (hngh.core.threat-detection:l1-verdict-failures verdict)))))

(test analyze-manifest-missing-name-fails
  "A manifest missing :name fails L1."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest
                   '(:version "0.1" :trust-tier :first-party :language :cl))))
    (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
    (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
      (is (find :manifest-schema failures :key #'second)))))

(test analyze-manifest-bad-trust-tier-fails
  "A manifest with invalid :trust-tier fails L1."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest
                   '(:name "bad" :version "0.1" :trust-tier :bogus :language :cl))))
    (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
    (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
      (is (find :manifest-schema failures :key #'second)))))

(test analyze-manifest-bad-language-fails
  "A manifest with invalid :language fails L1."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest
                   '(:name "bad" :version "0.1" :trust-tier :first-party :language :bogus))))
    (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
    (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
      (is (find :manifest-schema failures :key #'second)))))

(test analyze-manifest-ai-generated-without-review-fails
  "AI-generated manifest missing :review section fails L1."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest
                   '(:name "ai-bad" :version "0.1" :trust-tier :ai-generated :language :cl))))
    (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
    (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
      (is (find :trust-tier-rules failures :key #'second)))))

(test analyze-manifest-ai-generated-with-review-passes
  "AI-generated manifest with :review section passes trust tier check."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest (ai-generated-manifest))))
    (is (equal :pass (hngh.core.threat-detection:l1-verdict-result verdict)))
    ;; No :trust-tier-rules failure
    (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
      (is (not (find :trust-tier-rules failures :key #'second))))))

(test analyze-manifest-unknown-capability-category-fails
  "Manifest with unknown capability category fails L1."
  (let ((verdict (hngh.core.threat-detection:analyze-manifest
                   '(:name "badcap" :version "0.1" :trust-tier :first-party :language :cl
                     :capabilities (:bogus-category (:allowed ("x")))))))
    (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
    (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
      (is (find :capability-validation failures :key #'second)))))

;;; --- L1: Code Analysis ---

(test analyze-code-safe-file-passes
  "A Lisp file with no dangerous calls passes L1."
  (let ((tmp-file (make-tmp-lisp-file "
(defun hello-world ()
  (format t \"Hello, world!~%\"))
")))
    (unwind-protect
         (let ((verdict (hngh.core.threat-detection:analyze-code tmp-file)))
           (is (equal :pass (hngh.core.threat-detection:l1-verdict-result verdict))
               "Safe code should pass")
           (is (null (hngh.core.threat-detection:l1-verdict-failures verdict))
               "No failures expected for safe code"))
      (delete-file tmp-file))))

(test analyze-code-eval-detected
  "A Lisp file calling eval is flagged as dangerous."
  (let ((tmp-file (make-tmp-lisp-file "
(defun bad-function ()
  (eval '(format t \"hi~%\")))
")))
    (unwind-protect
         (let ((verdict (hngh.core.threat-detection:analyze-code tmp-file)))
           (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
           (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
             (is (find :dangerous-functions failures :key #'second))))
      (delete-file tmp-file))))

(test analyze-code-run-program-detected
  "A Lisp file calling run-program is flagged."
  (let ((tmp-file (make-tmp-lisp-file "
(uiop:run-program \"rm -rf /\" '())
")))
    (unwind-protect
         (let ((verdict (hngh.core.threat-detection:analyze-code tmp-file)))
           (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
           (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
             (is (find :dangerous-functions failures :key #'second))))
      (delete-file tmp-file))))

(test analyze-code-nonexistent-file-fails
  "Analyzing a non-existent file returns fail."
  (let ((verdict (hngh.core.threat-detection:analyze-code #P"/tmp/nonexistent-12345.lisp")))
    (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
    (is (find :file-read (hngh.core.threat-detection:l1-verdict-failures verdict)
              :key #'second))))

;;; --- Pattern Management ---

(test add-pattern-and-list
  "Patterns can be added and listed."
  (bt:with-lock-held (hngh.core.threat-detection::*patterns-lock*)
    (setf hngh.core.threat-detection:*patterns* nil))
  (let ((count (hngh.core.threat-detection:add-pattern
                 '(:name "test-pattern"
                   :match :symbol
                   :pattern "bad-function"
                   :severity :high
                   :description "Test pattern for unit test"))))
    (is (equal 1 count))
    (is (equal 1 (length hngh.core.threat-detection:*patterns*)))
    (is (equal "test-pattern" (getf (first hngh.core.threat-detection:*patterns*) :name))))
  ;; Clean up
  (bt:with-lock-held (hngh.core.threat-detection::*patterns-lock*)
    (setf hngh.core.threat-detection:*patterns* nil)))

(test pattern-db-check-flags-known-bad-name
  "A manifest with a name matching a known-bad pattern is flagged."
  (bt:with-lock-held (hngh.core.threat-detection::*patterns-lock*)
    (setf hngh.core.threat-detection:*patterns* nil)
    (push '(:name "malware-blocklist"
            :match :symbol
            :pattern "evil-plugin"
            :severity :critical
            :description "Known malware")
          hngh.core.threat-detection:*patterns*))
  (unwind-protect
       (let ((verdict (hngh.core.threat-detection:analyze-manifest
                        '(:name "evil-plugin" :version "1.0" :trust-tier :user :language :cl))))
         (is (equal :fail (hngh.core.threat-detection:l1-verdict-result verdict)))
         (let ((failures (hngh.core.threat-detection:l1-verdict-failures verdict)))
           (is (find :pattern-db failures :key #'second))))
    (bt:with-lock-held (hngh.core.threat-detection::*patterns-lock*)
      (setf hngh.core.threat-detection:*patterns* nil))))

;;; --- L3: Runtime Observation ---

(test observe-behavior-benign-returns-nil
  "A benign event returns nil (no flag)."
  (hngh.core.threat-detection:init)
  (let ((result (hngh.core.threat-detection:observe-behavior
                  "test-plugin"
                  '(:topic "plugin.loaded" :payload (:name "test-plugin")))))
    (is (null result)))
  (hngh.core.threat-detection:shutdown))

(test observe-behavior-secret-denied-flags
  "A secret.denied event raises a flag."
  (hngh.core.threat-detection:init)
  (let ((flag (hngh.core.threat-detection:observe-behavior
                "unauthorized-plugin"
                '(:topic "secret.denied" :payload (:name "api-key" :requester "unauthorized-plugin")))))
    (is (not (null flag)))
    (is (equal "unauthorized-plugin" (getf flag :plugin)))
    (is (equal :high (getf flag :severity)))
    (is (equal :L3 (getf flag :layer)))
    ;; Flag should appear in *flags*
    (is (equal 1 (length (hngh.core.threat-detection:list-flags)))))
  ;; Clean up
  (hngh.core.threat-detection:clear-flags)
  (hngh.core.threat-detection:shutdown))

(test observe-behavior-string-event-returns-nil
  "String events are handled gracefully (no crash)."
  (hngh.core.threat-detection:init)
  (let ((result (hngh.core.threat-detection:observe-behavior "test-plugin" "not-an-event")))
    (is (null result)))
  (hngh.core.threat-detection:shutdown))

(test observe-behavior-nil-event-returns-nil
  "NIL events are handled gracefully."
  (hngh.core.threat-detection:init)
  (let ((result (hngh.core.threat-detection:observe-behavior "test-plugin" nil)))
    (is (null result)))
  (hngh.core.threat-detection:shutdown))

;;; --- Flag Management ---

(test list-flags-and-clear
  "Flags can be listed and cleared."
  (hngh.core.threat-detection:init)
  ;; Raise a flag
  (hngh.core.threat-detection:observe-behavior
    "test-plugin"
    '(:topic "secret.denied" :payload (:name "secret1" :requester "test-plugin")))
  (is (equal 1 (length (hngh.core.threat-detection:list-flags))))
  (hngh.core.threat-detection:clear-flags)
  (is (equal 0 (length (hngh.core.threat-detection:list-flags))))
  (hngh.core.threat-detection:shutdown))

;;; --- Lifecycle ---

(test init-shutdown-lifecycle
  "Init and shutdown work correctly."
  (is (not (hngh.core.threat-detection:running-p)))
  (hngh.core.threat-detection:init)
  (is (hngh.core.threat-detection:running-p))
  (hngh.core.threat-detection:shutdown)
  (is (not (hngh.core.threat-detection:running-p))))
