;;;; tests/unit/test-knowledge-base.lisp — Tests for Knowledge Base (B12)
;;;;
;;;; Covers lifecycle, article write/read, keyword query,
;;;; decision recording, and learned-pattern recording.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.knowledge-base
  :description "Tests for Knowledge Base (B12)"
  :in :hngh)

(in-suite :hngh.knowledge-base)

;;; --- Helpers ---------------------------------------------------------------

(defun kb-setup (tmp)
  "Initialize services required by Knowledge Base on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.plugins.knowledge-base:initialize-knowledge-base :hngh-home tmp))

(defun kb-teardown (tmp)
  "Shutdown Knowledge Base + dependencies and clean TMP."
  (hngh.plugins.knowledge-base:shutdown-knowledge-base)
  (hngh.core.state-store:shutdown)
  (hngh.core.event-bus:shutdown)
  (cleanup-tmp-home tmp))

(defmacro with-kb ((tmp-var) &body body)
  "Run BODY with temporary home and Knowledge Base initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (kb-setup ,tmp-var)
            ,@body)
       (kb-teardown ,tmp-var))))

;;; --- Tests ----------------------------------------------------------------

(test kb-lifecycle
  "Knowledge Base initializes as ready and shuts down cleanly."
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (unwind-protect
         (progn
           (hngh.core.event-bus:init :hngh-home tmp)
           (hngh.core.state-store:init :hngh-home tmp)
           (is (hngh.plugins.knowledge-base:initialize-knowledge-base
                :hngh-home tmp)
               "initialize-knowledge-base should return T")
           (is (hngh.plugins.knowledge-base:knowledge-base-ready-p)
               "Knowledge Base should report ready after initialize")
           (let ((status (hngh.plugins.knowledge-base:kb-status)))
             (is (eq t (getf status :running))
                 "kb-status :running should be T")))
      (hngh.plugins.knowledge-base:shutdown-knowledge-base)
      (hngh.core.state-store:shutdown)
      (hngh.core.event-bus:shutdown)
      (cleanup-tmp-home tmp)))
  (is (not (hngh.plugins.knowledge-base:knowledge-base-ready-p))
      "Knowledge Base should not be ready after shutdown"))

