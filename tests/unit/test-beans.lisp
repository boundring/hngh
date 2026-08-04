;;;; tests/unit/test-beans.lisp — Tests for Beans Lifecycle (Wave 4)
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>
;;;; Coder — glm-5.2, Hermes harness.

(in-package :hngh.tests)

(def-suite :hngh.beans
  :description "Tests for beans plugin (Wave 4)"
  :in :hngh)

(in-suite :hngh.beans)

;;; --- Fixture helpers -------------------------------------------------------

(defun %beans-tmp-root ()
  "Return a fresh temp directory for a test squad."
  (merge-pathnames (format nil "hngh-beans-test-~D/" (random 1000000))
                   (uiop:temporary-directory)))

(defun %cleanup-beans (root)
  "Delete the test squad directory tree."
  (when (probe-file root)
    (uiop:delete-directory-tree root :validate t)))

(defun %setup-squad (&optional (home (%beans-tmp-root)))
  "Create a test squad and return (values root home)."
  (let* ((result (hngh.plugins.squad-dispatch:create-squad
                   "test-beans" :home home))
         (root (getf result :squad-root)))
    (values root home)))

;;; --- Tests -----------------------------------------------------------------

(test plant-message-bean-with-membrane
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (let ((result (hngh.plugins.beans:plant-bean
                        root :pm :designer "test-msg-1"
                        :type :message
                        :content "Design the beans plugin."
                        :membrane :ingest)))
           (is (eq :message (getf result :type)))
           (is (eq :ingest (getf result :membrane)))
           (is (string= "ripe" (getf result :status)))
           (is (getf result :commit-sha))
           (let ((bean (hngh.plugins.beans:read-bean root :designer "test-msg-1")))
             (is (string= "message" (getf bean :type)))
             (is (string= "ingest" (getf bean :membrane)))
             (is (search "Design the beans plugin." (getf bean :content)))))
      (%cleanup-beans home))))

(test plant-task-bean-with-fields
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (let ((result (hngh.plugins.beans:plant-bean
                        root :pm :coder "test-task-1"
                        :type :task
                        :content "Implement the beans plugin."
                        :membrane :chew
                        :expires "2099-12-31T23:59:59"
                        :type-fields '(:task-id "w4"
                                       :title "Bean Lifecycle"
                                       :blocked-by "w3"
                                       :acceptance "- All types defined
- Lifecycle implemented
- Tests green"
                                       :files "src/plugins/beans.lisp"))))
           (is (eq :task (getf result :type)))
           (is (getf result :commit-sha))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "test-task-1")))
             (is (string= "task" (getf bean :type)))
             (is (string= "chew" (getf bean :membrane)))
             (let ((tf (getf bean :type-fields)))
               (is (string= "w4" (getf tf :task-id)))
               (is (string= "Bean Lifecycle" (getf tf :title)))
               (is (string= "w3" (getf tf :blocked-by)))))
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 1 (length (getf status :communications))))))
      (%cleanup-beans home))))

(test full-cycle-message-bean
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :designer "cycle-msg"
            :type :message
            :content "Do the thing.")
           (let ((harvest (hngh.plugins.beans:harvest-bean
                           root :designer "cycle-msg")))
             (is (search "Do the thing." (getf harvest :content)))
             (is (string= "message" (getf harvest :type)))
             (is (string= "ingest" (getf harvest :membrane))))
           (let ((digest (hngh.plugins.beans:digest-bean
                          root :designer "cycle-msg"
                          :output "Done."
                          :attribution "Designer — glm-5.2, Hermes harness")))
             (is (getf digest :commit-sha))
             (is (null (getf digest :spore-result))))
           (let ((bean (hngh.plugins.beans:read-bean root :designer "cycle-msg")))
             (is (string= "husked" (getf bean :status))))
           (let ((journal (uiop:read-file-string
                            (merge-pathnames "journal/actual.md" root))))
             (is (search "cycle-msg" journal))
             (is (search "Designer — glm-5.2" journal))))
      (%cleanup-beans home))))

