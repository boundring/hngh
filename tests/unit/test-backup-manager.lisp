;;;; tests/unit/test-backup-manager.lisp — Tests for Backup Manager (B7)
;;;;
;;;; Covers lifecycle, git init, secure commit behavior, restore guard,
;;;; remotes, and local push workflow.
;;;;
;;;; SPDX-License-Identifier: AGPL-3.0-or-later
;;;; SPDX-FileCopyrightText: 2026 boundring <boundring@gmail.com>

(in-package :hngh.tests)

(def-suite :hngh.backup-manager
  :description "Tests for Backup Manager (B7)"
  :in :hngh)

(in-suite :hngh.backup-manager)

;;; --- Helpers ---------------------------------------------------------------

(defun run-git-in-dir (directory args)
  "Run git ARGS in DIRECTORY and return plist with :ok :code :output."
  (handler-case
      (let* ((proc (sb-ext:run-program "git" args
                                       :directory directory
                                       :output :stream
                                       :error :output
                                       :wait t
                                       :search t))
             (code (sb-ext:process-exit-code proc))
             (output (with-output-to-string (out)
                       (loop for line = (read-line (sb-ext:process-output proc) nil nil)
                             while line
                             do (progn
                                  (write-string line out)
                                  (write-char #\Newline out))))))
        (list :ok (zerop code) :code code :output output))
    (error (c)
      (list :ok nil :code 127 :output (princ-to-string c)))))

(defun backup-setup (tmp)
  "Initialize dependencies and Backup Manager on TMP."
  (hngh.core.event-bus:init :hngh-home tmp)
  (hngh.core.state-store:init :hngh-home tmp)
  (hngh.core.scheduler:init)
  (hngh.plugins.backup-manager:init :hngh-home tmp)
  ;; Hermetic local identity for deterministic git behavior in tests.
  (run-git-in-dir tmp '("config" "user.email" "test@localhost"))
  (run-git-in-dir tmp '("config" "user.name" "Hngh Test")))

(defun backup-teardown (tmp)
  "Shutdown Backup Manager + dependencies and clean TMP."
  (ignore-errors (hngh.plugins.backup-manager:shutdown))
  (ignore-errors (hngh.core.scheduler:shutdown))
  (ignore-errors (hngh.core.state-store:shutdown))
  (ignore-errors (hngh.core.event-bus:shutdown))
  (cleanup-tmp-home tmp))

(defmacro with-backup ((tmp-var) &body body)
  "Run BODY with temporary home and Backup Manager initialized."
  `(let ((,tmp-var (make-tmp-home)))
     (cleanup-tmp-home ,tmp-var)
     (unwind-protect
          (progn
            (backup-setup ,tmp-var)
            ,@body)
       (backup-teardown ,tmp-var))))

;;; --- Tests -----------------------------------------------------------------

(test backup-lifecycle
  "Backup Manager initializes and shuts down cleanly."
  (let ((tmp (make-tmp-home)))
    (cleanup-tmp-home tmp)
    (unwind-protect
         (progn
           (backup-setup tmp)
           (is (hngh.plugins.backup-manager:running-p)
               "Backup Manager should report running after init")
           (let ((status (hngh.plugins.backup-manager:status)))
             (is (eq t (getf status :running)) "status :running should be T")
             (is (not (null (getf status :git-initialized)))
                 "status :git-initialized should be non-NIL")
             (is (integerp (getf status :remotes-count)) "status remotes count should be integer")
             (is (integerp (getf status :ignore-count)) "status ignore count should be integer")
             (is (integerp (getf status :history-count)) "status history count should be integer")))
      (backup-teardown tmp)))
  (is (not (hngh.plugins.backup-manager:running-p))
      "Backup Manager should report not running after shutdown"))

(test backup-git-init-and-gitignore
  "Init creates git repo and managed .gitignore with secret exclusion."
  (with-backup (tmp)
    (is (probe-file (merge-pathnames ".git/" tmp))
        "git repository directory should exist")
    (let ((gitignore (merge-pathnames ".gitignore" tmp)))
      (is (probe-file gitignore) ".gitignore should be created")
      (with-open-file (in gitignore :direction :input :element-type 'character)
        (let ((contents (make-string (file-length in))))
          (read-sequence contents in)
          (is (not (null (search "secrets/" contents :test #'char=)))
              ".gitignore should contain secrets/ rule"))))))

(test backup-commit-history
  "Commit returns hash/message payload and appends history."
  (with-backup (tmp)
    (is (not (null tmp)) "temporary home should be available")
    (hngh.core.state-store:write-state "state/plugins/backup-manager/normal.lisp"
                                       '(:ok t))
    (let* ((before (length (hngh.plugins.backup-manager:list-history)))
           (result (hngh.plugins.backup-manager:commit :message "backup test commit"))
           (after (length (hngh.plugins.backup-manager:list-history))))
      (is (listp result) "commit should return a plist on success")
      (is (stringp (getf result :hash)) "commit hash should be a string")
      (is (plusp (length (getf result :hash))) "commit hash should be non-empty")
      (is (string= "backup test commit" (getf result :message))
          "commit message should round-trip")
      (is (= (1+ before) after) "history length should increase by one"))))

(test backup-secrets-never-tracked
  "Secrets remain untracked while normal files are tracked."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "secrets/vault.lisp" '(:token "secret"))
    (hngh.core.state-store:write-state "config/plugins/backup-manager/normal.lisp" '(:safe t))
    (let ((result (hngh.plugins.backup-manager:commit :message "mixed content commit")))
      (is (not (null result)) "commit should still succeed due to normal file"))
    (let* ((ls-files (run-git-in-dir tmp '("ls-files")))
           (tracked (or (getf ls-files :output) "")))
      (is (null (search "secrets/vault.lisp" tracked :test #'char=))
          "secrets file must never be tracked")
      (is (not (null (search "config/plugins/backup-manager/normal.lisp" tracked :test #'char=)))
          "normal file should be tracked"))))

(test backup-staging-guard-blocks-forced-secret
  "Forced staging of secrets is blocked by pre-commit guard."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "secrets/forced.gpg" '(:secret t))
    (let ((forced (run-git-in-dir tmp '("add" "-f" "secrets/forced.gpg"))))
      (is (getf forced :ok) "forced git add should succeed for guard test"))
    (let ((result (hngh.plugins.backup-manager:commit :message "should be blocked")))
      (is (null result) "commit should be blocked when forbidden path is staged"))
    (let ((staged (run-git-in-dir tmp '("diff" "--cached" "--name-only"))))
      (is (null (search "secrets/forced.gpg" (or (getf staged :output) "") :test #'char=))
          "forbidden staged file should be unstaged by guard"))))

(test backup-h1-unquote-git-path
  "Quoted git paths are unquoted before forbidden-path checks."
  (let* ((quoted "\"secrets/coñfig.gpg\"")
         (unquoted (hngh.plugins.backup-manager::unquote-git-path quoted)))
    (is (hngh.plugins.backup-manager::string-prefix-p "secrets/" unquoted)
        "unquote-git-path should strip surrounding quotes")
    (is (hngh.plugins.backup-manager::forbidden-staged-path-p
         (hngh.plugins.backup-manager::unquote-git-path "\"secrets/x.gpg\""))
        "forbidden check should catch quoted secret paths")
    (is (string= "config/normal.lisp"
                 (hngh.plugins.backup-manager::unquote-git-path "config/normal.lisp"))
        "plain path should be unchanged")))

(test backup-h2-restore-invalid-ref
  "Restore rejects option-like refs and leaves working tree unchanged."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "config/invalid-ref-test.lisp" '(:version 1))
    (is (not (null (hngh.plugins.backup-manager:commit :message "invalid-ref baseline")))
        "baseline commit should succeed")
    (hngh.core.state-store:write-state "config/invalid-ref-test.lisp" '(:version 2))
    (let ((before (hngh.core.state-store:read-state "config/invalid-ref-test.lisp"))
          (result (hngh.plugins.backup-manager:restore "--force"
                                                       :paths '("config/invalid-ref-test.lisp")
                                                       :confirm t)))
      (is (eq :failed (getf result :status)) "restore should fail for invalid ref")
      (is (eq :invalid-ref (getf result :reason)) "failure reason should be :invalid-ref")
      (is (equal before (hngh.core.state-store:read-state "config/invalid-ref-test.lisp"))
          "invalid ref restore must not modify working tree"))))

(test backup-h2-add-remote-invalid-name
  "add-remote rejects option-like remote names."
  (with-backup (tmp)
    (is (not (null tmp)) "temporary home should be available")
    (is (null (hngh.plugins.backup-manager:add-remote "--evil" "url"))
        "add-remote should return NIL for invalid names")
    (is (null (hngh.plugins.backup-manager:add-remote "origin" "--evil-url"))
        "add-remote should return NIL for invalid urls")
    (is (= 0 (length (hngh.plugins.backup-manager:list-remotes)))
        "invalid remote attempts must not persist state")))

(test backup-h2-push-invalid-remote
  "push-backup rejects option-like remote arguments."
  (with-backup (tmp)
    (is (not (null tmp)) "temporary home should be available")
    (let ((result (hngh.plugins.backup-manager:push-backup
                   :remote "--repo=https://evil/x.git")))
      (is (eq :failed (getf result :status)) "push-backup should fail invalid remote")
      (is (eq :invalid-remote (getf result :reason))
          "push-backup should report :invalid-remote"))))

(test backup-h3-git-lock-and-sequential-commit
  "Git lock is present and sequential commits still succeed."
  (with-backup (tmp)
    (is (not (null tmp)) "temporary home should be available")
    (is (boundp 'hngh.plugins.backup-manager::*git-lock*)
        "*git-lock* special variable should exist")
    (hngh.core.state-store:write-state "state/plugins/backup-manager/lock1.lisp" '(:n 1))
    (is (not (null (hngh.plugins.backup-manager:commit :message "lock commit 1")))
        "first commit should succeed")
    (hngh.core.state-store:write-state "state/plugins/backup-manager/lock2.lisp" '(:n 2))
    (is (not (null (hngh.plugins.backup-manager:commit :message "lock commit 2")))
        "second sequential commit should succeed")))

(test backup-h4-restore-auto-stash
  "Restore with confirm auto-stashes local modifications first."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "config/stash-test.lisp" '(:version 1))
    (is (not (null (hngh.plugins.backup-manager:commit :message "stash baseline")))
        "baseline commit should succeed")
    (hngh.core.state-store:write-state "config/stash-test.lisp" '(:version 2))
    (let ((result (hngh.plugins.backup-manager:restore "HEAD"
                                                       :paths '("config/stash-test.lisp")
                                                       :confirm t)))
      (is (eq :ok (getf result :status)) "restore should succeed")
      (is (eq t (getf result :stashed)) "restore should report stashed=T when changes existed"))
    (let* ((stash-list (run-git-in-dir tmp '("stash" "list")))
           (entries (string-trim '(#\Space #\Tab #\Newline #\Return)
                                 (or (getf stash-list :output) ""))))
      (is (plusp (length entries)) "stash list should contain pre-restore entry"))))

(test backup-h5-restore-forbidden-paths
  "Restore blocks explicit forbidden secret paths."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "config/h5-safe.lisp" '(:safe t))
    (is (not (null (hngh.plugins.backup-manager:commit :message "h5 baseline")))
        "baseline commit should succeed")
    (let* ((before-file (hngh.core.state-store:read-state "config/h5-safe.lisp"))
           (before-stash (run-git-in-dir tmp '("stash" "list")))
           (result (hngh.plugins.backup-manager:restore "HEAD"
                                                        :paths '("secrets/vault.lisp")
                                                        :confirm t))
           (after-stash (run-git-in-dir tmp '("stash" "list"))))
      (is (eq :failed (getf result :status)) "restore should fail for forbidden paths")
      (is (eq :forbidden-paths (getf result :reason)) "failure reason should be :forbidden-paths")
      (is (equal before-file (hngh.core.state-store:read-state "config/h5-safe.lisp"))
          "forbidden restore must not affect working tree")
      (is (string= (or (getf before-stash :output) "")
                   (or (getf after-stash :output) ""))
          "forbidden restore must not run pre-restore stash or checkout"))))

(test backup-m3-guard-unstages-only-violations
  "Staging guard unstages only forbidden paths, keeping safe paths staged."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "config/m3-safe.lisp" '(:safe t))
    (hngh.core.state-store:write-state "secrets/m3-secret.gpg" '(:secret t))
    (is (getf (run-git-in-dir tmp '("add" "config/m3-safe.lisp")) :ok)
        "safe path should stage cleanly")
    (is (getf (run-git-in-dir tmp '("add" "-f" "secrets/m3-secret.gpg")) :ok)
        "secret path should be force-staged for guard test")
    (let ((result (hngh.plugins.backup-manager:commit :message "m3 should abort")))
      (is (null result) "commit should abort when forbidden staged path exists"))
    (let ((staged (or (getf (run-git-in-dir tmp '("diff" "--cached" "--name-only")) :output) "")))
      (is (not (null (search "config/m3-safe.lisp" staged :test #'char=)))
          "safe staged file should remain staged")
      (is (null (search "secrets/m3-secret.gpg" staged :test #'char=))
          "forbidden staged file should be unstaged"))))

(test backup-restore-guard
  "Restore requires explicit confirmation and leaves tree unchanged otherwise."
  (with-backup (tmp)
    (hngh.core.state-store:write-state "config/restore-test.lisp" '(:version 1))
    (is (not (null (hngh.plugins.backup-manager:commit :message "restore baseline")))
        "baseline commit should succeed")
    (hngh.core.state-store:write-state "config/restore-test.lisp" '(:version 2))
    (let ((before (hngh.core.state-store:read-state "config/restore-test.lisp"))
          (result (hngh.plugins.backup-manager:restore "HEAD"
                                                       :paths '("config/restore-test.lisp"))))
      (is (eq :needs-confirmation (getf result :status))
          "restore without confirm must request confirmation")
      (is (equal before (hngh.core.state-store:read-state "config/restore-test.lisp"))
          "restore without confirm must not modify files"))))

(test backup-remotes-and-ignore
  "add-remote/list-remotes round-trip and defaults in managed ignore list."
  (with-backup (tmp)
    (is (not (null tmp)) "temporary home should be available")
    (is (hngh.plugins.backup-manager:add-remote "origin" "/tmp/backup-origin.git")
        "add-remote should return T")
    (let ((remotes (hngh.plugins.backup-manager:list-remotes))
          (ignores (hngh.plugins.backup-manager:managed-ignore-paths)))
      (is (= 1 (length remotes)) "one remote should be registered")
      (is (string= "origin" (getf (first remotes) :name)) "remote name should round-trip")
      (is (member "secrets/" ignores :test #'string=)
          "managed-ignore-paths should include default secrets/"))))

(test backup-push-local-bare-remote
  "push-backup succeeds against a local bare repository remote."
  (with-backup (tmp)
    (let ((remote-home (make-tmp-home)))
      (cleanup-tmp-home remote-home)
      (unwind-protect
           (let* ((bare-path (merge-pathnames "bare-remote.git/" remote-home))
                  (init-bare (run-git-in-dir tmp (list "init" "--bare" (namestring bare-path)))))
             (is (getf init-bare :ok) "local bare repo should be created")
             (hngh.core.state-store:write-state "state/plugins/backup-manager/pushable.lisp" '(:ok t))
             (is (not (null (hngh.plugins.backup-manager:commit :message "push baseline")))
                 "baseline commit for push should succeed")
             (is (hngh.plugins.backup-manager:add-remote "local" (namestring bare-path))
                 "adding local bare remote should succeed")
             (let ((push-result (hngh.plugins.backup-manager:push-backup :remote "local")))
               (is (eq :ok (getf push-result :status))
                   "push-backup should report :ok for local bare remote")))
        (cleanup-tmp-home remote-home)))))