(test kb-article-write-read
  "Writing an article then reading it by ID round-trips required fields."
  (with-kb (tmp)
    (let* ((written (hngh.plugins.knowledge-base:kb-write-article
                     "pacman-basics"
                     "Pacman Basics"
                     "Use pacman -Syu regularly."
                     :tags '("packages" :linux)
                     :keywords '("pacman" "upgrade")))
           (loaded (hngh.plugins.knowledge-base:kb-get-article "pacman-basics")))
      (is (not (null written)) "kb-write-article should return an entry plist")
      (is (not (null loaded)) "kb-get-article should return the persisted entry")
      (is (eq :article (getf loaded :kind)) "Loaded entry :kind should be :article")
      (is (string= "pacman-basics" (getf loaded :id)) "Loaded ID should match slug")
      (is (string= "Pacman Basics" (getf loaded :title)) "Loaded title should match")
      (is (find "pacman" (getf loaded :keywords) :test #'string=)
          "Loaded keywords should include pacman"))))

(test kb-query-by-keyword-and-tag
  "Query matches by keyword text and tag filters deterministically."
  (with-kb (tmp)
    (hngh.plugins.knowledge-base:kb-write-article
     "a-arch-pkgs" "Arch Packages" "pacman and makepkg tips"
     :tags '("packages" "arch")
     :keywords '("pacman"))
    (hngh.plugins.knowledge-base:kb-write-article
     "a-workflow" "Workflow Notes" "agent handoff checklist"
     :tags '("workflow")
     :keywords '("handoff"))
    (let ((keyword-results (hngh.plugins.knowledge-base:kb-query "pacman"))
          (tag-results (hngh.plugins.knowledge-base:kb-query ""
                                                              :tags '("workflow"))))
      (is (plusp (length keyword-results))
          "Query by keyword should return at least one match")
      (is (find "a-arch-pkgs" keyword-results :key (lambda (x) (getf x :id)) :test #'string=)
          "Keyword query should include the matching article")
      (is (= 1 (length tag-results))
          "Tag-filtered query should return one matching entry")
      (is (string= "a-workflow" (getf (first tag-results) :id))
          "Tag-filtered query should return the workflow article"))))

(test kb-record-decision
  "Recording a decision persists it and updates status counts."
  (with-kb (tmp)
    (let ((decision (hngh.plugins.knowledge-base:kb-record-decision
                     "d-runtime-choice"
                     "Runtime Choice"
                     "Prefer local ollama first"
                     :tags '("runtime" "ai")
                     :context '(:tier :local)
                     :outcome :accepted
                     :rationale "Lower latency and privacy.")))
      (is (not (null decision)) "kb-record-decision should return decision entry")
      (is (eq :decision (getf decision :kind)) "Recorded entry :kind should be :decision")
       (let* ((loaded (hngh.plugins.knowledge-base:kb-get-decision "d-runtime-choice"))
              (hits (hngh.plugins.knowledge-base:kb-query "runtime choice"))
              (status (hngh.plugins.knowledge-base:kb-status)))
         (is (not (null loaded)) "kb-get-decision should return persisted decision")
         (is (find "d-runtime-choice" hits :key (lambda (x) (getf x :id)) :test #'string=)
             "Decision should be queryable by title text")
         (is (= 1 (getf status :decisions-count))
             "kb-status should report one decision")))))

(test kb-record-pattern
  "Recording a learned pattern persists it under category and is queryable."
  (with-kb (tmp)
    (let ((pattern (hngh.plugins.knowledge-base:kb-record-pattern
                    "p-retry-timeout"
                    :optimizations
                    "Retry Timeout Pattern"
                    "Use bounded retries with jitter"
                    :tags '("retry" "reliability")
                    :signals '(:timeout-spike)
                    :actions '(:retry-with-jitter :cap-backoff))))
      (is (not (null pattern)) "kb-record-pattern should return pattern entry")
      (is (eq :pattern (getf pattern :kind)) "Recorded entry :kind should be :pattern")
      (is (string= "optimizations" (getf pattern :category))
          "Pattern category should normalize to optimizations")
       (let* ((loaded (hngh.plugins.knowledge-base:kb-get-pattern
                       "p-retry-timeout"
                       :category :optimizations))
              (hits (hngh.plugins.knowledge-base:kb-query "retry timeout"))
              (status (hngh.plugins.knowledge-base:kb-status)))
         (is (not (null loaded)) "kb-get-pattern should return persisted pattern")
         (is (find "p-retry-timeout" hits :key (lambda (x) (getf x :id)) :test #'string=)
             "Pattern should be queryable by text")
         (is (= 1 (getf status :patterns-count))
             "kb-status should report one pattern")))))

(test kb-write-respects-state-lock
  "Writes fail gracefully when another holder has already acquired the lock."
  (with-kb (tmp)
    (is (not (null tmp)) "Temporary home should be initialized")
    (is (hngh.core.state-store:acquire-lock "kb-article-locked-id"
                                            :holder "test-holder"
                                            :ttl 30)
        "Test should be able to acquire lock first")
    (unwind-protect
         (is (null (hngh.plugins.knowledge-base:kb-write-article
                    "locked-id"
                    "Locked"
                    "Should not write while lock is held"))
             "kb-write-article should return NIL when lock is busy")
      (hngh.core.state-store:release-lock "kb-article-locked-id"
                                          :holder "test-holder"))))

(test kb-slugify-degenerate-id-stable
  "Degenerate IDs produce deterministic fallback slugs instead of time-based IDs."
  (let ((first (hngh.plugins.knowledge-base::slugify "!!!"))
        (second (hngh.plugins.knowledge-base::slugify "!!!"))
        (third (hngh.plugins.knowledge-base::slugify "@@@")))
    (is (string= first second)
        "Same degenerate input should produce same fallback slug")
    (is (not (string= first third))
        "Different degenerate inputs should produce different fallback slugs")))