(test full-cycle-all-types
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (dolist (type '(:message :task :status :resource :context :review))
           (let ((bean-name (format nil "cycle-~A" (string-downcase type))))
             (hngh.plugins.beans:plant-bean
              root :pm :worker bean-name
              :type type
              :content (format nil "~A bean content" (string-downcase type))
              :membrane :ingest
              :type-fields (case type
                             (:task '(:task-id "t1" :title "Test" :acceptance "ok"))
                             (:status '(:role "worker" :state "growing"))
                             (:resource '(:kind "file"))
                             (:context '(:scope "squad"))
                             (:review '(:artifact "test.md" :verdict "accept"))
                             (t nil)))
             (hngh.plugins.beans:harvest-bean root :worker bean-name)
             (hngh.plugins.beans:digest-bean
              root :worker bean-name
              :output "output"
              :attribution "Worker — test")
             (let ((bean (hngh.plugins.beans:read-bean root :worker bean-name)))
               (is (string= "husked" (getf bean :status))
                   "Bean ~A should be husked" bean-name))))
      (%cleanup-beans home))))

(test stale-bean-detection
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "stale-1"
            :type :message
            :content "This is stale."
            :expires "2000-01-01T00:00:00")
           (let ((result (hngh.plugins.beans:check-bean-staleness
                          root :coder "stale-1")))
             (is (getf result :stale))
             (is (string= "expired" (getf result :reason))))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "stale-1")))
             (is (string= "spoiled" (getf bean :status))))
           (signals error
             (hngh.plugins.beans:harvest-bean root :coder "stale-1")))
      (%cleanup-beans home))))

(test fresh-bean-not-stale
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "fresh-1"
            :type :message
            :content "This is fresh."
            :expires "2099-12-31T23:59:59")
           (let ((result (hngh.plugins.beans:check-bean-staleness
                          root :coder "fresh-1")))
             (is (null (getf result :stale)))))
      (%cleanup-beans home))))

(test cull-spoiled-beans-removes-from-inbox
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "stale-1"
            :type :message :content "Stale."
            :expires "2000-01-01T00:00:00")
           (hngh.plugins.beans:plant-bean
            root :pm :coder "fresh-1"
            :type :message :content "Fresh."
            :expires "2099-12-31T23:59:59")
           (hngh.plugins.beans:check-bean-staleness root :coder "stale-1")
           (let ((result (hngh.plugins.beans:cull-spoiled-beans
                          root :role :coder)))
             (is (= 1 (getf result :count)))
             (is (string= "stale-1"
                          (getf (first (getf result :culled)) :bean))))
           (signals error
             (hngh.plugins.beans:read-bean root :coder "stale-1"))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "fresh-1")))
             (is (string= "fresh-1" (getf bean :bean)))))
      (%cleanup-beans home))))

(test cull-dry-run-keeps-beans
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "stale-1"
            :type :message :content "Stale."
            :expires "2000-01-01T00:00:00")
           (hngh.plugins.beans:check-bean-staleness root :coder "stale-1")
           (let ((result (hngh.plugins.beans:cull-spoiled-beans
                          root :role :coder :dry-run t)))
             (is (= 1 (getf result :count)))
             (is (null (getf result :commit-sha))))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "stale-1")))
             (is (string= "spoiled" (getf bean :status)))))
      (%cleanup-beans home))))

