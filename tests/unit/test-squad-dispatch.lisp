;;;; tests/unit/test-squad-dispatch.lisp — Tests for Squad Dispatch (Wave 3)
;;;;
;;;; Fixture tests exercise create-squad, plant-bean, harvest-bean,
;;;; rollback-squad, assign-task, update-task-status, update-role-status,
;;;; check-preconditions, squad-log, and custom roles.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.squad-dispatch
  :description "Tests for squad-dispatch plugin (Wave 3)"
  :in :hngh)

(in-suite :hngh.squad-dispatch)

;;; --- Fixture helpers -------------------------------------------------------

(defun %squad-dispatch-tmp-root ()
  "Return a fresh temp directory for a test squad."
  (merge-pathnames (format nil "hngh-squad-dispatch-test-~D/" (random 1000000))
                   (uiop:temporary-directory)))

(defun %cleanup-squad (root)
  "Delete the test squad directory tree."
  (when (probe-file root)
    (uiop:delete-directory-tree root :validate t)))

;;; --- Tests -----------------------------------------------------------------

(test create-squad-creates-tree
  "create-squad creates the directory tree and initial commit."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((result (hngh.plugins.squad-dispatch:create-squad
                         "test-squad"
                         :home home))
                (root (getf result :squad-root))
                (state-git (getf result :state-git)))
           (declare (ignore state-git))
           ;; Directory tree exists
           (is (probe-file root))
           (is (probe-file (merge-pathnames "dispatch.md" root)))
           (is (probe-file (merge-pathnames "state.git/" root)))
           (is (probe-file (merge-pathnames "pm/inbox.md" root)))
           (is (probe-file (merge-pathnames "designer/inbox.md" root)))
           (is (probe-file (merge-pathnames "coder/tasks/" root)))
           (is (probe-file (merge-pathnames "journal/projected.md" root)))
           ;; dispatch.md has correct content
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (string= "test-squad" (getf status :squad-name)))
             (is (= 6 (length (getf status :roles))))
             (is (null (getf status :tasks)))
             (is (null (getf status :communications))))
           ;; First commit exists
           (is (getf result :commit-sha)))
      (%cleanup-squad home))))

(test plant-bean-writes-inbox
  "plant-bean writes to inbox and commits."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (let* ((plant-result
                   (hngh.plugins.squad-dispatch:plant-bean
                    root :pm :designer "wave-2-design-request"
                    :type :message
                    :content "Design the file-watcher plugin."))
                  (inbox-content
                   (uiop:read-file-string
                    (merge-pathnames "designer/inbox.md" root))))
             ;; Bean is in the inbox
             (is (search "wave-2-design-request" inbox-content))
             (is (search "Design the file-watcher plugin." inbox-content))
             ;; dispatch.md Communications table updated
             (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
               (is (= 1 (length (getf status :communications))))
               (let ((comm (first (getf status :communications))))
                 (is (string= "pm" (getf comm :from)))
                 (is (string= "designer" (getf comm :to)))
                 (is (string= "wave-2-design-request" (getf comm :bean)))
                 (is (string= "planted" (getf comm :status)))))
             ;; Commit SHA returned
             (is (getf plant-result :commit-sha))))
      (%cleanup-squad home))))

(test harvest-bean-marks-harvested
  "harvest-bean reads bean, marks harvested, commits."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           ;; Plant then harvest
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "wave-2-design-request"
            :content "Design the file-watcher plugin.")
           (let ((harvest-result
                  (hngh.plugins.squad-dispatch:harvest-bean
                   root :designer "wave-2-design-request")))
             ;; Bean content returned
             (is (search "Design the file-watcher plugin."
                         (getf harvest-result :content)))
             ;; dispatch.md Communications status is "harvested"
             (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
               (let ((comm (first (getf status :communications))))
                 (is (string= "harvested" (getf comm :status)))))
             ;; Commit SHA returned
             (is (getf harvest-result :commit-sha))))
      (%cleanup-squad home))))

(test squad-log-shows-actions
  "git log shows action history."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "wave-2-design-request"
            :content "Design it.")
           (hngh.plugins.squad-dispatch:harvest-bean
            root :designer "wave-2-design-request")
           (let ((log (hngh.plugins.squad-dispatch:squad-log root :oneline t)))
             ;; Log contains all three actions
             (is (search "[dispatch] create-squad: test-squad" log))
             (is (search "[bean] pm -> designer: wave-2-design-request" log))
             (is (search "[bean] designer harvested: wave-2-design-request" log))
             ;; Three commits (create + plant + harvest)
             (let ((lines (cl-ppcre:split "\\n" (string-trim '(#\Newline) log))))
               (is (= 3 (length (remove-if (lambda (l) (string= l "")) lines)))))))
      (%cleanup-squad home))))