(test spore-propagation-generates-sub-beans
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :worker "spore-1"
            :type :spore
            :membrane :ferment
            :content "Generate sub-tasks."
            :type-fields '(:spore-id "sp-001"
                           :propagation-limit 5
                           :sub-bean-types "task,message"))
           (hngh.plugins.beans:harvest-bean root :worker "spore-1")
           (let ((digest (hngh.plugins.beans:digest-bean
                          root :worker "spore-1"
                          :output "```spore
- bean: sub-1
  to: worker
  type: task
  content: \"Sub-task 1\"
  type-fields:
    task-id: sub-1
    title: Sub 1
    acceptance: ok
- bean: sub-2
  to: worker
  type: message
  content: \"Sub-message 2\"
```"
                          :attribution "Worker — test")))
             (is (getf digest :spore-result))
             (is (= 2 (getf (getf digest :spore-result) :sub-bean-count)))
             (is (null (getf (getf digest :spore-result) :feral))))
           (let ((sub1 (hngh.plugins.beans:read-bean root :worker "sub-1")))
             (is (string= "task" (getf sub1 :type))))
           (let ((sub2 (hngh.plugins.beans:read-bean root :worker "sub-2")))
             (is (string= "message" (getf sub2 :type)))))
      (%cleanup-beans home))))

(test spore-exceeds-limit-marks-feral
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :worker "spore-2"
            :type :spore
            :membrane :ferment
            :content "Generate too many sub-tasks."
            :type-fields '(:spore-id "sp-002"
                           :propagation-limit 1
                           :sub-bean-types "task"))
           (hngh.plugins.beans:harvest-bean root :worker "spore-2")
           (signals error
             (hngh.plugins.beans:digest-bean
              root :worker "spore-2"
              :output "```spore
- bean: sub-a
  to: worker
  type: task
  content: \"A\"
- bean: sub-b
  to: worker
  type: task
  content: \"B\"
```"
              :attribution "Worker — test"))
           (let ((bean (hngh.plugins.beans:read-bean root :worker "spore-2")))
             (is (string= "feral" (getf bean :status)))))
      (%cleanup-beans home))))

(test cross-role-planting
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :designer :coder "design-handoff"
            :type :message
            :content "Design done, implement it.")
           (let ((bean (hngh.plugins.beans:read-bean root :coder "design-handoff")))
             (is (string= "designer" (getf bean :from)))
             (is (string= "coder" (getf bean :to)))
             (is (search "Design done" (getf bean :content))))
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 1 (length (getf status :communications))))
             (let ((comm (first (getf status :communications))))
               (is (string= "designer" (getf comm :from)))
               (is (string= "coder" (getf comm :to))))))
      (%cleanup-beans home))))

(test harvest-growing-bean-errors
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "growing-1"
            :type :task
            :content nil
            :type-fields '(:task-id "g1" :title "Growing" :acceptance "ok"))
           (let ((bean (hngh.plugins.beans:read-bean root :coder "growing-1")))
             (is (string= "growing" (getf bean :status))))
           (signals error
             (hngh.plugins.beans:harvest-bean root :coder "growing-1")))
      (%cleanup-beans home))))

(test digest-before-harvest-errors
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :coder "undigested-1"
            :type :message
            :content "Not harvested yet.")
           (signals error
             (hngh.plugins.beans:digest-bean
              root :coder "undigested-1"
              :output "output"
              :attribution "test")))
      (%cleanup-beans home))))

(test cull-feral-beans
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :worker "feral-spore"
            :type :spore
            :membrane :ferment
            :content "Go feral."
            :type-fields '(:spore-id "fp-001"
                           :propagation-limit 1
                           :sub-bean-types "task"))
           (hngh.plugins.beans:harvest-bean root :worker "feral-spore")
           (handler-case
               (hngh.plugins.beans:digest-bean
                root :worker "feral-spore"
                :output "```spore
- bean: fsub-1
  to: worker
  type: task
  content: \"A\"
- bean: fsub-2
  to: worker
  type: task
  content: \"B\"
```"
                :attribution "test")
             (error () nil))
           (let ((result (hngh.plugins.beans:cull-spoiled-beans
                          root :feral-only t)))
             (is (>= (getf result :count) 1))))
      (%cleanup-beans home))))

(test husk-entry-has-attribution
  (multiple-value-bind (root home) (%setup-squad)
    (unwind-protect
         (progn
           (hngh.plugins.beans:plant-bean
            root :pm :designer "husk-test"
            :type :task
            :content "Do work."
            :type-fields '(:task-id "h1" :title "Husk test" :acceptance "ok"))
           (hngh.plugins.beans:harvest-bean root :designer "husk-test")
           (hngh.plugins.beans:digest-bean
            root :designer "husk-test"
            :output "Work done."
            :attribution "Designer — glm-5.2, Hermes harness, $0")
           (let ((journal (uiop:read-file-string
                            (merge-pathnames "journal/actual.md" root))))
             (is (search "husk-test" journal))
             (is (search "Designer — glm-5.2" journal))
             (is (search "task" journal))
             (is (search "chew" journal)))
      (%cleanup-beans home)))))