(test rollback-restores-state
  "rollback-squad restores previous state."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root))
                (create-sha (getf create-result :commit-sha)))
           ;; Plant a bean (changes state)
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "wave-2-design-request"
            :content "Design it.")
           ;; Verify bean exists
           (let ((status-before (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 1 (length (getf status-before :communications)))))
           ;; Rollback to create-squad commit (before the bean)
           (hngh.plugins.squad-dispatch:rollback-squad root create-sha)
           ;; Verify bean is gone
           (let ((status-after (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (null (getf status-after :communications)))
             (is (null (getf status-after :tasks))))
           ;; inbox.md is empty again
           (let ((inbox (uiop:read-file-string
                         (merge-pathnames "designer/inbox.md" root))))
             (is (string= "" inbox))))
      (%cleanup-squad home))))

(test assign-task-updates-dispatch
  "assign-task adds task to dispatch.md."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (let ((assign-result
                  (hngh.plugins.squad-dispatch:assign-task
                   root "t84" "implement watcher" :coder
                   :blocked-by "w2-design")))
             ;; Task appears in dispatch.md
             (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
               (is (= 1 (length (getf status :tasks))))
               (let ((task (first (getf status :tasks))))
                 (is (string= "t84" (getf task :id)))
                 (is (string= "implement watcher" (getf task :title)))
                 (is (string= "coder" (getf task :assigned)))
                 (is (string= "pending" (getf task :status)))
                 (is (string= "w2-design" (getf task :blocked-by)))))
             ;; Task file exists
             (is (probe-file (merge-pathnames "coder/tasks/t84.md" root)))
             ;; Commit SHA returned
             (is (getf assign-result :commit-sha))))
      (%cleanup-squad home))))

(test check-preconditions-procedural
  "check-preconditions evaluates boolean expressions."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           ;; A spec with mixed pass/fail preconditions
           (let ((spec (list :preconditions
                             (list (list :file-exists "dispatch.md")
                                   (list :function-exists :hngh.plugins.hngh-up
                                         :generate-pm-prompt)
                                   (list :file-exists "nonexistent-file.lisp")
                                   (list :package-exports
                                         :hngh.plugins.config-watcher
                                         :init :shutdown :running-p :status)))))
             (let ((result (hngh.plugins.squad-dispatch:check-preconditions
                            spec :cwd root)))
               ;; Not all passed (nonexistent file fails)
               (is (null (getf result :all-passed)))
               ;; 4 results
               (is (= 4 (length (getf result :results))))
               ;; First two pass, third fails
               (is (getf (first (getf result :results)) :passed))
               (is (getf (second (getf result :results)) :passed))
               (is (null (getf (third (getf result :results)) :passed))))))
      (%cleanup-squad home))))

(test status-updates
  "update-task-status and update-role-status work."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (hngh.plugins.squad-dispatch:assign-task
            root "t84" "implement watcher" :coder)
           ;; Update task status
           (hngh.plugins.squad-dispatch:update-task-status
            root "t84" "in-progress")
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (let ((task (first (getf status :tasks))))
               (is (string= "in-progress" (getf task :status)))))
           ;; Update role status
           (hngh.plugins.squad-dispatch:update-role-status
            root :designer "active")
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (let ((designer-role
                    (find "designer" (getf status :roles)
                          :key (lambda (r) (getf r :role)) :test #'string=)))
               (is (string= "active" (getf designer-role :status))))))
      (%cleanup-squad home))))

(test double-harvest-errors
  "Double harvest signals an error."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((create-result (hngh.plugins.squad-dispatch:create-squad
                                "test-squad" :home home))
                (root (getf create-result :squad-root)))
           (hngh.plugins.squad-dispatch:plant-bean
            root :pm :designer "test-bean" :content "Test.")
           (hngh.plugins.squad-dispatch:harvest-bean
            root :designer "test-bean")
           ;; Second harvest should error
           (signals error
             (hngh.plugins.squad-dispatch:harvest-bean
              root :designer "test-bean")))
      (%cleanup-squad home))))

(test create-squad-custom-roles
  "create-squad accepts custom roles."
  (let ((home (%squad-dispatch-tmp-root)))
    (unwind-protect
         (let* ((result (hngh.plugins.squad-dispatch:create-squad
                         "test-squad"
                         :home home
                         :roles '(:pm :designer :coder :reviewer)))
                (root (getf result :squad-root)))
           (is (probe-file (merge-pathnames "reviewer/inbox.md" root)))
           (is (probe-file (merge-pathnames "reviewer/tasks/" root)))
           (let ((status (hngh.plugins.squad-dispatch:get-squad-status root)))
             (is (= 4 (length (getf status :roles))))))
      (%cleanup-squad home))))
